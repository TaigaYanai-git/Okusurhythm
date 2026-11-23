#!/bin/zsh
ICT="/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool"
D=~/Okusurhythm/Design/IconProposals/round3
P=$D/previews
for icon in $D/*.icon; do
  n=$(basename $icon .icon)
  "$ICT" $icon --export-image --output-file $P/$n-Light.png --platform iOS --rendition Default --width 1024 --height 1024 --scale 1 >/dev/null 2>&1
  "$ICT" $icon --export-image --output-file $P/$n-Dark.png --platform iOS --rendition Dark --width 1024 --height 1024 --scale 1 >/dev/null 2>&1
  "$ICT" $icon --export-image --output-file $P/$n-TintedDark.png --platform iOS --rendition TintedDark --width 1024 --height 1024 --scale 1 --tint-color 0.58 --tint-strength 0.75 >/dev/null 2>&1
  "$ICT" $icon --export-image --output-file $P/$n-ClearLight.png --platform iOS --rendition ClearLight --width 1024 --height 1024 --scale 1 >/dev/null 2>&1
  magick $P/$n-Light.png $P/$n-Dark.png $P/$n-TintedDark.png $P/$n-ClearLight.png -resize 360x360 +append $PWD/row_$n.png
done
