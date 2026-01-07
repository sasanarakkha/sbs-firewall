# SBS OpenWRT Ticket API

These API calls do not require authentication.

## Get all tickets [GET]

```sh
curl -sX GET https://openwrt.sbs.rocks/cgi-bin/sbs/tickets
```

```json
{
  "tickets": [
    {
      "ether": "10:66:6a:29:81:e3",
      "timeout": 4500,
      "expires": 1888,
      "comment": "ip=fded:10:108::1234 id=5678"
    },
    {
      "ether": "10:66:6a:91:e6:0c",
      "timeout": 300,
      "expires": 96,
      "comment": "ip=10.108.4.2 id=1234"
    }
  ]
}
```

## Add a ticket [POST]

```sh
curl -sX POST https://openwrt.sbs.rocks/cgi-bin/sbs/tickets \
  -d '{ "addr": "10.108.4.2", "duration": 300, "comment": "id=1234" }'
```

```json
{
  "parsed_addr": {
    "addr": "10.108.4.2",
    "type": "ipv4",
    "ip": "10.108.4.2",
    "ether": "10:66:6a:91:e6:0c"
  },
  "ticket": {
    "ether": "10:66:6a:91:e6:0c",
    "timeout": 300,
    "expires": 300,
    "comment": "ip=10.108.4.2 id=1234"
  }
}
```

## Replace a ticket [PUT]

```sh
curl -sX PUT https://openwrt.sbs.rocks/cgi-bin/sbs/tickets \
  -d '{ "addr": "fded:10:108::1234", "timeout": 4500, "expires": 2000, "comment": "id=5678" }'
```

```json
{
  "parsed_addr": {
    "addr": "fded:10:108::1234",
    "type": "ipv6",
    "ip": "fded:10:108::1234",
    "ether": "10:66:6a:29:81:e3"
  },
  "ticket": {
    "ether": "10:66:6a:29:81:e3",
    "timeout": 4500,
    "expires": 2000,
    "comment": "ip=fded:10:108::1234 id=5678"
  }
}
```

## Delete a ticket [DELETE]

```sh
curl -sX DELETE https://openwrt.sbs.rocks/cgi-bin/sbs/tickets \
  -d '{ "addr": "10:66:6a:29:81:e3" }'
```

```json
{
  "parsed_addr": {
    "addr": "10:66:6a:29:81:e3",
    "type": "ether",
    "ether": "10:66:6a:29:81:e3"
  }
}
```

## Errors

The error parameter will be set when there is an error.

```sh
curl -sX DELETE https://openwrt.sbs.rocks/cgi-bin/sbs/tickets \
  -d '{ "addr": "1.2.3" }'
```

```json
{
  "error": "invalid addr: 1.2.3"
}
```

```sh
curl -sX DELETE https://openwrt.sbs.rocks/cgi-bin/sbs/tickets \
  -d '{ "addr": "1.2.3.4" }'
```

```json
{
  "parsed_addr": {
    "addr": "1.2.3.4",
    "type": "ipv4",
    "ip": "1.2.3.4"
  },
  "error": "ether not found for ip: 1.2.3.4"
}
```
