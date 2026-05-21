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
| [PostGIS](https://postgis.net/) | 3.6.2 | Spatial and geographic data |
| [pg_textsearch](https://github.com/timescale/pg_textsearch) | 1.2.0 | BM25 full-text search |
| [pg_cron](https://github.com/citusdata/pg_cron) | 1.6.7 | Job scheduler for periodic tasks |
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
CREATE EXTENSION pg_cron;
CREATE EXTENSION pg_partman;
CREATE EXTENSION pg_stat_statements;
```

## Configuration

`track_io_timing` is enabled by default for accurate I/O metrics in `pg_stat_statements`. This powers the usage metering and query stats collection pipeline.

## Build

```bash
make build    # Build image
make test     # Build and verify extensions
make run      # Run container
make shell    # psql into container
make clean    # Remove image
```

## Building manually

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t constructiveio/postgres-plus:18 \
  -t constructiveio/postgres-plus:latest \
  --push .
```
