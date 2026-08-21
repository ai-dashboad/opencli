#!/bin/bash

# Set "chatgpt.cliExecutable": "/Users/<USERNAME>/code/opencli/scripts/debug-opencli.sh" in VSCode settings to always get the 
# latest opencli-rs binary when debugging OpenCLI Extension.


set -euo pipefail

OPENCLI_RS_DIR=$(realpath "$(dirname "$0")/../opencli-rs")
(cd "$OPENCLI_RS_DIR" && cargo run --quiet --bin opencli -- "$@")