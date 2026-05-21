#!/bin/sh
set -eu

CLI_BIN="/usr/local/bin/cli.real"
IPINFO_URL="${IPINFO_URL:-https://ipinfo.io/json}"

json_get() {
  key="$1"
  payload="$2"
  printf '%s' "$payload" | tr -d '\n' | sed -n "s/.*\"$key\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -n 1
}

print_public_ip() {
  payload="$(curl -4 -fsS --max-time 10 "$IPINFO_URL" 2>/dev/null || true)"

  if [ -z "$payload" ]; then
    echo "Public ip : unavailable"
    return 0
  fi

  ip="$(json_get ip "$payload")"
  city="$(json_get city "$payload")"
  region="$(json_get region "$payload")"
  country="$(json_get country "$payload")"
  loc="$(json_get loc "$payload")"
  postal="$(json_get postal "$payload")"
  timezone="$(json_get timezone "$payload")"
  org="$(json_get org "$payload")"
  hostname="$(json_get hostname "$payload")"

  asn="$(printf '%s' "$org" | sed -n 's/^\(AS[0-9][0-9]*\).*/\1/p')"

  [ -n "$ip" ] || ip="-"
  [ -n "$city" ] || city="-"
  [ -n "$region" ] || region="-"
  [ -n "$country" ] || country="-"
  [ -n "$loc" ] || loc="-"
  [ -n "$postal" ] || postal="-"
  [ -n "$timezone" ] || timezone="-"
  [ -n "$org" ] || org="-"
  [ -n "$hostname" ] || hostname="-"
  [ -n "$asn" ] || asn="-"

  echo "Public ip : ip=$ip | asn=$asn | city=$city | region=$region | country=$country | loc=$loc | postal=$postal | timezone=$timezone | org=$org | hostname=$hostname"
}

print_public_ip

# Start a lightweight HTTP server on port 2410 returning JSON
# Using busybox httpd ensures maximum optimization (~0 CPU, <1MB RAM)
mkdir -p /tmp/www/cgi-bin
cat << 'EOF' > /tmp/www/index.html
{"hello": "world"}
EOF
cat << 'EOF' > /tmp/www/cgi-bin/api
#!/bin/sh
printf "Content-Type: application/json\r\n\r\n"
printf "{\"hello\": \"world\"}\n"
EOF
chmod +x /tmp/www/cgi-bin/api
httpd -p 2410 -h /tmp/www

exec "$CLI_BIN" "$@"
