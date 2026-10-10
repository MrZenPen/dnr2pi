#!/usr/bin/env bash
set -euo pipefail

GAME_ROOT="${HOME}/duke-remastered"
GAME_DIR="$GAME_ROOT/uranium"
LOG_DIR="$GAME_ROOT/logs"
LOG_FILE="$LOG_DIR/duke-remastered.log"
GAME_BINARY="$GAME_DIR/RigelEngine_StaticSDL2.pi"
EXPECTED_BINARY_HASH="246c17b1dbb0be290079fbf98501ade47c4535524dd8910bcf6e5f6c5267282b"

declare -A EXPECTED_ARCHIVE_HASHES=(
  [data.duke]="a88d956eb1ee548f261f15e63f43f4a9bdf4aa6b5a20f5196984189f40164171"
  [music.duke]="eb5afb0c2c20946fc3dd5e2dc9e5d6bddd010178f482abfb3c4e30595eeb1c4f"
  [misc.duke]="d2f8c788773a99b99e356fccf818fc0ae8b6a0466bbfe4bd93f2d4c258d58746"
)

fail() { echo "Error: $*" >&2; exit 1; }

[[ "$(getconf LONG_BIT)" == "32" ]] || fail \
  "This release requires Raspberry Pi OS 32-bit userspace."

mkdir -p "$LOG_DIR"
[[ -f "$GAME_BINARY" ]] || fail "Patched executable not found: $GAME_BINARY"

binary_hash="$(sha256sum "$GAME_BINARY" | awk '{print $1}')"
[[ "$binary_hash" == "$EXPECTED_BINARY_HASH" ]] || fail \
  "The patched executable checksum is incorrect: $binary_hash"
chmod +x "$GAME_BINARY"

connector_status="/sys/class/drm/card1-HDMI-A-1/status"
[[ -r "$connector_status" ]] || fail "HDMI port 1 was not found at $connector_status."
[[ "$(tr -d '\r\n' < "$connector_status")" == "connected" ]] || fail \
  "HDMI port 1 is not connected. Move the HDMI cable to the first micro-HDMI port."

for archive in data.duke music.duke misc.duke; do
  archive_path="$GAME_DIR/$archive"
  [[ -f "$archive_path" ]] || fail "Required archive is missing: $archive_path"
  archive_hash="$(sha256sum "$archive_path" | awk '{print $1}')"
  [[ "$archive_hash" == "${EXPECTED_ARCHIVE_HASHES[$archive]}" ]] || fail \
    "Checksum mismatch for $archive: $archive_hash"
done

missing_libraries="$(ldd "$GAME_BINARY" 2>&1 | grep 'not found' || true)"
[[ -z "$missing_libraries" ]] || fail "Missing libraries: $missing_libraries"

aplay -L 2>/dev/null | grep -qx 'pipewire' || fail \
  "The PipeWire ALSA device is unavailable. Check the README audio setup."

export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export SDL_VIDEODRIVER=kmsdrm
export SDL_AUDIODRIVER=alsa
export AUDIODEV=pipewire
export SDL_AUDIO_ALSA_DEFAULT_DEVICE=pipewire
export SDL_AUDIO_FREQUENCY=48000
export SDL_AUDIO_FORMAT=S16SYS
export SDL_AUDIO_SAMPLES=8192
export LD_LIBRARY_PATH=/usr/lib/arm-linux-gnueabihf

if [[ -f "$GAME_ROOT/gamecontrollerdb.txt" ]]; then
  export SDL_GAMECONTROLLERCONFIG_FILE="$GAME_ROOT/gamecontrollerdb.txt"
fi

cd "$GAME_DIR"
: > "$LOG_FILE"
echo "Starting Duke Nukem 1+2 Remastered. Log: $LOG_FILE"
exec "$GAME_BINARY" "$GAME_DIR" >> "$LOG_FILE" 2>&1
