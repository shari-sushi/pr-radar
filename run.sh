#!/bin/sh
# pr-radar をローカルで配信する。
# ポート・bind 先・公開ディレクトリを固定するためのスクリプトなので、
# 素の `python3 -m http.server` で代用しないこと（理由は README を参照）。
set -eu
cd "$(dirname "$0")"

PORT=49787

# トークンを暗号化する鍵。この端末だけに置き、リポジトリには入れない。
if [ ! -f key.js ]; then
  KEY=$(od -An -tx1 -N32 /dev/urandom | tr -d ' \n')
  printf 'window.PR_RADAR_KEY = "%s";\n' "$KEY" > key.js
  chmod 600 key.js
  echo "key.js を作成した（この端末専用の鍵・git 管理外）"
fi

echo "pr-radar → http://127.0.0.1:$PORT/"
exec python3 -m http.server "$PORT" --bind 127.0.0.1 --directory .
