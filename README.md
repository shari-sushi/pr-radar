# pr-radar

example-org の複数リポジトリにまたがる open PR / draft PR を、1画面で見るための個人用ダッシュボード。

ビルドなし・依存なしの HTML 1枚。GitHub REST API を直接叩く。

## 使い方

```sh
git clone git@github.com:<owner>/pr-radar.git
cd pr-radar
python3 -m http.server 8787
```

`http://localhost:8787/` を開いて、**設定** から次の2つを入れる。

- **アクセストークン** — 下記参照
- **一緒に見る人** — 自分以外で追いたい人の GitHub ID（自分は `/user` から自動で入る）

対象リポジトリと自動更新間隔も設定から変えられる。設定は `localStorage`（キー `pr-radar:config`）に保存されるので、次回からは開くだけ。トークンは端末の外に出ない。

`index.html` をブラウザで直接開いても動くが、`http://` で配信したほうが行儀がいい。

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
