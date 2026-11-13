#!/usr/bin/env bash
# Fails if the image's PostgreSQL server predates the 18.7 security release
# (CVE-2026-6460 and the other fixes shipped with it).
#
# The base image is the floating `postgres:18-alpine` tag, so a rebuild picks up
# whatever minor that tag points at; this asserts against the *running* server,
# not the Dockerfile ARG. `composite_type_mismatch` is the server parameter the
# CVE-2026-6460 fix introduced, so its presence proves that fix is compiled in.
#
# Usage: verify-postgres-security.sh <container-name>
set -euo pipefail

container="${1:?usage: verify-postgres-security.sh <container>}"
psql() { docker exec -i "$container" psql -U postgres -X -q -At "$@"; }

# 18.7 — lowest minor carrying the 2026-11-12 security fixes.
PG_MIN_VERSION_NUM="${PG_MIN_VERSION_NUM:-180007}"

fail() { echo "FAIL: $*" >&2; exit 1; }
ok() { echo "ok: $*"; }

version_num="$(psql -c 'SHOW server_version_num')"
[ "$version_num" -ge "$PG_MIN_VERSION_NUM" ] \
  || fail "server_version_num $version_num is below the patched floor $PG_MIN_VERSION_NUM"
ok "postgres $(psql -c 'SHOW server_version') >= $PG_MIN_VERSION_NUM"

mismatch="$(psql -c 'SHOW composite_type_mismatch' 2>&1)" \
  || fail "composite_type_mismatch is unknown — server lacks the CVE-2026-6460 fix"
[ "$mismatch" = "error" ] || fail "composite_type_mismatch is '$mismatch', expected 'error'"
ok "composite_type_mismatch = error (CVE-2026-6460 check active)"

# Every C extension must load against this server's ABI: an extension built
# against an older minor fails here with "undefined symbol".
for ext in vector postgis pg_textsearch pg_partman pg_stat_statements; do
  psql -c "CREATE EXTENSION IF NOT EXISTS $ext" >/dev/null || fail "CREATE EXTENSION $ext failed"
done
ok "vector, postgis, pg_textsearch, pg_partman, pg_stat_statements load"

echo "PostgreSQL security verification passed"
