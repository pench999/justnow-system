# VM Docker Compose deployment

## Recommended flow

Commit this source to a private Git repository first, then deploy by cloning it on the VM.

Reasons:

- You can reproduce exactly what is deployed.
- Rollback is just checking out the previous tag or commit.
- VM-local edits and secrets stay separate.
- The Docker image build has stable inputs.

Do not commit `.env`, database dumps, logs, or private LDAP settings.

## VM baseline

- Ubuntu 24.04 LTS or 26.04 LTS
- Docker Engine with Compose plugin
- 2 vCPU / 4 GB RAM minimum for a small internal deployment
- Persistent disk sized for MySQL data and backups

## Initial setup

```sh
git clone git@github.com:YOUR_ORG/yabitz.git
cd yabitz
cp .env.example .env
vi .env
docker compose build
docker compose up -d db
docker compose run --rm app bundle exec ruby scripts/db_tables.rb
docker compose up -d
```

`scripts/db_tables.rb` creates tables in the empty database created by the MySQL container. Run it only once for a new empty deployment.

`scripts/db_schema.rb` recreates the configured database and needs create/drop privileges. Avoid it for normal Compose deployment.

## Check

```sh
docker compose ps
docker compose logs -f app
curl -I http://127.0.0.1:9292/ybz
```

## nginx reverse proxy example

Expose the app through nginx on the VM:

```nginx
server {
    listen 80;
    server_name yabitz.example.internal;

    location / {
        proxy_pass http://127.0.0.1:9292;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Add TLS with your normal certificate process, such as Let's Encrypt or an internal CA.

## Operations

Deploy a new version:

```sh
git pull --ff-only
docker compose build app
docker compose up -d app
```

Backup:

```sh
docker compose exec db sh -c 'mysqldump -uroot -p"$MYSQL_ROOT_PASSWORD" --single-transaction "$MYSQL_DATABASE"' > backup.sql
```

Restore into a new environment first; avoid restoring directly over production without a rollback plan.
