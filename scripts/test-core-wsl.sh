#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [ -f "$HOME/.local/share/swiftly/env.sh" ]; then
    source "$HOME/.local/share/swiftly/env.sh"
fi
# This machine runs Ubuntu 26.04; the official toolchain targets Ubuntu 24.04.
# Its older ABI dependencies were extracted locally, without replacing system libraries.
compat="$HOME/.cache/rallytrip-swift-compat/root/usr/lib/x86_64-linux-gnu"
if [ -d "$compat" ]; then
    export LD_LIBRARY_PATH="$compat${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi
swift test --scratch-path "$HOME/.cache/rallytrip-build"
