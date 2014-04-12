#!/bin/bash

#
#read conf
#
cd $(dirname ${0})

if [ ! -e ./radiko.conf ]; then
    echo -e "where is the 'radiko.conf'? we need this file.\nso exit this process."
    exit 0
fi
source ./radiko.conf
 # -> DIR_RADIKO
 # -> FILE_RADIKO_TABLE # 録音スケジュール、及び it3tag 情報を記載したテーブルファイルのパス
 # -> DIR_RADIKO_PLIST  # launchd に登録する plist 生成処理にて使用する場所。作業用であり、生成に成功した plist は ${DIR_LAUNCHAGENTS} へ格納される。
 # -> DIR_RADIKO_LOG    # スケジュール録音処理時の launchd による log ファイル出力先

# ログ出力用ディレクトリ
[ ! -e ${DIR_RADIKO_PLIST} ] && mkdir -p ${DIR_RADIKO_PLIST}
[ ! -e ${DIR_RADIKO_LOG} ] && mkdir -p ${DIR_RADIKO_LOG}

# 定数(変更不可 推奨)
FILE_RADIKO="${DIR_RADIKO}/radiko.sh"           # 録音処理メインシェル

MYHOSTNAME=$(hostname -s)                       # hostname 取得。launchd のジョブ名、plist 名で使用。
DIR_LAUNCHAGENTS="${HOME}/Library/LaunchAgents" # launchd が参照する plist ファイルの格納場所(システム側で規定。変更不可)

#
#functions
#
duration()
{
    beg=$(date -j -f '%H%M' $1 "+%s")    # BSD
    end=$(date -j -f '%H%M' $2 "+%s")    # BSD
    if [ $beg -gt $end ]; then end=$(( end + ( 60 * 60 * 24 ) )); fi    # sec * min * hour

    echo $(((end - beg) / 60 + SHIFT + ADJUSTMENT))
}
weekday()
{
    case $1 in
        sun) echo 0;;
        mon) echo 1;;
        tue) echo 2;;
        wed) echo 3;;
        thr) echo 4;;
        fri) echo 5;;
        sat) echo 6;;
        * ) echo 99;;
    esac
}
make_plist()
{
    labelis=$1
    stationis=$2
    nameis=$3
    durationis=$4
    sch_minuteis=$5
    sch_houris=$6
    sch_weekdayis=$7

    plistis=$8
    [ -e ${plistis} ] && rm -f ${plistis}

cat << END >> "${plistis}"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${labelis}</string>
  <key>ProgramArguments</key>
  <array>
    <string>${FILE_RADIKO}</string>
    <string>${stationis}</string>
    <string>${nameis}</string>
    <string>${durationis}</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key>
    <integer>${sch_houris}</integer>
    <key>Minute</key>
    <integer>${sch_minuteis}</integer>
END
if [ ! "${sch_weekdayis}" = 99 ]; then
cat << END >> "${plistis}"
    <key>Weekday</key>
    <integer>${sch_weekdayis}</integer>
END
fi
cat << END >> "${plistis}"
  </dict>
  <key>StandardErrorPath</key>
    <string>${DIR_RADIKO_LOG}/${labelis}_err.log</string>
  <key>StandardOutPath</key>
    <string>${DIR_RADIKO_LOG}/${labelis}.log</string>
</dict>
</plist>
END
}

make_plist4checking()
{
    labelis=$1
    stationis=$2
    nameis=$3
    durationis=$4
    sch_interval=$5

    plist_checkin=$6
    [ -e ${plist_checkin} ] && rm -f ${plist_checkin}

cat << END >> "${plist_checkin}"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${labelis}</string>
  <key>ProgramArguments</key>
  <array>
    <string>${FILE_RADIKO}</string>
    <string>${stationis}</string>
    <string>${nameis}</string>
    <string>${durationis}</string>
  </array>
  <key>StandardErrorPath</key>
  <string>${DIR_RADIKO_LOG}/${labelis}_err.log</string>
  <key>StandardOutPath</key>
  <string>${DIR_RADIKO_LOG}/${labelis}.log</string>
</dict>
</plist>
END
}


#
#prepare
#
while true; do
    printf 'clean plists about radiko?  [y(es)/n(o)] : '
    read res
    case ${res} in
        [Yy]*)
            # for plistis in $(ls "${DIR_LAUNCHAGENTS}/*.plist")
            for plistis in $(ls ${DIR_LAUNCHAGENTS}/koo.radiko.*.plist); do
                if [ -z "${plistis}" -o ! -e "${plistis}" ]; then
                    continue
                fi
                #remove job
                job_label=$(basename "${plistis}" ".plist")
                launchctl remove ${job_label}
                rm ${plistis}
            done
            break;;
        [Nn]*) break;;
        *)
            echo "Can't read your enter. try again."
    esac
done

#
#regester recording shedule with system
#
rec=1
while read LINE
do
    [ $(echo ${LINE:0:1}) = "#" ] && continue

    name=$(echo ${LINE} | cut -d , -f 1)
    station=$(echo $LINE | cut -d , -f 2)

    duration=$(duration $(echo $LINE | cut -d , -f 4) $(echo $LINE | cut -d , -f 5))

    beg_tuned=$(echo ${LINE} | cut -d , -f 4)
    beg_tuned=$(date -j -f '%s' $(( $(date -j -f '%H%M' $beg_tuned "+%s") - $(( 60 * SHIFT)) )) "+%H%M")

    sch_hour=$(echo ${beg_tuned} | cut -c 1-2)
    sch_minute=$(echo ${beg_tuned} | cut -c 3-4)
    sch_weekday=$(weekday $(echo $LINE | cut -d , -f 3))

    label=${MYHOSTNAME}.radiko.${station}${sch_weekday}.${name}
    [ "${sch_weekday}" = 99 ] && label=${MYHOSTNAME}.radiko.${station}.${name}

    plist=${DIR_RADIKO_PLIST}/${label}.plist
    plist_launchagents=${DIR_LAUNCHAGENTS}/${label}.plist

    make_plist ${label} \
        $(tr "[a-z]" "[A-Z]" <<<${station}) ${name} ${duration} \
        ${sch_minute} ${sch_hour} ${sch_weekday} \
        ${plist}
    echo "${label}, ${station}, $(echo $LINE | cut -d , -f 3), $(echo ${LINE} | cut -d , -f 4)(${beg_tuned})-$(echo $LINE | cut -d , -f 5)"

    #in "$HOME/Library/LaunchAgents"
    cp -f ${plist} ${plist_launchagents}
    chmod 644 ${plist_launchagents}
    # launchctl unload ${plist_launchagents} && launchctl load ${plist_launchagents}
    launchctl load ${plist_launchagents}

done < ${FILE_RADIKO_TABLE}

while true; do
    printf 'do you need a plist for checking?  [y(es)/n(o)] : '
    read res
    case ${res} in
        [Yy]*)
            name="check"
            station="tbs"
            duration=1    #min

            sch_interval=$(( 60 * 5 ))

            label=${MYHOSTNAME}.radiko.${station}.${name}
            plist=${DIR_LAUNCHAGENTS}/${label}.plist

            make_plist4checking ${label} \
                $(tr "[a-z]" "[A-Z]" <<<${station}) ${name} ${duration} \
                ${sch_interval} \
                ${plist}

            launchctl load ${plist}
            launchctl start ${label}

            break;;
        [Nn]*)
            break;;
        *)
            echo "Can't read your enter. try again."
    esac
done
echo "it's done."
