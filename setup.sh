#!/bin/bash

set -e

existence_directory()
{
    #usage $1:path
    # [ ! -e $1 ] && mkdir -p $1
    if [ -e $1 ]; then
        echo "OK: directory '$(basename $1)' => $1"
    else
        echo "CHECK: we need '$(basename $1)' directory. so mkdir it."
        mkdir -p $1
    fi
}

existence_command()
{
    if ! type $1 > /dev/null 2>&1; then
        [ $# -eq 2 ] && targetis=$2 || targetis=$1
        echo "CHECK: we need '$1' command. so install it using homebrew."
        brew install ${targetis}
    fi

    echo "OK: command '$1' => $(type $1 | awk -F' ' '{print $NF}')"
}

cd $(dirname ${0})

#
# 環境チェック
#

# tools (homebrew の導入が前提)
if ! type brew > /dev/null 2>&1; then
    echo -e "ERROR: its not been installed 'homebrew'. we need 'homebrew' enviroment, so install that.\nexit this process."
    exit 1
fi
echo -e "OK: command 'brew' => $(brew --prefix)"

# radiko.conf
if [ ! -e ./radiko.conf ]; then
    echo -e "ERROR: there is no 'radiko.conf'. we need the config file for radiko.\nexit this process."
    exit 1
fi
source ./radiko.conf
echo -e "OK: file 'radiko.conf' => $(mdfind -onlyin $(pwd) -name 'radiko.conf')"

#
# 環境構築
#
echo ""
existence_directory "${DIR_RADIKO_WRK}"   # 録音データ出力用
existence_directory "${DIR_RADIKO_CACHE}" # 録音データ出力用DIR.キャッシュ
existence_directory "${DIR_RADIKO_RAW}"   # 録音データ出力用DIR.録音済ファイル(*.acc)
existence_directory "${DIR_DONE_RAW}"     # 録音データ出力用DIR.録音済ファイル(*.acc).処理済データ
existence_directory "${DIR_RADIKO_EDT}"   # 録音データ出力用DIR.編集済ファイル(*.mp3)
existence_directory "${DIR_DONE_EDT}"     # 録音データ出力用DIR.編集済ファイル(*.mp3).作業済データ
existence_directory "${DIR_COVERARTS}"    # 録音データ出力用DIR.編集済ファイル(*.mp3).アートワーク画像

if [ ! -e "${DIR_RADIKO_TABLE}" ]; then
    echo "#keyword,channel,weekday(sun|mon|tue|wed|thr|fri|sat),start(hhmm),end(hhmm),title,artist,genre,album" > ${FILE_RADIKO_TABLE}
fi

echo ""
existence_command "wget"
existence_command "swfextract" "swftools" # swfextract is in swftools.
existence_command "rtmpdump"
existence_command "ffmpeg"
existence_command "base64"

existence_command "eyeD3"

#
#その他
#
if ! type mid3v2 > /dev/null 2>&1; then
cat << END
CHECK: we need 'mid3v2' command to set id3tag. so install it using homebrew.

in order to install and use mid3v2 we need the following;
- Python (Mutagen has mid3v2 is a Python module)
- Pip (To install Mutagen)
- Mutagen (mid3v2 is incuded with it)

Steps ;
$ brew install python
$ brew install python3
$ brew link --overwrite python

$ pip install mutagen

END
else
    echo "OK: command 'mid3v2' => $(type mid3v2 | awk -F' ' '{print $NF}')"
fi

echo -e "\n\033[32m==>\033[0m \033[1mNow it's done.\033[0m\n"

cat << END
* please prepare for the recording Radiko successively. ;
    0. set up mid3v2. (if it's not yet)
    1. prepare 'radiko.table' and so execute \`setschedule.sh\` to regester with launchd.
    2. get artworks and sotre into 'coverarts' directory.
END

