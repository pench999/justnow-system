# JustNow System API v1 Readonly

JustNow System provides a small readonly JSON API under `/ybz/api/v1`.
The API uses the same authentication path as the web UI, including session
authentication and HTTP Basic authentication.

## Response Format

List endpoints return:

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

Detail endpoints return:

```json
{
  "data": {}
}
```

Errors return:

```json
{
  "error": {
    "code": "not_found",
    "message": "host not found"
  }
}
```

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

## Examples

```bash
curl -u USERNAME:PASSWORD \
  'http://localhost:9292/ybz/api/v1/services?limit=10'

curl -u USERNAME:PASSWORD \
  'http://localhost:9292/ybz/api/v1/hosts?status=IN_SERVICE&limit=20'

curl -u USERNAME:PASSWORD \
  'http://localhost:9292/ybz/api/v1/hosts?q=web&limit=20'

curl -u USERNAME:PASSWORD \
  'http://localhost:9292/ybz/api/v1/changes/hosts?since=2026-06-30T10:00:00+09:00'
```
