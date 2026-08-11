# pr-radar

example-org の複数リポジトリにまたがる open PR / draft PR を、1画面で見るための個人用ダッシュボード。

ビルドなし・依存なしの HTML 1枚。GitHub REST API を直接叩く。

## 使い方

```sh
git clone git@github.com:<owner>/pr-radar.git
cd pr-radar
./run.sh
```

`http://127.0.0.1:49787/` を開いて、**設定** から次の2つを入れる。

- **アクセストークン** — 下記参照
- **一緒に見る人** — 自分以外で追いたい人の GitHub ID（自分は `/user` から自動で入る）

対象リポジトリと自動更新間隔も設定から変えられる。設定は `localStorage`（キー `pr-radar:config`）に保存されるので、次回からは開くだけ。トークンは端末の外に出ない。

### なぜ `run.sh` を使うのか

`python3 -m http.server` を直接叩かず、スクリプト経由で起動する。3点を固定するため。

- **ポートを 49787 に固定する。** `localStorage` は「scheme + host + **port**」単位で分離される。あとから同じポートで別プロジェクトを配信すると、そのページから pr-radar の設定が読める。このポートは pr-radar 専用にする
- **`--bind 127.0.0.1` で自分の端末に閉じる。** `python3 -m http.server` の既定は全インターフェースへの bind なので、同じ Wi-Fi にいる誰でもこの画面を開けてしまう
- **`--directory` でこのディレクトリだけを配信する。** 親ディレクトリごと配信すると、隣のプロジェクトが pr-radar と同一オリジンになる

`index.html` をブラウザで直接開いても表示はされるが、上の分離が効かないので `./run.sh` を使う。

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

## 表示のしくみ

各リポジトリの `GET /repos/{owner}/{repo}/pulls?state=open` を叩き、クライアント側で4つのレーンに振り分ける。上から順に評価し、最初に当たったレーンに入る。

| レーン | 条件 |
| --- | --- |
| 依頼 | `requested_reviewers` に自分が入っている |
| 待ち | 作者が自分たち・draft でない |
| 下書 | 作者が自分たち・draft |
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
