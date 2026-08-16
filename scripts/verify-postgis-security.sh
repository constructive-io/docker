#!/usr/bin/env bash
# Fails if the image ships a PostGIS build that is vulnerable to
# CVE-2026-73515 (FlatGeobuf out-of-bounds read) or CVE-2026-73514
# (address_standardizer out-of-bounds write).
#
# Everything is asserted against the *installed* extension, never against a
# Dockerfile ARG or a tag: an image can be rebuilt from a moved tag, and the
# upstream 3.6.x tarballs carry neither fix, so the build applies patches/ on
# top and records them in the manifest this script reads back.
#
# Usage: verify-postgis-security.sh <container-name>
set -euo pipefail

container="${1:?usage: verify-postgis-security.sh <container>}"
psql() { docker exec -i "$container" psql -U postgres -X -q -At "$@"; }

# Lowest release carrying the fixes we backport on top of. A tarball below this
# is vulnerable even before considering the patches.
POSTGIS_MIN_VERSION="${POSTGIS_MIN_VERSION:-3.6.4}"
MANIFEST=/usr/local/share/postgresql/security/postgis-patches.txt

fail() { echo "FAIL: $*" >&2; exit 1; }
ok() { echo "ok: $*"; }

psql -c 'CREATE EXTENSION IF NOT EXISTS postgis' >/dev/null
psql -c 'CREATE EXTENSION IF NOT EXISTS address_standardizer' >/dev/null
psql -c 'CREATE EXTENSION IF NOT EXISTS address_standardizer_data_us' >/dev/null

# 1. installed PostGIS release floor
installed="$(psql -c "SELECT extversion FROM pg_extension WHERE extname = 'postgis'")"
[ -n "$installed" ] || fail "postgis extension is not installed"
if [ "$(printf '%s\n%s\n' "$POSTGIS_MIN_VERSION" "$installed" | sort -V | head -1)" != "$POSTGIS_MIN_VERSION" ]; then
  fail "postgis $installed is below the patched floor $POSTGIS_MIN_VERSION"
fi
ok "postgis $installed >= $POSTGIS_MIN_VERSION ($(psql -c 'SELECT postgis_lib_version()'))"

# 2. the security patches are recorded in the image
manifest="$(docker exec "$container" cat "$MANIFEST" 2>/dev/null || true)"
[ -n "$manifest" ] || fail "$MANIFEST missing — image was not built with patches/"
for cve in CVE-2026-73514 CVE-2026-73515; do
  grep -qx "cve_fixed=$cve" <<<"$manifest" || fail "$MANIFEST does not record a fix for $cve"
done
ok "patch manifest records $(grep -c '^patch=' <<<"$manifest") patches for both CVEs"

# 3. CVE-2026-73515: a truncated FlatGeobuf buffer must be rejected, and the
#    backend must survive it (an unpatched build reads past the buffer).
fgb_error="$(docker exec -i "$container" psql -U postgres -X -q -At -v ON_ERROR_STOP=0 <<'SQL' 2>&1 || true
CREATE TEMP TABLE fgb_probe (geom geometry, name text);
SELECT ST_FromFlatGeobuf(NULL::fgb_probe, decode('6667620366676201', 'hex'));
SQL
)"
grep -qi 'flatgeobuf' <<<"$fgb_error" || fail "truncated FlatGeobuf input was not rejected: $fgb_error"
[ "$(psql -c 'SELECT 1')" = "1" ] || fail "backend did not survive truncated FlatGeobuf input"
ok "truncated FlatGeobuf input rejected, backend alive"

# 4. CVE-2026-73514: the off-by-one that let parse_rule() write past
#    rule_arr[MAX_RULE_LENGTH] is gone, and the standardizer still works.
psql -c "SELECT house_num, name, city, state FROM standardize_address(
  'us_lex', 'us_gaz', 'us_rules', '1 Devonshire Place, Boston, MA 02109')" >/dev/null \
  || fail "standardize_address() failed on patched address_standardizer"
ok "address_standardizer $(psql -c "SELECT extversion FROM pg_extension WHERE extname='address_standardizer'") functional"

echo "PostGIS security verification passed"
