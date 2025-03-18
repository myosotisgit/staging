#!/bin/bash
# Copyright 2025 - Myosotis ICT
# Inspired by the install script by Teleport
# This script fetches and runs the latest ubstage install script from github

# The script is wrapped inside a function to protect against the connection being interrupted
# in the middle of the stream.

set -euo pipefail

# download uses curl or wget to download a teleport binary
download() {
    URL=$1
    TMP_PATH=$2

    echo "Downloading $URL"
    if type curl &>/dev/null; then
        set -x
        # shellcheck disable=SC2086
        $CURL -o "$TMP_PATH" "$URL"
    else
        set -x
        # shellcheck disable=SC2086
        $CURL -O "$TMP_PATH" "$URL"
    fi
    set +x
}


fetch_and_run() {
    # require curl/wget
    CURL=""
    if type curl &>/dev/null; then
        CURL="curl -fL"
    elif type wget &>/dev/null; then
        CURL="wget"
    fi
    if [ -z "$CURL" ]; then
        echo "ERROR: This script requires either curl or wget in order to download files. Please install one of them and try again."
        exit 1
    fi

    # fetch install script
    TEMP_DIR=$(mktemp -d -t ubstage-XXXXXXXXXX)
    SCRIPT_FILENAME="install.sh"
    SCRIPT_PATH="${TEMP_DIR}/${SCRIPT_FILENAME}"
    URL="https://cdn.teleport.dev/${SCRIPT_FILENAME}"
    download "${URL}" "${SCRIPT_PATH}"

    

    set -x
    cd "$TEMP_DIR"
    $SHA_COMMAND -c "$TMP_CHECKSUM"
    cd -
    set +x

    # run install script
    bash "${SCRIPT_PATH}" "$TELEPORT_VERSION" "$TELEPORT_EDITION"
}

fetch_and_run