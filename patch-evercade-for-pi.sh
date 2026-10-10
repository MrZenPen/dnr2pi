#!/usr/bin/env bash
set -euo pipefail

# Patch the original Duke Nukem 1+2 Remastered Evercade ARM executable for
# Raspberry Pi 5. The source file is never modified in place.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SOURCE="${1:-$SCRIPT_DIR/uranium/RigelEngine_StaticSDL2}"
DESTINATION="${2:-$SCRIPT_DIR/uranium/RigelEngine_StaticSDL2.pi}"

EXPECTED_SOURCE_SHA256="b07904da2f84d943b52965d6171dbef59b43d3701a9e93167c1138c062a578fc"
EXPECTED_OUTPUT_SHA256="246c17b1dbb0be290079fbf98501ade47c4535524dd8910bcf6e5f6c5267282b"

fail() { echo "Error: $*" >&2; exit 1; }

[[ -f "$SOURCE" ]] || fail "Original executable not found: $SOURCE"
[[ "$SOURCE" != "$DESTINATION" ]] || fail "Refusing to overwrite the original executable."

actual_source_hash="$(sha256sum "$SOURCE" | awk '{print $1}')"
[[ "$actual_source_hash" == "$EXPECTED_SOURCE_SHA256" ]] || fail \
  "Unsupported source binary. Expected SHA-256 $EXPECTED_SOURCE_SHA256 but found $actual_source_hash"

gate_byte="$(od -An -tx1 -j 73027 -N 1 "$SOURCE" | tr -d '[:space:]')"
[[ "$gate_byte" == "1a" ]] || fail "Unexpected byte at Evercade hardware-gate patch offset."

connector_byte="$(od -An -tx1 -j 4902395 -N 1 "$SOURCE" | tr -d '[:space:]')"
[[ "$connector_byte" == "30" ]] || fail "Unexpected byte at HDMI connector patch offset."

cp -- "$SOURCE" "$DESTINATION"
printf '\352' | dd of="$DESTINATION" bs=1 seek=73027 conv=notrunc status=none
printf '\061' | dd of="$DESTINATION" bs=1 seek=4902395 conv=notrunc status=none
chmod +x "$DESTINATION"

actual_output_hash="$(sha256sum "$DESTINATION" | awk '{print $1}')"
if [[ "$actual_output_hash" != "$EXPECTED_OUTPUT_SHA256" ]]; then
  rm -f -- "$DESTINATION"
  fail "Patched output failed verification; the incomplete output was removed."
fi

echo "Patch completed successfully."
echo "Original: $SOURCE"
echo "Patched:  $DESTINATION"
echo "SHA-256:  $actual_output_hash"
