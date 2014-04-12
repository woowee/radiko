#!/bin/bash

cd `dirname ${0}`
#
#read conf
#
if [ ! -e ./radiko.conf ]; then
    echo -e "where is the 'radiko.conf'? we need this file.\nso exit this process."
    exit 1
fi
source ./radiko.conf
 # -> DIR_RADIKO_WRK    # 作業のベースとなるメインディレクトリ。
 # -> DIR_RADIKO_RAW    # 録音済データ(*.acc)格納用ディレクトリ。(DIR_RADIKO_WRK の直下にレイアウト)
 # -> DIR_RADIKO_EDT    # 編集済データ(*.mp3)格納用ディレクトリ。(DIR_RADIKO_WRK の直下にレイアウト)
 # -> FILE_RADIKO_TABLE # 録音スケジュール、及び it3tag 情報を記載したテーブルファイルのパス
 #
 # -> DIR_DONE_RAW      # バックアップ格納用ディレクトリ。録音済(*.acc)用。
 # -> DIR_DONE_EDT      # バックアップ格納用ディレクトリ。編集済(*.mp3)用。
 # -> EXT_EDT           # 編集済データフォーマット、"mp3"。
 #
 # -> DIRNAME_COVERARTS # アルバムアートワークの画像データを格納するディレクトリの名前

EXTENTION=${EXT_EDT} # "mp3"

#
# itunes
#
[ ! -e DIR_ITUNESLIB ] && DIR_ITUNESLIB="${HOME}/Music/iTunes"
DIRNAME_ADD2ITUNES='Automatically Add to iTunes.localized'
DIR_ADD2ITUNES=$(mdfind -onlyin "${DIR_ITUNESLIB}" "kMDItemFSName == '${DIRNAME_ADD2ITUNES}' && kMDItemKind == 'フォルダ'")
if [ -z "${DIR_ADD2ITUNES}" -o ! -e "${DIR_ADD2ITUNES}" ]; then
    echo -e "cannot find your itunes library.\nso exit this process. check your itunes library."
    exit 1
fi

#
# tools
#
get_path_command()
{
    if type $1 > /dev/null 2>&1; then
        eval $2="\"$(type -p $1)\""
    else
        echo "$1 has not been installed. please install $1." 1>$2
        return 1
    fi
}

# TOOL_MID3V2="${DIR_CELLAR}/mid3v2"      # check on terminal `%type mid3v2`
# TOOL_EYE3D="${DIR_CELLAR}/eyeD3_script" # check on terminal `%type eyeD3_script`
get_path_command mid3v2 TOOL_MID3V2
get_path_command eyeD3  TOOL_EYE3D

# ------------------------------ read table
rec=1; while IFS= read LINE; do listis[${rec}]=${LINE}; ((rec++)); done < ${FILE_RADIKO_TABLE}; unset rec LINE

# ------------------------------ set tag
for target in $(ls ${DIR_RADIKO_EDT}/*.${EXTENTION}); do
    target_keyis=$(echo ${target##*/} | cut -d '_' -f 1)
    for itemis in "${listis[@]}"; do
        # get key from the list
        keyis=`echo "${itemis}" | cut -d , -f 1`

        # check key
        # echo $target_keyis, $keyis
        if [ "${target_keyis}" = ${keyis} ]; then
            titleis=$(echo ${itemis} | cut -d , -f 6)
            artistis=$(echo ${itemis} | cut -d , -f 7)
            ganreis=$(echo ${itemis} | cut -d , -f 8)
            albumis=$(echo ${itemis} | cut -d , -f 9)

            # title date
            target_dateis=$(echo ${target##*/} | cut -d '_' -f 2)

            echo ${DIR_ADD2ITUNES}
            if [ -e "${DIR_ADD2ITUNES}" ]; then
                # drop id3tag
                ${TOOL_MID3V2} \
                        -t "${titleis} $(echo ${target_dateis} | cut -c1-4).$(echo ${target_dateis} | cut -c5-6).$(echo ${target_dateis} | cut -c7-8)" \
                        -a "${artistis}" \
                        -A "${albumis}" \
                        -g "${ganreis}" \
                        -y $(echo ${target_dateis} | cut -c1-4) \
                    $target

                # coverart
                coverartis=$(mdfind -onlyin "${DIR_COVERARTS}" "${target_keyis}")
                ${TOOL_EYE3D} --add-image ${coverartis}:FRONT_COVER ${target}

                # send itunes & set on "remember playback position"
                osascript "${DIR_RADIKO}/setradiko.scpt" "${target}"

                # remove raw file
                recfileis=$(mdfind -onlyin ${DIR_RADIKO_RAW} $(basename ${target} .${EXT_EDT}).${EXT_RAW})
                [ -e ${recfileis} ] && mv ${recfileis} ${DIR_DONE_RAW}
                # remove edited mp3 file
                mv ${target} ${DIR_DONE_EDT}

                break
            fi

        fi
    done
done
