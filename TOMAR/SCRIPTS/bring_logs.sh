#!/usr/bin/env bash
# Synchronise TOMAR's active and archived HV/rate logs into TOMAR/LOGS.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tomar_root="$(dirname "$script_dir")"
remote_host="${REMOTE_LOG_HOST:-tomar}"

mkdir -p "$tomar_root/LOGS"
rsync -avz "$remote_host:/home/rpcuser/logs/" "$tomar_root/LOGS/"
