#!/usr/bin/env bash
# Fails if the image ships a pgvector build that is vulnerable to
# CVE-2026-103484 (out-of-bounds write during an IVFFlat index build,
# https://github.com/pgvector/pgvector/issues/1036 — affected <= 0.8.6,
# fixed in 0.8.7).
#
# Asserted against the *installed* extension and the *loaded* library, never
# against a Dockerfile ARG or a tag. The extension version is only SQL
# metadata, so the library is checked too: 0.8.7 is the first release whose
# vector.so exports `sparsevec_vector_dims`, added by the same commit as the
# fix (ee00d39), and binding a C function to that symbol fails on any older
# build. Nothing here builds an index or writes out of bounds.
#
# Usage: verify-pgvector-security.sh <container-name>
set -euo pipefail

container="${1:?usage: verify-pgvector-security.sh <container>}"
psql() { docker exec -i "$container" psql -U postgres -X -q -At -v ON_ERROR_STOP=1 "$@"; }

PGVECTOR_MIN_VERSION="${PGVECTOR_MIN_VERSION:-0.8.7}"

fail() { echo "FAIL: $*" >&2; exit 1; }
ok() { echo "ok: $*"; }

below_floor() {
  [ "$(printf '%s\n%s\n' "$PGVECTOR_MIN_VERSION" "$1" | sort -V | head -1)" != "$PGVECTOR_MIN_VERSION" ]
}

# 1. the version the image installs by default
available="$(psql -c "SELECT default_version FROM pg_available_extensions WHERE name = 'vector'")"
[ -n "$available" ] || fail "pgvector is not available in this image"
if below_floor "$available"; then
  fail "pgvector default_version $available is below the patched floor $PGVECTOR_MIN_VERSION"
fi

# 2. the version a database actually gets
psql -c 'CREATE EXTENSION IF NOT EXISTS vector' >/dev/null
installed="$(psql -c "SELECT extversion FROM pg_extension WHERE extname = 'vector'")"
if below_floor "$installed"; then
  fail "pgvector extension $installed is below the patched floor $PGVECTOR_MIN_VERSION"
fi
ok "pgvector $installed >= $PGVECTOR_MIN_VERSION"

# 3. the library itself carries the fix commit
psql >/dev/null 2>&1 <<'SQL' || fail "vector.so does not export sparsevec_vector_dims — library predates the CVE-2026-103484 fix"
BEGIN;
CREATE FUNCTION pg_temp.pgvector_fix_probe(sparsevec) RETURNS integer
  AS '$libdir/vector', 'sparsevec_vector_dims' LANGUAGE C IMMUTABLE STRICT;
ROLLBACK;
SQL
ok "vector.so exports sparsevec_vector_dims (CVE-2026-103484 fix compiled in)"

echo "pgvector security verification passed"
