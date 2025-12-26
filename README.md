# Constructive Docker

<p align="center" width="100%">
   <img src="./img/logo.svg" alt="constructive" width="80"><br />
</p>

Lean PostgreSQL 17 image with essential extensions for modern applications.

## Extensions

| Extension | Description |
|-----------|-------------|
| [pgvector](https://github.com/pgvector/pgvector) | Vector similarity search for embeddings |
| [PostGIS](https://postgis.net/) | Spatial and geographic data |
| [Tiger Geocoder](https://postgis.net/docs/Extras.html#Tiger_Geocoder) | US address geocoding |
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
CREATE EXTENSION fuzzystrmatch;
CREATE EXTENSION address_standardizer;
CREATE EXTENSION postgis_tiger_geocoder;
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

## GitHub Actions

Images are automatically built and pushed to `ghcr.io` on:
- Push to `main`
- Tagged releases (`v*`)

Multi-arch support: `linux/amd64` and `linux/arm64`

## License

MIT License - see [LICENSE](./LICENSE)
