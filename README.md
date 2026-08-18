# pr-radar

example-org の複数リポジトリにまたがる open PR / draft PR を、1画面で見るための個人用ダッシュボード。

ビルドなし・依存なしの HTML 1枚。GitHub API を直接叩く。

PR 一覧は REST（リポジトリごとに1リクエスト）。カードに出すコメント数だけは、
REST の一覧レスポンスに入っていない（単体 GET にしかない）ため GraphQL で取る。
PR ごとに単体 GET すると N+1 になるが、GraphQL なら全リポジトリぶんが1リクエストで済む。

## 使い方

```sh
git clone git@github.com:<owner>/pr-radar.git
cd pr-radar
./run.sh
```

`http://127.0.0.1:49787/` を開いて、**設定** から次の2つを入れる。

- **アクセストークン** — 下記参照
- **Author** — 自分以外で追いたい人の GitHub ID（自分は `/user` から自動で入る）

登録した author は自分も含めてチェックボックスで並ぶ。チェックを入れた人の PR だけが「自分たちのPR」の2レーンに出て、外した人の PR は「ほかの人のPR」に回る。レビュー依頼レーンはチェックと無関係で、常に自分宛のものを拾う。

対象リポジトリと自動更新間隔も設定から変えられる。設定は `localStorage` に保存されるので、次回からは開くだけ。トークンは端末の外に出ない（送信先は `https://api.github.com` のみ）。

### なぜ `run.sh` を使うのか

`python3 -m http.server` を直接叩かず、スクリプト経由で起動する。3点を固定するため。

- **ポートを 49787 に固定する。** `localStorage` は「scheme + host + **port**」単位で分離される。あとから同じポートで別プロジェクトを配信すると、そのページから pr-radar の設定が読める。このポートは pr-radar 専用にする
- **`--bind 127.0.0.1` で自分の端末に閉じる。** `python3 -m http.server` の既定は全インターフェースへの bind なので、同じ Wi-Fi にいる誰でもこの画面を開けてしまう
- **`--directory public` で `public/` だけを配信する。** 配信されるものを列挙できる形に閉じ込めるため。リポジトリの直下を配信すると、`README.md` も `run.sh` も `.git/` も、あとから置いたメモも、全部 HTTP で読める

```text
pr-radar/
├── public/          ← ここだけが配信される
│   ├── index.html
│   ├── shari-porp-b.png
│   └── key.js       ← run.sh が生成。git 管理外
├── run.sh
├── README.md
└── .gitignore
```

`public/index.html` をブラウザで直接開いても表示はされるが、上の分離が効かないので `./run.sh` を使う。

## トークン

Fine-grained personal access token を推奨。

| 項目 | 値 |
| --- | --- |
| Resource owner | 対象リポジトリを持つ organization |
| Repository access | Only select repositories → 対象の3つ |
| Repository permissions | **Pull requests: Read-only** のみ |

`Metadata: Read-only` は自動で付く（外せない）。`Contents` は不要 —— ファイルの中身には触らないため。

organization をリソースオーナーにする場合、org 側で fine-grained PAT が許可されている必要があり、設定によってはオーナーの承認待ちになる。

classic token を使う場合はプライベートリポジトリに `repo` スコープが必要だが、これは書き込み権限も含むので推奨しない。SAML SSO 必須の org では発行後に Configure SSO で認可する。

## トークンの保管

`localStorage` に平文で置くと、同一オリジンの JavaScript から誰でも読める。初回起動時に `run.sh` が `public/key.js`（32バイトの乱数）を作り、トークンはこの鍵で AES-GCM 暗号化してから `pr-radar:token` に保存する。他の設定は `pr-radar:config` に平文のまま。

| | 保存場所 | git |
| --- | --- | --- |
| 鍵 | `public/key.js`（この端末のみ） | 管理外（`.gitignore`） |
| 暗号文 | `localStorage` | — |

守れるのは「**あとから同じポート（49787）で別のものを配信され、その localStorage を読まれる**」ケース。ポートは1プロセスしか掴めないので、そのとき pr-radar は動いておらず、攻撃者ページから `public/key.js` は取得できない。暗号文だけ持っていても復号できない。

守れないのは、**pr-radar を配信している最中に同一オリジンでコードを実行された**ケース。そのときは `public/key.js` も一緒に読まれる。だから `run.sh` の `--directory public` 固定（同一オリジンに他のものを置かない）とセットで意味を持つ。

鍵を作り直すとトークンは復号できなくなるので、入れ直しになる。それだけで済むので、**画面共有・配信・スクリーンショットなどで `public/key.js` の中身を晒したら作り直すこと。**

```sh
rm public/key.js && ./run.sh
```

`public/key.js` が無い、または `file://` で開いた場合は暗号化できないため、トークンを保存せずタブを閉じるまでの一時利用になる（設定画面に赤字で表示される）。

## 表示のしくみ

各リポジトリの `GET /repos/{owner}/{repo}/pulls?state=open` を叩き、クライアント側で4つのレーンに振り分ける。上から順に評価し、最初に当たったレーンに入る。

| レーン | 条件 |
| --- | --- |
| 依頼 | `requested_reviewers` に自分が入っている |
| 待ち | 作者がチェック済みの author・draft でない |
| 下書 | 作者がチェック済みの author・draft |
| 他 | 残り全部 |

「依頼」を先に判定するので、相方が自分にレビューを振った PR は「待ち」ではなく「依頼」に出る。

7日以上更新のない PR には停滞バッジ、14日以上なら赤で表示する。

## 既知の制約

- レビューを提出すると `requested_reviewers` から自分が外れるため、往復中の PR は「他」に落ちる。拾いたい場合は `GET /pulls/{n}/reviews` を追加で叩く必要がある（必要な権限は Pull requests: Read のまま）
- チーム宛のレビュー依頼（`requested_teams`）は見ていない。個人指名のみ
- 各リポジトリ 100件までしか取らない。ページングなし
- CI の状態やレビューの承認状況は一覧レスポンスに含まれないので表示していない

## キーボード

| キー | 動作 |
| --- | --- |
| `r` | 更新 |
| `s` | 設定の開閉 |
