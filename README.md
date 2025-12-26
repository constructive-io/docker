# Constructive Docker

<p align="center" width="100%">
   <img src="https://raw.githubusercontent.com/constructive-io/docker/refs/heads/main/img/logo.svg" alt="constructive" height="180"><br />
</p>

Lean PostgreSQL 17 image with essential extensions for modern applications.

## Extensions

| Extension | Description |
|-----------|-------------|
| [pgvector](https://github.com/pgvector/pgvector) | Vector similarity search for embeddings |
| [PostGIS](https://postgis.net/) | Spatial and geographic data |
| [pg_textsearch](https://www.tigerdata.com/docs/use-timescale/latest/extensions/pg-textsearch) | BM25 full-text search |
| [pgsodium](https://github.com/michelp/pgsodium) | Encryption using libsodium |

## Usage

```bash
# Pull the image
docker pull ghcr.io/constructive-io/docker:latest

# Run
docker run -d \
  --name postgres \
  -e POSTGRES_PASSWORD=secret \
  -p 5432:5432 \
  ghcr.io/constructive-io/docker:latest
```

Enable extensions as needed:

```sql
CREATE EXTENSION vector;
CREATE EXTENSION postgis;
CREATE EXTENSION pg_textsearch;
CREATE EXTENSION pgsodium;
```

## Build

```bash
make build    # Build image
make test     # Build and verify extensions
make run      # Run container
make shell    # psql into container
make clean    # Remove image
```

