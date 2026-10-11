#!/bin/bash

# Define the path to a local bundled binary, if one is ever vendored
LOCAL_BIN="$PWD/bin/love.AppImage"

if [ -f "$LOCAL_BIN" ]; then
    echo "Using local bin..."
    "$LOCAL_BIN" "$PWD" "$@"
else
    love "$PWD" "$@"
fi
