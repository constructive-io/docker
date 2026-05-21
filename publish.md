# Publishing

How to build and publish the `constructiveio/postgres-plus` image to Docker Hub.

## Prerequisites

- Logged in to Docker Hub: `docker login`
- Push access to the `constructiveio` org on Docker Hub
- Docker Desktop or a Docker engine with `buildx` available (included in modern Docker installs)

---

## Multi-architecture builds (amd64 + arm64)

Docker Hub serves a single image tag that resolves to the correct architecture for the puller (Intel/AMD servers get `linux/amd64`, Apple Silicon and Graviton get `linux/arm64`). To produce that, build with `buildx` and push a multi-arch manifest.

### One-time setup

Create a buildx builder that supports multiple platforms:

```bash
docker buildx create --name multiarch --use --bootstrap
```

Confirm both platforms are available:

```bash
docker buildx inspect multiarch
# Look for: Platforms: linux/amd64, linux/arm64, ...
```

If `linux/arm64` is missing on a non-ARM host, Docker Desktop's QEMU emulation handles it automatically. On a Linux host without Docker Desktop, install `qemu-user-static` first.

### Build and push

Multi-arch manifests can only be **pushed** — they cannot be `--load`ed into the local Docker daemon, because the daemon stores one architecture per tag.

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t constructiveio/postgres-plus:latest \
  -t constructiveio/postgres-plus:18 \
  --push .
```

Tag with both `:latest` and the Postgres major version so users can pin if they want.

### Local testing (single arch)

To smoke-test before pushing, build one arch at a time with `--load`:

```bash
docker buildx build --platform linux/arm64 \
  -t constructiveio/postgres-plus:test --load .

docker run --rm -e POSTGRES_PASSWORD=test -p 5432:5432 \
  constructiveio/postgres-plus:test
```

### Makefile target

A convenience target you can drop into the `Makefile`:

```makefile
PLATFORMS ?= linux/amd64,linux/arm64

buildx-setup:
	docker buildx inspect multiarch >/dev/null 2>&1 || \
		docker buildx create --name multiarch --bootstrap

buildx: buildx-setup
	docker buildx build --platform $(PLATFORMS) \
		-t $(IMAGE_NAME):$(IMAGE_TAG) --push .
```

Then: `make buildx` (optionally `make buildx IMAGE_TAG=18`).

### Verify the manifest

After pushing, confirm both architectures landed:

```bash
docker buildx imagetools inspect constructiveio/postgres-plus:latest
```

You should see entries for both `linux/amd64` and `linux/arm64`.

---

## Updating the Docker Hub README

The README shown on the Docker Hub repo page (`hub.docker.com/r/constructiveio/postgres-plus`) is **not** synced automatically from this repo's `README.md`. You have to push it explicitly.

### Option 1: Manual (web UI)

1. Sign in at https://hub.docker.com
2. Go to `constructiveio/postgres-plus`
3. Click **Manage Repository** → edit the **Overview** field
4. Paste the contents of `README.md` and save

Simple, but easy to forget when the README changes.

### Option 2: CLI with `docker-pushrm`

[`docker-pushrm`](https://github.com/christian-korneck/docker-pushrm) is a Docker CLI plugin that pushes the README.

Install (macOS):

```bash
mkdir -p ~/.docker/cli-plugins
curl -sSL \
  https://github.com/christian-korneck/docker-pushrm/releases/download/v1.9.0/docker-pushrm_darwin_arm64 \
  -o ~/.docker/cli-plugins/docker-pushrm
chmod +x ~/.docker/cli-plugins/docker-pushrm
```

(Swap `darwin_arm64` for `darwin_amd64` or `linux_amd64` as needed; check the releases page for the latest version.)

Push the README:

```bash
docker pushrm constructiveio/postgres-plus
```

It reads `README.md` from the current directory by default. Add to the `Makefile`:

```makefile
pushrm:
	docker pushrm $(IMAGE_NAME)
```

### Option 3: GitHub Action (recommended for automation)

Wire it into CI so the Docker Hub page never drifts from the repo README. Add `.github/workflows/dockerhub-description.yml`:

```yaml
name: Update Docker Hub description

on:
  push:
    branches: [main]
    paths:
      - README.md
      - .github/workflows/dockerhub-description.yml

jobs:
  update:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: peter-evans/dockerhub-description@v4
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}
          repository: constructiveio/postgres-plus
          short-description: "Lean PostgreSQL 18 with pgvector, PostGIS, pg_textsearch, pg_cron, pg_partman"
          readme-filepath: ./README.md
```

`DOCKERHUB_TOKEN` should be a Docker Hub access token (Account Settings → Security) with **Read, Write, Delete** scope on this repo, stored as a repo secret. The default `GITHUB_TOKEN` won't work for Docker Hub.

---

## Full release flow

For a typical version bump:

```bash
# 1. Test locally
make test

# 2. Build + push multi-arch image
make buildx IMAGE_TAG=latest
make buildx IMAGE_TAG=18

# 3. Update the Hub README (if it changed)
docker pushrm constructiveio/postgres-plus
# or just push to main and let the GitHub Action handle it

# 4. Verify
docker buildx imagetools inspect constructiveio/postgres-plus:latest
```
