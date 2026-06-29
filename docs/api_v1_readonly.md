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
```

## Filters

Hosts:

```text
GET /ybz/api/v1/hosts?status=IN_SERVICE
GET /ybz/api/v1/hosts?service_oid=123
```

IP segments:

```text
GET /ybz/api/v1/ipsegments?area=local
GET /ybz/api/v1/ipsegments?area=global
```

## Examples

```bash
curl -u USERNAME:PASSWORD \
  'http://localhost:9292/ybz/api/v1/services?limit=10'

curl -u USERNAME:PASSWORD \
  'http://localhost:9292/ybz/api/v1/hosts?status=IN_SERVICE&limit=20'
```
