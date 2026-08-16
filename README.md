# Constructive DB

> The official Docker image for the Constructive database.

<p align="center" width="100%">
   <img src="https://raw.githubusercontent.com/constructive-io/docker/refs/heads/main/img/logo.svg" alt="constructive" height="180"><br />
</p>

Lean PostgreSQL 18 image with essential extensions for modern applications.

## Extensions

| Extension | Version | Description |
|-----------|---------|-------------|
| [pgvector](https://github.com/pgvector/pgvector) | 0.8.2 | Vector similarity search for embeddings |
| [PostGIS](https://postgis.net/) | 3.6.4 (+ security patches) | Spatial and geographic data |
| [pg_textsearch](https://github.com/timescale/pg_textsearch) | 1.3.1 | BM25 full-text search |
| [pg_partman](https://github.com/pgpartman/pg_partman) | 5.4.3 | Partition management |
| [pg_stat_statements](https://www.postgresql.org/docs/current/pgstatstatements.html) | built-in | Query performance statistics |

## Usage

```bash
# Pull the image
docker pull constructiveio/postgres-plus:latest

# Run
docker run -d \
  --name postgres \
  -e POSTGRES_PASSWORD=secret \
  -p 5432:5432 \
  constructiveio/postgres-plus:latest
```

Enable extensions as needed:

```sql
CREATE EXTENSION vector;
CREATE EXTENSION postgis;
CREATE EXTENSION pg_textsearch;
CREATE EXTENSION pg_partman;
CREATE EXTENSION pg_stat_statements;
```

## Configuration

`track_io_timing` is enabled by default for accurate I/O metrics in `pg_stat_statements`. This powers the usage metering and query stats collection pipeline.

## Build

```bash
make build            # Build image
make test             # Build, verify extensions, and run the PostGIS security gate
make verify-security  # Run the security gate against an already-running container
make run              # Run container
make shell            # psql into container
make clean            # Remove image
```

## PostGIS security patches

PostGIS is built from the `3.6.4` tarball with the upstream security fixes in
[`patches/`](./patches) applied on top — no released tarball carries them yet:

| Patch | Fixes |
|-------|-------|
| `0001-flatgeobuf-validate-input-buffers-before-decoding` | CVE-2026-73515 — out-of-bounds read decoding a FlatGeobuf buffer (`ST_FromFlatGeobuf`). `postgis/stable-3.6` `53e273fae`, landed after 3.6.4. |
| `0002-address_standardizer-harden-scanner-and-rule-parsing` | CVE-2026-73514 — equivalent to `423570b` in the split-out [`postgis/address_standardizer`](https://github.com/postgis/address_standardizer) repo. |
| `0003-address_standardizer-clean-up-partial-2D-allocations` | leak/partial-allocation cleanup accompanying the above. |
| `0004-Avoid-out-of-bounds-write-uninitialized-memory` | the `parse_rule()` off-by-one write past `rule_arr[MAX_RULE_LENGTH]` plus an uninitialized `RULE_PARAM`. |

Each is a `git format-patch` of the upstream commit cherry-picked onto the
`3.6.4` tag, so the provenance stays greppable and a patch that stops applying
fails the build rather than being silently skipped.

`scripts/verify-postgis-security.sh <container>` is the gate that keeps a
vulnerable build from reaching a tag. It asserts against the *installed*
extension, not the Dockerfile args: release floor, the patch manifest baked into
the image, that a truncated FlatGeobuf buffer is rejected with the backend still
alive, and that `standardize_address()` still works. CI runs it on every PR and
on the pushed digest before the `latest`/`18` manifests move.

Drop the patches when a PostGIS release contains all four fixes; the gate's
`POSTGIS_MIN_VERSION` floor and manifest check are what to update then.

## Building manually

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t constructiveio/postgres-plus:18 \
  -t constructiveio/postgres-plus:latest \
  --push .
```
