#!/bin/sh
# Render every option and variant at 1024 into option-<n>-<name>/, tagged sRGB. Needs Blender 5 on PATH.
cd "$(dirname "$0")" || exit 1
SAMPLES=${SAMPLES:-256}
SRGB="/System/Library/ColorSync/Profiles/sRGB Profile.icc"
for entry in 1:two-beats:two_beats 2:folio:folio 3:shelf:shelf 4:steps:steps 5:well:well 6:phosphor:phosphor; do
  n=${entry%%:*}; rest=${entry#*:}; name=${rest%%:*}; concept=${rest#*:}
  dir="option-$n-$name"; mkdir -p "$dir"
  for variant in light dark tinted; do
    case $variant in light) file=icon-1024.png ;; *) file=icon-1024-$variant.png ;; esac
    blender -b --factory-startup -P render_icons.py -- "$concept" "$variant" 1024 "$SAMPLES" "$PWD/$dir/$file" >/dev/null || exit 1
    sips --embedProfile "$SRGB" "$dir/$file" >/dev/null
    # App Store rejects an icon with alpha.
    sips -g hasAlpha -g pixelWidth "$dir/$file" | grep -q 'hasAlpha: no' || { echo "$dir/$file has alpha"; exit 1; }
  done
done
