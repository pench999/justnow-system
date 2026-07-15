# JustNow System 管理者向け運用ドキュメント

このドキュメントは、Docker Compose で運用している JustNow System の管理者向け手順です。

対象環境:

- Debian 12 などの Linux VM
- Docker / Docker Compose
- `web` コンテナ: nginx Basic 認証とリバースプロキシ
- `app` コンテナ: JustNow System 本体
- `db` コンテナ: MySQL 8.4

## 基本方針

本番環境では、アプリ本体の `app` サービスを直接外部公開せず、必ず `web` サービス経由でアクセスさせます。

`web` サービスは nginx Basic 認証を行い、認証済みユーザー名を `X-Remote-User` として `app` へ渡します。`app` は trusted proxy header 認証を前提に動作します。

通常の公開ポートは `.env` の `JUSTNOW_HTTP_PORT` で決まります。未指定の場合はホスト側 `9292` 番ポートで公開されます。

## 日常確認

コンテナ状態を確認します。

```bash
cd ~/justnow-system
docker compose ps
```

アプリの応答を確認します。

```bash
curl -I http://127.0.0.1:9292/ybz
```

`HTTP/1.1 200 OK` が返れば、nginx 経由でアプリが応答しています。

ログを確認します。

```bash
docker compose logs --tail=100 web
docker compose logs --tail=100 app
docker compose logs --tail=100 db
```

リアルタイムに確認する場合:

```bash
docker compose logs -f app
```

## デプロイ手順

ソースは GitHub の `main` ブランチを正とし、本番 VM 側で pull して反映します。

```bash
cd ~/justnow-system
git status -sb
git pull --ff-only origin main
docker compose build app
docker compose up -d app web
docker compose ps
curl -I http://127.0.0.1:9292/ybz
```

注意:

- この構成ではソースコードを Docker image に `COPY` しているため、ソース変更後は `docker compose build app` が必要です。
- `.env`、DB dump、ログ、秘密鍵、認証情報は Git に commit しないでください。
- `git pull --ff-only` が失敗した場合は、VM 上に未反映のローカル変更がある可能性があります。内容を確認してから対応してください。

## 再起動

アプリだけ再起動します。

```bash
docker compose restart app
```

nginx も含めて再起動します。

```bash
docker compose restart app web
```

DB を含めて全体を再作成します。

```bash
docker compose up -d
```

通常運用では、DB コンテナの削除や volume 削除は行わないでください。

## DB の保存場所

MySQL のデータは Docker の名前付き volume `mysql-data` に保存されます。

volume 名は Compose project 名が付くため、通常は以下のような名前になります。

```bash
docker volume ls | grep mysql-data
```

実体パスを確認する場合:

```bash
docker volume inspect justnow-system_mysql-data
```

`Mountpoint` に表示されるディレクトリがホスト上の実体です。ただし、通常はこのディレクトリを直接編集しません。DB 操作は `mysql`、`mysqldump`、または `docker compose exec db` 経由で行います。

## DB へ直接 SQL を実行する

`.env` を読み込んで root ユーザーで MySQL に接続します。

```bash
cd ~/justnow-system
set -a
. ./.env
set +a
docker compose exec db mysql -uroot -p"$MYSQL_ROOT_PASSWORD" "$YABITZ_DB_NAME"
```

1 SQL だけ実行する例:

```bash
docker compose exec db mysql -uroot -p"$MYSQL_ROOT_PASSWORD" "$YABITZ_DB_NAME" \
  -e "SELECT COUNT(*) FROM auth_info;"
```

## バックアップ

バックアップは `mysqldump` で取得します。

```bash
cd ~/justnow-system
set -a
. ./.env
set +a
mkdir -p backups
docker compose exec db sh -c 'mysqldump -uroot -p"$MYSQL_ROOT_PASSWORD" --single-transaction "$MYSQL_DATABASE"' \
  > "backups/justnow-$(date +%Y%m%d-%H%M%S).sql"
```

取得した dump は、必要に応じて VM 外へ退避してください。

## リストア

原則として、本番 DB へ直接上書きリストアする前に、検証環境で確認してください。

新しい環境へ投入する例:

```bash
cd ~/justnow-system
set -a
. ./.env
set +a
docker compose exec -T db mysql -uroot -p"$MYSQL_ROOT_PASSWORD" "$YABITZ_DB_NAME" < backup.sql
```

既存データを上書きする場合は、作業前に必ず現状の dump を取得してください。

## Basic 認証ユーザー管理

Basic 認証ユーザーは、ADMIN 権限を持つユーザーでログイン後、画面右上の「管理項目」から管理できます。

初回作成や緊急時は、VM 上で `.htpasswd` を直接作成できます。

初回作成:

```bash
cd ~/justnow-system
docker run --rm -it -v "$PWD/docker/nginx:/work" httpd:2.4-alpine \
  htpasswd -cB /work/.htpasswd USERNAME
chmod 644 docker/nginx/.htpasswd
docker compose restart web
```

ユーザー追加:

```bash
docker run --rm -it -v "$PWD/docker/nginx:/work" httpd:2.4-alpine \
  htpasswd -B /work/.htpasswd USERNAME
chmod 644 docker/nginx/.htpasswd
docker compose restart web
```

ユーザー削除:

```bash
docker run --rm -it -v "$PWD/docker/nginx:/work" httpd:2.4-alpine \
  htpasswd -D /work/.htpasswd USERNAME
docker compose restart web
```

## アプリ側ユーザーと権限

Basic 認証に成功したユーザーは、アプリ側の `auth_info` テーブルに自動登録されます。

管理者権限は、アプリ画面の「管理項目」から設定します。

注意:

- Basic 認証ユーザーとアプリ側ユーザーは別管理です。
- Basic 認証を削除しても、`auth_info` の行は自動削除されません。
- ホスト詳細メモは ADMIN 権限を持つユーザーだけが閲覧・編集できます。

`auth_info` を確認する例:

```bash
docker compose exec db mysql -uroot -p"$MYSQL_ROOT_PASSWORD" "$YABITZ_DB_NAME" \
  -e "SELECT * FROM auth_info;"
```

特定ユーザーを削除する例:

```bash
docker compose exec db mysql -uroot -p"$MYSQL_ROOT_PASSWORD" "$YABITZ_DB_NAME" \
  -e "DELETE FROM auth_info WHERE username = 'USERNAME';"
```

## API トークン

読み取り専用 API v1 でトークン認証を使う場合は、`.env` に設定します。

単一トークン:

```env
YABITZ_API_TOKEN=change-this-to-a-long-random-token
```

用途別トークン:

```env
YABITZ_API_TOKENS=sync-job:token1,monitoring:token2
```

`.env` 変更後は `app` を再作成します。

```bash
docker compose up -d app
```

API の詳細は `docs/api_v1_readonly.ja.md` を参照してください。

## 障害時の確認順

画面が表示されない場合は、以下の順で切り分けます。

1. コンテナ状態を確認

```bash
docker compose ps
```

2. nginx 経由の応答を確認

```bash
curl -I http://127.0.0.1:9292/ybz
```

3. app コンテナのログを確認

```bash
docker compose logs --tail=200 app
```

4. web コンテナのログを確認

```bash
docker compose logs --tail=200 web
```

5. DB の health 状態とログを確認

```bash
docker compose ps db
docker compose logs --tail=200 db
```

6. リバースプロキシや CDN を使っている場合は、直接 `127.0.0.1:9292` と外部 URL の差を確認

```bash
curl -I http://127.0.0.1:9292/ybz
curl -I https://example.com/ybz
```

直接アクセスで正常、外部 URL だけ異常な場合は、上位リバースプロキシ、CDN cache、TLS、header 転送設定を確認してください。

## よくある対応

### ソースを更新したのに画面が変わらない

`app` image を再 build していない可能性があります。

```bash
docker compose build app
docker compose up -d app web
```

Cloudflare などの CDN を経由している場合は、cache purge も確認してください。

### Internal Server Error が出る

まず app log を確認します。

```bash
docker compose logs --tail=200 app
```

DB データ、rack plugin、古い移行データ、権限判定、テンプレート表示のどこで落ちているかをログから確認します。

### ログアウト後にアクセスできない

nginx Basic 認証のユーザーが存在するか、`.htpasswd` が `web` コンテナから読めるかを確認します。

```bash
ls -l docker/nginx/.htpasswd
docker compose logs --tail=100 web
```

### 時刻表示がずれる

アプリ側の表示時刻は日本時間で表示する前提です。コンテナやホストの時刻差が疑わしい場合は確認します。

```bash
date
docker compose exec app date
docker compose exec db date
```

## セキュリティ注意点

- `app` を直接インターネットや社内ネットワークへ公開しないでください。
- 外部公開は `web` または別の信頼済みリバースプロキシ経由に限定してください。
- `.env`、`.htpasswd`、DB dump は Git に commit しないでください。
- 管理者権限は必要最小限のユーザーに限定してください。
- API トークンは十分長いランダム文字列にし、用途別に分けてください。
- 退職者や不要ユーザーは Basic 認証と `auth_info` の両方を確認してください。
