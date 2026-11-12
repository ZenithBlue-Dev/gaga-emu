#!/usr/bin/env bash
# Seeds the store screenshot Library on a device that has the Debug app installed: ten homebrew test ROMs named
# after the invented games, each with its 3:4 cover tile, and order.txt, in the app's Documents/StoreSeed.
# UITests/GagaEmuWalkTests.swift testStoreShots imports them (-GagaStoreSeed StoreSeed).
#
#     scripts/store/seed_device.sh <device-udid> <tiles-dir>
#
# <tiles-dir> is the second argument given to scripts/store/clean_art.swift (cover-01.png ... cover-10.png).
set -euo pipefail
device=${1:?usage: seed_device.sh <device-udid> <tiles-dir>}
tiles=${2:?usage: seed_device.sh <device-udid> <tiles-dir>}
root=$(cd "$(dirname "$0")/../.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
titles=("Tiny Jump Quest" "Chronicles of Eldon" "Neon Starfire" "Turbo Dash" "Cerebral Grid" "Arena of Rage"
        "Shadow of Ashes" "Sprout's Big Journey" "Red Planet Outpost" "Whispers in the Dark")
"$root/scripts/make-test-rom.sh" "$work/rom.gba"
: >"$work/order.txt"
for i in "${!titles[@]}"; do
    t=${titles[$i]}
    cp "$work/rom.gba" "$work/$t.gba"
    cp "$tiles/cover-$(printf %02d $((i + 1))).png" "$work/$t.png"
    echo "$t.gba" >>"$work/order.txt"
done
rm "$work/rom.gba"
for f in "$work"/*; do
    xcrun devicectl device copy to --device "$device" --domain-type appDataContainer \
        --domain-identifier com.zenithblue.gagaemu --source "$f" --destination "Documents/StoreSeed/$(basename "$f")" >/dev/null
done
echo "seeded $(wc -l <"$work/order.txt" | tr -d ' ') games"
