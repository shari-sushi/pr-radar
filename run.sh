#!/bin/sh
# pr-radar をローカルで配信する。
# ポート・bind 先・公開ディレクトリを固定するためのスクリプトなので、
# 素の `python3 -m http.server` で代用しないこと（理由は README を参照）。
set -eu
cd "$(dirname "$0")"

PORT=49787

echo "pr-radar → http://127.0.0.1:$PORT/"
exec python3 -m http.server "$PORT" --bind 127.0.0.1 --directory .
