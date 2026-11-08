#!/usr/bin/env bash
# Local ZMK build in the same docker image CI uses.
#   ./build-local.sh            build left + right
#   ./build-local.sh left       build one target (left|right|reset|left-debug: USB log + display dbg)
#   ./build-local.sh update     re-run `west update` (after changing west.yml)
# Workspace: ~/Code/zmk-workspace. The local ~/Code/custom-zmk-animation is mounted
# over the west-fetched copy, so screen edits build without pushing.
# Extra cmake args: CMAKE_EXTRA="-DCONFIG_ZMK_USB_LOGGING=y" ./build-local.sh left
set -euo pipefail

ws=$HOME/Code/zmk-workspace
cfg=$(cd "$(dirname "$0")" && pwd)
mod=$HOME/Code/custom-zmk-animation
out=$ws/out
mkdir -p "$ws/custom-zmk-animation" "$out"

run() { # cmd [extra docker args]
    docker run --rm -u "$(id -u):$(id -g)" -e HOME=/tmp -e ZEPHYR_BASE=/ws/zephyr \
        -v "$ws:/ws" -v "$cfg/config:/ws/config" "${@:2}" \
        -w /ws zmkfirmware/zmk-build-arm:stable bash -c "$1"
}

if [ ! -d "$ws/.west" ] || [ "${1:-}" = update ]; then
    # Local module not mounted here: west update would check it out and detach its HEAD.
    run "[ -d .west ] || west init -l config; west update --fetch-opt=--filter=tree:0"
    [ "${1:-}" = update ] && exit 0
fi

build() { # name board shield extra-args
    run "west build -s zmk/app -d build/$1 -b $2 -p auto -- -DZephyr_DIR=/ws/zephyr/share/zephyr-package/cmake -DZMK_CONFIG=/ws/config \
        -DSHIELD='$3' $4 ${CMAKE_EXTRA:-}" -v "$mod:/ws/custom-zmk-animation"
    cp "$ws/build/$1/zephyr/zmk.uf2" "$out/$1.uf2"
    echo "-> $out/$1.uf2"
}

for half in ${1:-left right}; do
    case $half in
    left) build left nice_nano//zmk "sofle_left nice_view_adapter nice_view_custom" \
        "-DSNIPPET=studio-rpc-usb-uart -DCONFIG_ZMK_STUDIO=y" ;;
    left-debug) build left-debug nice_nano//zmk "sofle_left nice_view_adapter nice_view_custom" \
        "-DSNIPPET=zmk-usb-logging -DCONFIG_DISPLAY_LOG_LEVEL_DBG=y" ;;
    left-stock) build left-stock nice_nano//zmk "sofle_left nice_view_adapter nice_view" \
        "-DSNIPPET=zmk-usb-logging -DCONFIG_DISPLAY_LOG_LEVEL_DBG=y" ;;
    right) build right nice_nano//zmk "sofle_right nice_view_adapter nice_view_custom" "" ;;
    reset) build reset nice_nano//zmk settings_reset "" ;;
    esac
done
