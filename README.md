# JustNow System

JustNow System は、livedoor/NHN Japan が公開していた **yabitz - Yet Another Business Information Tracker Z** をベースに、現在の Ruby/MySQL 環境と Docker Compose 運用に合わせて更新したホスト管理 Web アプリケーションです。

オリジナル:

- https://github.com/livedoor/yabitz
- yabitz は 2011 年頃にライブドア社内で利用されていた、数千台規模のホスト・IP アドレス・ラック・ハードウェア情報を集約するためのアプリケーションです。

このリポジトリでは、元の設計やデータモデルを大きく変えずに、以下のような更新を加えています。

- Ruby 3.3 系対応
- MySQL 8.4 対応
- Docker Compose による VM 上の検証・運用環境
- 旧データ移行を想定した互換修正
- 現行ラック plugin の追加
- UI のモダン化
- JustNow System としてのロゴ・favicon・表示名変更

## 概要

yabitz/JustNow System は、ユーザ、主に企業が保有するホスト、IP アドレス、データセンタラック、サーバハードウェア、OS などの情報を管理するための Web アプリケーションです。

1000 台を超える規模になると、どのようなホストがどこに何台あり、どのように変わってきたのかをスプレッドシートだけで把握することは難しくなります。また、互いに矛盾する情報や欠損に気付くことも困難です。yabitz は、そのような情報を集約し、検索・確認・チェックするために作られました。

厳密な意味での構成管理、監視、プロビジョニングツールではありません。情報の集約、履歴確認、矛盾チェック、ラック/IP/ホストの見える化に特化しています。

## 主な機能

- 部署、コンテンツ、サービスの階層によるホスト分類
- ホスト情報の登録、検索、一覧表示
- ホスト状態の管理
  - 稼働中
  - 準備中
  - 非課金
  - 停止
  - 待機
  - 撤去依頼済
  - 撤去完了
  - 管理対象外
- DNS 名、IP アドレス、ラック位置、ハードウェア ID の管理
- ハードウェア種別、メモリ、ディスク容量、OS 情報の管理
- Local / Global / Virtual IP アドレス管理
- 仮想マシンとハイパーバイザの関連付け
- タグ、メモ、障害時連絡先の管理
- ホスト変更履歴と差分表示
- サービス単位での変更履歴確認
- IP セグメントやラック単位での利用状況確認
- ハードウェア種別、OS 別の集計
- ホスト情報の欠損や矛盾チェック
- JSON/CSV 出力
- plugin による認証、ラック形式、外部リンク、タグ拡張

## API

JustNow System には読み取り専用の JSON API v1 があります。

主な用途:

- ホスト、サービス、ラック、IP セグメント、IP アドレスの参照
- キーワード検索
- 更新日時を使った差分取得
- API トークンによる外部システム連携
- health endpoint による死活監視

詳しくは以下を参照してください。

- [API v1 読み取り専用API 日本語版](docs/api_v1_readonly.ja.md)
- [API v1 Readonly English version](docs/api_v1_readonly.md)

## 動作環境

このリポジトリでの現在の想定環境は以下です。

- Debian 12 などの Linux VM
- Docker / Docker Compose
- Ruby 3.3
- MySQL 8.4
- Rack / Sinatra
- Haml / Sass

アプリケーションは Docker Compose で起動する前提にしています。Windows 端末上で Ruby を直接動かす運用は想定していません。

## Docker Compose での起動

### 1. リポジトリを取得

```bash
git clone https://github.com/pench999/justnow-system.git
cd justnow-system
```

### 2. `.env` を作成

```bash
cp .env.example .env
vi .env
```

例:

```env
YABITZ_DB_NAME=yabitz
YABITZ_DB_USER=yabitz
YABITZ_DB_PASSWORD=change-me
MYSQL_ROOT_PASSWORD=change-root-password
```

### 3. DB を起動

```bash
docker compose up -d db
docker compose ps
```

DB が `healthy` になるまで待ちます。

### 4. DB スキーマを作成

初回構築の場合は、app コンテナからスキーマ作成を実行します。

```bash
docker compose run --rm app bundle exec ruby scripts/db_schema.rb
```

既存の本番/検証データをインポートする場合は、空スキーマ作成ではなく、既存 DB の dump を MySQL コンテナへ投入してください。

例:

```bash
docker compose exec -T db mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" "${YABITZ_DB_NAME}" < backup.sql
```

### 5. アプリを起動

```bash
docker compose build app
docker compose up -d app
docker compose logs --tail=100 app
```

デフォルトではホスト側の `127.0.0.1:9292` に公開されます。

```bash
curl -I http://127.0.0.1:9292/ybz
```

HTTP 200 が返れば起動しています。

## 認証とユーザー

yabitz/JustNow System は、ホスト情報の登録・編集などに認証を要求します。

主な選択肢は以下です。

- LDAP / Active Directory 連携
- `instant_membersource` による簡易ユーザーマスタ
- 独自 auth plugin

ログインに成功したユーザーは `auth_info` に自動登録されます。管理者権限は、画面右上のメニューから「管理項目」→「ユーザリスト」で確認・変更できます。

ADMIN 権限を持つユーザーがまだ存在しない場合、ログイン済みユーザーを管理者として扱う互換動作があります。検証環境ではこの動作を利用できますが、本番運用では明示的に管理者を設定してください。

## 初期登録が必要なマスタ

ホスト管理を行うには、最低限以下を登録します。

- 部署
  - 使用ホスト数やユニット数を集計する大きな単位
- コンテンツ
  - 部署配下でサービスをまとめる単位
- サービス
  - ホストを所属させる基本単位
- HW 情報
  - サーバ筐体名、U 数、課金/集計用の論理ユニットなど
- OS 情報
  - ホスト登録時に選択する OS 名

必要に応じて以下も登録します。

- Local NW
- Global NW
- ラック
- 連絡先
- 連絡先メンバ

## ラック plugin

オリジナルの yabitz には 42U 標準ラックの plugin が同梱されていました。

JustNow System では、既存データ移行に合わせて以下のラック形式も追加しています。

- `STANDARD36U`
- `STANDARD46U`
- `STANDARD47U`
- 福岡向けラック形式
- 越谷向けラック形式

ラック形式は `lib/yabitz/plugin/` 配下の rack plugin で拡張できます。データセンタごとにラック番号・ラックユニット番号の規則が異なる場合は、同様の plugin を追加してください。

## データ移行

既存 yabitz / JustNow 環境からの移行では、MySQL dump を Docker Compose の MySQL 8.4 環境にインポートして検証します。

注意点:

- MySQL 8.4 は strict mode が有効なため、古い MySQL では許容されていた空文字の数値カラム挿入などがエラーになる場合があります。
- 旧データに未知のホスト type、未設定 service、未対応ラック形式が含まれる場合があります。
- 既存 plugin のラック形式は移行前に確認してください。

このリポジトリでは、移行中に確認された互換性問題をいくつか修正しています。

- `auth_log.oid` への空文字挿入を避ける修正
- Rack/Sinatra/Haml 更新に伴う Haml 内 helper 定義の修正
- 未知の host type や service 未設定ホストを含むラック表示への耐性追加

## 運用メモ

### アプリの再ビルド

```bash
docker compose build app
docker compose up -d app
```

### ログ確認

```bash
docker compose logs --tail=100 app
docker compose logs --tail=100 db
```

### Ruby 構文チェック

```bash
docker compose exec app ruby -c lib/yabitz/plugin/rack_fairway.rb
docker compose exec app ruby -c lib/yabitz/controller/rack.rb
```

### アプリ読み込み確認

```bash
docker compose exec app bundle exec ruby -e "require './lib/yabitz/app'; puts 'OK'"
```

## plugin について

yabitz は plugin による拡張を前提にしています。

主な plugin 種別:

- `:config`
  - DB 接続、LDAP 接続、表示クレジットなど
- `:auth`
  - 認証
- `:member`
  - 連絡先メンバ情報の参照
- `:racktype`
  - ラック番号、ラックユニット番号、ラック表示形式
- `:hostlinkparts`
  - ホスト詳細画面への外部システムリンク追加
- `:customtag`
  - 独自タグ処理

詳細は `lib/yabitz/plugin.rb` と `lib/yabitz/plugin/` 配下の各 plugin を参照してください。

## オリジナル yabitz からの主な変更

- Ruby 1.9/2.x 前提から Ruby 3.3 前提へ更新
- MySQL 5.1 前提から MySQL 8.4 前提へ更新
- `mysql2-cs-bind` 依存を整理
- LDAP ライブラリを現行環境向けに更新
- Dockerfile / compose.yaml / Docker 用 config plugin を追加
- Rack/Sinatra/Haml の現行バージョンに合わせて route / template を修正
- UI を現代的な見た目へ調整
- JustNow System としてロゴ、favicon、フッター、タイトル表記を変更
- 現行運用で使用しているラック plugin を追加

## FAQ

### yabitz とは何ですか

Yet Another Business Information Tracker Z の略です。オリジナル README では「ヤビツ」という名前について、ヤビツ峠へのリンクが紹介されていました。

http://ja.wikipedia.org/wiki/%E3%83%A4%E3%83%93%E3%83%84%E5%B3%A0

### JustNow System とは何ですか

このリポジトリにおける、yabitz ベースの現行運用向け名称です。内部の Ruby 名前空間や URL には互換性維持のため `Yabitz` / `/ybz` が残っています。

## License

This project is based on livedoor/yabitz.

Original copyright:

```text
Copyright 2011- NHN Japan Corp.
```

Current customization:

```text
JustNow System / 2026 imagenzai at fairway-corp.co.jp
```

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
