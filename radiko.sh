#!/bin/bash -u
export LANG="ja_JP.UTF-8" LC_ALL="ja_JP.UTF-8"


############################## 定数

cd `dirname ${0}`
. ./radiko.conf
#  $DIR_RADIKO         : 各録音処理用 Shellscript
#  $DIR_RADIKO_WRK     : 録音作業用ディレクトリ
#    $DIR_RADIKO_CACHE : 録音時生成される各データのキャッシュ用ディレクトリ
#    $DIR_RADIKO_RAW   : 録音生データ
#    $DIR_RADIKO_EDT   : 編集済データ、iTunes へ転送
#  $DIR_CELLAR         : homebrew の各ツールが格納さえているディレクトリ
#  $MARGIN             : 録音時間のマージン(min)
#  $MYEXTENTION        : 録音データの出力へbん缶フォーマット

DIR_MYRADIKOREC=${DIR_RADIKO_WRK}
DIR_MYRADIKOREC_CACHE=${DIR_RADIKO_CACHE}
DIR_MYRADIKOREC_RAW=${DIR_RADIKO_RAW}

DIR_MYCELLAR=${DIR_CELLAR}

MYEXTENTION=${EXT_RAW}
DATETIME=`date '+%Y%m%d_%H%M'`

# arguments
if [ $# -ge 3 ]; then
  STATION=$1
  NAME=$2
  DURATION=$(( $3 * 60 + MARGIN * 2 * 60 ))
else
  echo "usage : $0 STATION NAME DURATION(minuites)" 1>&2
  exit 1
fi

# radiko へのアクセス
# PLAYERURL=http://radiko.jp/player/swf/player_3.1.0.00.swf
PLAYERURL=http://radiko.jp/player/swf/player_4.0.0.00.swf
PLAYERFILE="./player.swf"
KEYFILE="./authkey.png"

SUFFIX="_${STATION}_${NAME}"

# 録音データファイル
FILE_DMP="${DIR_MYRADIKOREC_CACHE}/${STATION}_${DATETIME}"
FILE_REC="${DIR_MYRADIKOREC_RAW}/${NAME}_${DATETIME}.${MYEXTENTION}"


############################## 処理

cd ${DIR_MYRADIKOREC_CACHE}

#
# get player
#
if [ ! -f ${PLAYERFILE} ]; then
  ${DIR_MYCELLAR}/wget -q -O ${PLAYERFILE} ${PLAYERURL}

  if [ $? -ne 0 ]; then
    echo "failed get player" 1>&2
    exit 1
  fi
fi

#
# get keydata (need swftool)
#
if [ ! -f ${KEYFILE} ]; then
  ${DIR_MYCELLAR}/swfextract -b 14 ${PLAYERFILE} -o ${KEYFILE}

  if [ ! -f ${KEYFILE} ]; then
    echo "failed get keydata" 1>&2
    exit 1
  fi
fi

if [ -f auth1_fms${SUFFIX} ]; then
  rm -f auth1_fms${SUFFIX}
fi

#
# access auth1_fms
#
${DIR_MYCELLAR}/wget -q \
     --header="pragma: no-cache" \
     --header="X-Radiko-App: pc_1" \
     --header="X-Radiko-App-Version: 2.0.1" \
     --header="X-Radiko-User: test-stream" \
     --header="X-Radiko-Device: pc" \
     --post-data='\r\n' \
     --no-check-certificate \
     --save-headers \
     --tries=3 \
     --timeout=6 \
     -O auth1_fms${SUFFIX} \
     https://radiko.jp/v2/api/auth1_fms

if [ $? -ne 0 ]; then
  echo "failed auth1 process" 1>&2
  exit 1
fi

#
# get partial key
#
authtoken=`cat auth1_fms${SUFFIX} | perl -ne 'print $1 if(/x-radiko-authtoken: ([\w-]+)/i)'`
offset=`cat auth1_fms${SUFFIX} | perl -ne 'print $1 if(/x-radiko-keyoffset: (\d+)/i)'`
length=`cat auth1_fms${SUFFIX} | perl -ne 'print $1 if(/x-radiko-keylength: (\d+)/i)'`

partialkey=`dd if=$KEYFILE bs=1 skip=${offset} count=${length} 2> /dev/null | base64`
echo -e "authtoken: ${authtoken} \noffset: ${offset} length: ${length} \npartialkey:$partialkey"

rm -f auth1_fms${SUFFIX}

if [ -f auth2_fms${SUFFIX} ]; then
  rm -f auth2_fms${SUFFIX}
fi

#
# access auth2_fms
#
${DIR_MYCELLAR}/wget -q \
     --header="pragma: no-cache" \
     --header="X-Radiko-App: pc_1" \
     --header="X-Radiko-App-Version: 2.0.1" \
     --header="X-Radiko-User: test-stream" \
     --header="X-Radiko-Device: pc" \
     --header="X-Radiko-Authtoken: ${authtoken}" \
     --header="X-Radiko-Partialkey: ${partialkey}" \
     --post-data='\r\n' \
     --no-check-certificate \
     --tries=3 \
     --timeout=6 \
     -O auth2_fms${SUFFIX} \
     https://radiko.jp/v2/api/auth2_fms

if [ $? -ne 0 -o ! -f auth2_fms${SUFFIX} ]; then
  echo "failed auth2 process" 1>&2
  exit 1
fi

echo "authentication success"
areaid=`cat auth2_fms${SUFFIX} | perl -ne 'print $1 if(/^([^,]+),/i)'`
echo "areaid: ${areaid}"

rm -f auth2_fms${SUFFIX}

#
# rtmpdump
#
retrycount=0
while :
do
    ${DIR_MYCELLAR}/rtmpdump -v \
        -r "rtmpe://w-radiko.smartstream.ne.jp" \
        --playpath "simul-stream.stream" \
        --app "${STATION}/_definst_" \
        -W ${PLAYERURL} \
        -C S:"" -C S:"" -C S:"" -C S:${authtoken} \
        --live \
        --stop ${DURATION} \
        -o ${FILE_DMP}
  if [ $? -ne 1 -o `wc -c ${FILE_DMP} | awk '{print $1}'` -ge 10240 ]; then
    break
  elif [ ${retrycount} -ge 5 ]; then
    echo "failed rtmpdump"
    exit 1
  else
    retrycount=$(( retrycount + 1 ))
  fi
done

${DIR_MYCELLAR}/ffmpeg -y -i ${FILE_DMP} -vn -acodec copy ${FILE_REC}

rm ${FILE_DMP}


