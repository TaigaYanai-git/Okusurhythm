#!/bin/zsh
# 1枚撮る。画面が描かれて落ち着くまで待つ（重いときに白い画面を撮らないように）
#   scripts/shoot_one.sh <端末> <出力png> 起動引数...
D=$1; OUTPNG=$2; shift 2
B=com.taigayanai.okusurhythm
xcrun simctl terminate "$D" $B 2>/dev/null
xcrun simctl launch "$D" $B -uiPreview "$@" >/dev/null
prev=0; tmp=$(mktemp -t shot).png
for i in $(seq 1 40); do
  sleep 4
  xcrun simctl io "$D" screenshot --type=png "$tmp" >/dev/null 2>&1
  s=$(stat -f %z "$tmp")
  # 白一色（約9万バイト）やホーム画面（300万バイト超）は待つ。2回同じ大きさなら完成
  if (( s > 150000 && s < 2500000 && s == prev )); then mv "$tmp" "$OUTPNG"; echo "$OUTPNG ($((i*4))s)"; exit 0; fi
  prev=$s
done
mv "$tmp" "$OUTPNG"; echo "$OUTPNG (timeout)"
