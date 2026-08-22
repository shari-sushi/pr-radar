#!/bin/sh
# pr-radar をローカルで配信する。
# bind 先・公開ディレクトリを固定し、ポートを1つに決めるためのスクリプトなので、
# 素の `python3 -m http.server` で代用しないこと（理由は README を参照）。
set -eu
cd "$(dirname "$0")"

# ポートを書いておくファイル。key.js と同じ流儀で、この端末だけに置く（git 管理外）。
# 中身は `port=50000` の1行。`last=` は run.sh が書く（前回使ったポート）。
PORT_FILE=port.local
DEFAULT_PORT=49787
# 選べる範囲。dynamic / private range に限る。3000 や 8080 を選ぶと、
# あとからそこで別プロジェクトを配信したときに pr-radar の localStorage を渡すことになる
MIN_PORT=49152
MAX_PORT=65535

die() { echo "$@" >&2; exit 1; }

# `key=` の最後の1行の値。ファイルが無ければ空。
# 数字だけを拾う書き方にはしない —— `port=abc` を「指定なし」として扱うと、
# 既定ポートで黙って起動して「設定が消えた」ことになる
read_key() {
  [ -f "$PORT_FILE" ] || return 0
  sed -n "s/^$1=//p" "$PORT_FILE" | tail -n 1 | tr -d '[:space:]'
}

is_port() {
  case ${1:-} in ''|*[!0-9]*) return 1 ;; esac
}

PORT=$(read_key port)
[ -n "$PORT" ] || PORT=${PR_RADAR_PORT:-$DEFAULT_PORT}
LAST=$(read_key last)

is_port "$PORT" || die "ポートが数字になっていない: $PORT
$PORT_FILE の port= の行を直す（既定に落として黙って起動はしない）。"
# last= は run.sh が書く行。人の手で壊れていたら、無かったことにして進む
is_port "$LAST" || LAST=""
if [ "$PORT" -lt "$MIN_PORT" ] || [ "$PORT" -gt "$MAX_PORT" ]; then
  die "ポートは $MIN_PORT〜$MAX_PORT から選ぶ（指定: $PORT）。
この範囲の外は、あとから別プロジェクトが同じポートを使いやすい。
localStorage はポート単位で分かれるので、そのページから pr-radar の設定が読める。"
fi

# localStorage は scheme + host + port で分かれる。ポートを変えると別オリジンになり、
# 設定もトークンもメモも全部空で立ち上がる。アプリ側から前のオリジンは読めないので、
# 黙って起動して「消えた」と思わせないよう、配信を始める前に言う
if [ -n "$LAST" ] && [ "$LAST" != "$PORT" ]; then
  echo "ポートが $LAST から $PORT に変わっている。"
  echo "  ・設定・トークン・メモ・待ちの印は引き継がれない（全部空で始まる）"
  echo "  ・消えたのではなく $LAST 側に残っている。$PORT_FILE を port=$LAST に戻せば元に戻る"
  echo "  ・アカウントを分けて使いたいなら、これが狙いどおり"
  if [ -t 0 ]; then
    printf 'このまま %s で起動する? [y/N] ' "$PORT"
    read -r answer
    case $answer in
      y|Y|yes|YES) ;;
      *) die "やめた。$PORT_FILE を直してから叩き直す。" ;;
    esac
  fi
fi

# トークンを暗号化する鍵。この端末だけに置き、リポジトリには入れない。
if [ ! -f public/key.js ]; then
  KEY=$(od -An -tx1 -N32 /dev/urandom | tr -d ' \n')
  printf 'window.PR_RADAR_KEY = "%s";\n' "$KEY" > public/key.js
  chmod 600 public/key.js
  echo "public/key.js を作成した（この端末専用の鍵・git 管理外）"
fi

# 埋まっているときの python3 -m http.server の出力は traceback なので、
# 何が起きたか分かる形にするために先に試しに掴んでみる
if ! python3 - "$PORT" <<'PY'
import socket, sys
s = socket.socket()
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
try:
    s.bind(("127.0.0.1", int(sys.argv[1])))
except OSError:
    sys.exit(1)
PY
then
  die "ポート $PORT は使用中。ほかで動いている pr-radar を止めるか、$PORT_FILE で別のポートにする。"
fi

# 次に立てたときに変化を見つけられるように、使うポートを覚えておく。
# port= の行とコメントは残す
{
  if [ -f "$PORT_FILE" ]; then grep -v '^last=' "$PORT_FILE" || true; fi
  echo "last=$PORT"
} > "$PORT_FILE.tmp"
mv "$PORT_FILE.tmp" "$PORT_FILE"

echo "pr-radar → http://127.0.0.1:$PORT/"
exec python3 -m http.server "$PORT" --bind 127.0.0.1 --directory public
