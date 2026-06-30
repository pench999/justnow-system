# JustNow System API v1 読み取り専用API

JustNow System は `/ybz/api/v1` 配下に読み取り専用のJSON APIを提供します。
このAPIは、資産情報の参照、外部システムとの同期、監視、簡易的な社内連携で使うことを想定しています。

すべてのendpointは読み取り専用です。データの登録、更新、削除は行いません。

## 認証

利用できる認証方式は以下です。

- WebセッションCookie: ブラウザで動作確認する場合に利用します。
- HTTP Basic認証: 簡単な社内スクリプトで利用できます。
- Bearer APIトークン: 外部連携や定期実行ジョブではこの方式を推奨します。

APIトークンは初期状態では無効です。利用する場合は `.env` などで次の環境変数を設定します。

```text
YABITZ_API_TOKEN=long-random-token
YABITZ_API_TOKENS=sync-job:long-random-token,monitoring:another-long-random-token
```

`YABITZ_API_TOKEN` は単一トークン用の簡易設定です。
`YABITZ_API_TOKENS` はカンマ区切りで複数のトークンを設定できます。
各要素は `token` または `name:token` の形式です。`name` は内部的な操作ユーザー名として扱われます。

APIトークンは次のどちらかのヘッダで送信します。

```text
Authorization: Bearer long-random-token
X-JustNow-API-Token: long-random-token
```

Basic認証のパスワードやAPIトークンを送信するため、本番ではHTTPSまたは閉域ネットワークでの利用を推奨します。

## 基本レスポンス形式

一覧APIは `data` と `meta` を返します。

```json
{
  "data": [],
  "meta": {
    "type": "hosts",
    "count": 100,
    "total": 350,
    "limit": 100,
    "offset": 0
  }
}
```

詳細APIは単一オブジェクトを返します。

```json
{
  "data": {}
}
```

エラー時は安定したJSON形式で返します。

```json
{
  "error": {
    "code": "not_found",
    "message": "host not found"
  }
}
```

主なHTTPステータスコードは以下です。

- `200`: 成功
- `401`: 認証が必要、またはトークンが不正
- `404`: endpointまたは対象リソースが存在しない
- `406`: クエリパラメータが不正

## 共通クエリパラメータ

- `limit`: 取得件数の上限です。デフォルトは `100`、最大は `1000` です。
- `offset`: 先頭から読み飛ばす件数です。デフォルトは `0` です。
- `q`: キーワード検索です。複数語を指定した場合はAND条件として扱います。
- `updated_since` または `since`: 指定日時以降に変更されたoidのレコードを返します。
- `updated_until` または `until`: 差分取得時の終了日時です。
- `include_removed`: `true` を指定すると、差分取得で削除済みレコードも含めます。

日時は次のような形式を利用できます。

```text
2026-06-30 10:00:00
2026-06-30T10:00:00+09:00
```

## Endpoint一覧

```text
GET /ybz/api/v1
GET /ybz/api/v1/health
GET /ybz/api/v1/hosts
GET /ybz/api/v1/hosts/:oid
GET /ybz/api/v1/services
GET /ybz/api/v1/services/:oid
GET /ybz/api/v1/racks
GET /ybz/api/v1/racks/:oid
GET /ybz/api/v1/ipsegments
GET /ybz/api/v1/ipsegments/:oid
GET /ybz/api/v1/ipaddresses
GET /ybz/api/v1/ipaddresses/:address
GET /ybz/api/v1/changes/:resource
```

## ヘルスチェック

監視用途では、認証付きのhealth endpointを利用できます。

```text
GET /ybz/api/v1/health
```

レスポンス例:

```json
{
  "data": {
    "status": "ok",
    "version": "v1",
    "readonly": true,
    "time": "2026-06-30T10:00:00+09:00"
  }
}
```

## 絞り込み

ホスト:

```text
GET /ybz/api/v1/hosts?q=web
GET /ybz/api/v1/hosts?status=IN_SERVICE
GET /ybz/api/v1/hosts?service_oid=123
```

サービス:

```text
GET /ybz/api/v1/services?q=mail
```

ラック:

```text
GET /ybz/api/v1/racks?q=Q01
```

IPセグメント:

```text
GET /ybz/api/v1/ipsegments?q=192.168.22
GET /ybz/api/v1/ipsegments?area=local
GET /ybz/api/v1/ipsegments?area=global
```

IPアドレス:

```text
GET /ybz/api/v1/ipaddresses?q=192.168.22
```

## 差分取得

各一覧APIでは `updated_since` を指定できます。

```text
GET /ybz/api/v1/hosts?updated_since=2026-06-30T10:00:00+09:00
GET /ybz/api/v1/services?updated_since=2026-06-30T10:00:00+09:00
```

同期ジョブでは専用のchanges endpointを利用できます。

```text
GET /ybz/api/v1/changes/hosts?since=2026-06-30T10:00:00+09:00
GET /ybz/api/v1/changes/services?since=2026-06-30T10:00:00+09:00
GET /ybz/api/v1/changes/racks?since=2026-06-30T10:00:00+09:00
GET /ybz/api/v1/changes/ipsegments?since=2026-06-30T10:00:00+09:00
GET /ybz/api/v1/changes/ipaddresses?since=2026-06-30T10:00:00+09:00
```

通常、削除済みレコードは返りません。同期先でも削除を反映したい場合は `include_removed=true` を追加します。

```text
GET /ybz/api/v1/changes/hosts?since=2026-06-30T10:00:00+09:00&include_removed=true
```

## curl例

Basic認証:

```bash
curl -u USERNAME:PASSWORD \
  'http://localhost:9292/ybz/api/v1/services?limit=10'

curl -u USERNAME:PASSWORD \
  'http://localhost:9292/ybz/api/v1/hosts?status=IN_SERVICE&limit=20'
```

Bearerトークン:

```bash
curl -H 'Authorization: Bearer long-random-token' \
  'http://localhost:9292/ybz/api/v1/hosts?limit=10'

curl -H 'Authorization: Bearer long-random-token' \
  'http://localhost:9292/ybz/api/v1/health'
```

専用トークンヘッダ:

```bash
curl -H 'X-JustNow-API-Token: long-random-token' \
  'http://localhost:9292/ybz/api/v1/services?limit=10'
```

検索と差分取得:

```bash
curl -H 'Authorization: Bearer long-random-token' \
  'http://localhost:9292/ybz/api/v1/hosts?q=web&limit=20'

curl -H 'Authorization: Bearer long-random-token' \
  'http://localhost:9292/ybz/api/v1/changes/hosts?since=2026-06-30T10:00:00+09:00'
```

## PowerShell例

Bearerトークン:

```powershell
$headers = @{ Authorization = 'Bearer long-random-token' }
Invoke-RestMethod -Headers $headers -Uri 'http://localhost:9292/ybz/api/v1/hosts?limit=10'
```

ヘルスチェック:

```powershell
$headers = @{ Authorization = 'Bearer long-random-token' }
Invoke-RestMethod -Headers $headers -Uri 'http://localhost:9292/ybz/api/v1/health'
```

## 同期ジョブの考え方

同期ジョブでは、前回正常終了した日時を保存し、次回実行時に `since` として利用します。

```text
1. 前回正常終了した同期日時をローカルストレージなどから読み込む。
2. /ybz/api/v1/changes/hosts?since=<timestamp> を呼び出す。
3. 返却されたレコードを同期先システムへ反映する。
4. 同期が正常終了した場合だけ、現在時刻を次回用に保存する。
```

同期対象の時間範囲を固定したい場合は `updated_until` または `until` を指定してください。
