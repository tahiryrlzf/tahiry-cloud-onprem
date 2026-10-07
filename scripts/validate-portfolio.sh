#!/usr/bin/env bash
set -u

K="${KUBECTL:-sudo k3s kubectl}"

for ns in staging prod; do
  host="tahiry-cloud.com"
  [ "$ns" = "staging" ] && host="staging.tahiry-cloud.com"

  echo "== $ns =="
  $K get pods -n "$ns"
  echo -n "HTTP /        : "
  curl -s -o /dev/null -w "%{http_code}\n" -H "Host: $host" http://127.0.0.1/
  echo -n "HTTP /healthz : "
  curl -s -o /dev/null -w "%{http_code}\n" -H "Host: $host" http://127.0.0.1/healthz
done
