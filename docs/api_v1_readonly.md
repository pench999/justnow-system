# JustNow System API v1 Readonly

Japanese version: [api_v1_readonly.ja.md](api_v1_readonly.ja.md)

JustNow System provides a readonly JSON API under `/ybz/api/v1`.
The API is intended for inventory lookup, synchronization jobs, monitoring,
and small internal integrations.

All endpoints are read-only. They do not create, update, or delete records.

## Authentication

Supported authentication methods:

- Web session cookie: useful when testing from a browser.
- HTTP Basic authentication: useful for simple internal scripts.
- Bearer API token: recommended for external systems and scheduled jobs.

API tokens are disabled by default. Set one of the following environment
variables to enable them:

```text
YABITZ_API_TOKEN=long-random-token
YABITZ_API_TOKENS=sync-job:long-random-token,monitoring:another-long-random-token
```

`YABITZ_API_TOKEN` is a shorthand for a single unnamed token.
`YABITZ_API_TOKENS` accepts comma-separated entries. Each entry can be either
`token` or `name:token`; the optional name is used internally as the request
operator name.

Send the token with either header:

```text
Authorization: Bearer long-random-token
X-JustNow-API-Token: long-random-token
```

Use HTTPS or a private network when sending Basic credentials or API tokens.

## Base Response Format

List endpoints return `data` and `meta`:

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

Detail endpoints return a single object:

```json
{
  "data": {}
}
```

Errors return a stable JSON object:

```json
{
  "error": {
    "code": "not_found",
    "message": "host not found"
  }
}
```

Common status codes:

- `200`: success
- `401`: authentication required or invalid token
- `404`: endpoint or resource not found
- `406`: invalid query parameter

## Common Query Parameters

- `limit`: maximum number of records to return. Default is `100`, maximum is `1000`.
- `offset`: number of records to skip. Default is `0`.
- `q`: keyword search. Multiple words are treated as AND conditions.
- `updated_since` or `since`: return records whose oid has changed since the specified timestamp.
- `updated_until` or `until`: optional end timestamp for change filtering.
- `include_removed`: set to `true` to include removed records in change results.

Timestamp values can be passed in common formats such as:

```text
2026-06-30 10:00:00
2026-06-30T10:00:00+09:00
```

## Endpoints

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

## Health Check

Use the health endpoint for authenticated monitoring:

```text
GET /ybz/api/v1/health
```

Example response:

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

## Filters

Hosts:

```text
GET /ybz/api/v1/hosts?q=web
GET /ybz/api/v1/hosts?status=IN_SERVICE
GET /ybz/api/v1/hosts?service_oid=123
```

Services:

```text
GET /ybz/api/v1/services?q=mail
```

Racks:

```text
GET /ybz/api/v1/racks?q=Q01
```

IP segments:

```text
GET /ybz/api/v1/ipsegments?q=192.168.22
GET /ybz/api/v1/ipsegments?area=local
GET /ybz/api/v1/ipsegments?area=global
```

IP addresses:

```text
GET /ybz/api/v1/ipaddresses?q=192.168.22
```

## Change Queries

Every list endpoint supports `updated_since`:

```text
GET /ybz/api/v1/hosts?updated_since=2026-06-30T10:00:00+09:00
GET /ybz/api/v1/services?updated_since=2026-06-30T10:00:00+09:00
```

The dedicated changes endpoint is useful for synchronization jobs:

```text
GET /ybz/api/v1/changes/hosts?since=2026-06-30T10:00:00+09:00
GET /ybz/api/v1/changes/services?since=2026-06-30T10:00:00+09:00
GET /ybz/api/v1/changes/racks?since=2026-06-30T10:00:00+09:00
GET /ybz/api/v1/changes/ipsegments?since=2026-06-30T10:00:00+09:00
GET /ybz/api/v1/changes/ipaddresses?since=2026-06-30T10:00:00+09:00
```

By default removed records are not returned. Add `include_removed=true` when a
sync client also needs removals:

```text
GET /ybz/api/v1/changes/hosts?since=2026-06-30T10:00:00+09:00&include_removed=true
```

## Curl Examples

Basic authentication:

```bash
curl -u USERNAME:PASSWORD \
  'http://localhost:9292/ybz/api/v1/services?limit=10'

curl -u USERNAME:PASSWORD \
  'http://localhost:9292/ybz/api/v1/hosts?status=IN_SERVICE&limit=20'
```

Bearer token:

```bash
curl -H 'Authorization: Bearer long-random-token' \
  'http://localhost:9292/ybz/api/v1/hosts?limit=10'

curl -H 'Authorization: Bearer long-random-token' \
  'http://localhost:9292/ybz/api/v1/health'
```

Token header:

```bash
curl -H 'X-JustNow-API-Token: long-random-token' \
  'http://localhost:9292/ybz/api/v1/services?limit=10'
```

Search and change queries:

```bash
curl -H 'Authorization: Bearer long-random-token' \
  'http://localhost:9292/ybz/api/v1/hosts?q=web&limit=20'

curl -H 'Authorization: Bearer long-random-token' \
  'http://localhost:9292/ybz/api/v1/changes/hosts?since=2026-06-30T10:00:00+09:00'
```

## PowerShell Examples

Bearer token:

```powershell
$headers = @{ Authorization = 'Bearer long-random-token' }
Invoke-RestMethod -Headers $headers -Uri 'http://localhost:9292/ybz/api/v1/hosts?limit=10'
```

Health check:

```powershell
$headers = @{ Authorization = 'Bearer long-random-token' }
Invoke-RestMethod -Headers $headers -Uri 'http://localhost:9292/ybz/api/v1/health'
```

## Sync Job Pattern

A simple sync job can store the previous successful timestamp and use it as
`since` on the next run:

```text
1. Read the last successful sync timestamp from local storage.
2. Request /ybz/api/v1/changes/hosts?since=<timestamp>.
3. Apply returned records to the destination system.
4. Store the current time only after the sync succeeds.
```

Use `updated_until` or `until` when the client needs a fixed time window.
