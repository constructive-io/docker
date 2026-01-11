# Constructive Docker

<p align="center" width="100%">
   <img src="https://raw.githubusercontent.com/constructive-io/docker/refs/heads/main/img/logo.svg" alt="constructive" height="180"><br />
</p>

PostgreSQL 17 images with essential extensions for modern applications.

## Images

This repository provides two Docker images:

### postgres-plus (Alpine, lean)

Lightweight image based on Alpine Linux with core extensions.

```bash
docker pull ghcr.io/constructive-io/docker/postgres-plus:latest
```

| Extension | Description |
|-----------|-------------|
| [pgvector](https://github.com/pgvector/pgvector) | Vector similarity search for embeddings |
| [PostGIS](https://postgis.net/) | Spatial and geographic data |
| [pg_textsearch](https://www.tigerdata.com/docs/use-timescale/latest/extensions/pg-textsearch) | BM25 full-text search |
| [pgsodium](https://github.com/michelp/pgsodium) | Encryption using libsodium |

### postgres-plus-lake (Debian, with pg_lake)

Full-featured image based on Debian with all extensions including pg_lake for data lake access.

```bash
docker pull ghcr.io/constructive-io/docker/postgres-plus-lake:latest
```

| Extension | Description |
|-----------|-------------|
| [pgvector](https://github.com/pgvector/pgvector) | Vector similarity search for embeddings |
| [PostGIS](https://postgis.net/) | Spatial and geographic data |
| [pg_textsearch](https://www.tigerdata.com/docs/use-timescale/latest/extensions/pg-textsearch) | BM25 full-text search |
| [pgsodium](https://github.com/michelp/pgsodium) | Encryption using libsodium |
| [pg_lake](https://github.com/Snowflake-Labs/pg_lake) | Iceberg and data lake access |

## Usage

```bash
# Run postgres-plus (Alpine)
docker run -d \
  --name postgres \
  -e POSTGRES_PASSWORD=secret \
  -p 5432:5432 \
  ghcr.io/constructive-io/docker/postgres-plus:latest

# Run postgres-plus-lake (Debian with pg_lake)
docker run -d \
  --name postgres \
  -e POSTGRES_PASSWORD=secret \
  -p 5432:5432 \
  ghcr.io/constructive-io/docker/postgres-plus-lake:latest
```

Enable extensions as needed:

```sql
CREATE EXTENSION vector;
CREATE EXTENSION postgis;
CREATE EXTENSION pg_textsearch;
CREATE EXTENSION pgsodium;
CREATE EXTENSION pg_lake;  -- only available in postgres-plus-lake
```

## Build

```bash
# postgres-plus (Alpine)
make build         # Build image
make test          # Build and verify extensions
make run           # Run container

# postgres-plus-lake (Debian with pg_lake)
make build-lake    # Build image
make test-lake     # Build and verify extensions
make run-lake      # Run container

# Both images
make build-all     # Build both images
make test-all      # Test both images

# Common
make shell         # psql into container
make clean         # Remove images
```

