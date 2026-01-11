# Lean PostgreSQL image with pgvector, PostGIS, pg_textsearch, pgsodium, and pg_lake
# Multi-stage build - all toolchains discarded, only artifacts kept

ARG PG_VERSION=17
ARG PGVECTOR_VERSION=0.8.0
ARG POSTGIS_VERSION=3.5.1
ARG PG_TEXTSEARCH_VERSION=0.2.0
ARG PGSODIUM_VERSION=3.1.9
ARG PG_LAKE_VERSION=main

#############################################
# Stage 1: Build extensions
#############################################
FROM postgres:${PG_VERSION}-alpine AS builder

ARG PGVECTOR_VERSION
ARG POSTGIS_VERSION
ARG PG_TEXTSEARCH_VERSION
ARG PGSODIUM_VERSION
ARG PG_LAKE_VERSION

RUN apk add --no-cache \
    git \
    build-base \
    postgresql-dev \
    clang19 \
    llvm19 \
    curl \
    # PostGIS dependencies
    geos-dev \
    proj-dev \
    gdal-dev \
    json-c-dev \
    protobuf-c-dev \
    libxml2-dev \
    pcre2-dev \
    libsodium-dev \
    # PostGIS build tools
    perl \
    flex \
    bison \
    # pg_lake dependencies
    cmake \
    ninja \
    openssl-dev \
    snappy-dev \
    jansson-dev \
    lz4-dev \
    xz-dev \
    zstd-dev \
    libpq-dev \
    linux-headers \
    krb5-dev

WORKDIR /build

# Symlink for LLVM JIT (postgres expects llvm-lto-19)
RUN ln -s /usr/bin/llvm19-lto /usr/bin/llvm-lto-19

# pgvector
RUN git clone --branch v${PGVECTOR_VERSION} --depth 1 https://github.com/pgvector/pgvector.git && \
    cd pgvector && \
    make OPTFLAGS="" -j$(nproc) && \
    make install

# PostGIS with Tiger geocoder and address standardizer
RUN curl -L https://download.osgeo.org/postgis/source/postgis-${POSTGIS_VERSION}.tar.gz | tar xz && \
    cd postgis-${POSTGIS_VERSION} && \
    ./configure --without-raster --without-topology && \
    make && \
    make install

# pg_textsearch (BM25)
RUN git clone --branch v${PG_TEXTSEARCH_VERSION} --depth 1 https://github.com/timescale/pg_textsearch.git && \
    cd pg_textsearch && \
    # Fix missing math.h include (upstream bug)
    sed -i '1i #include <math.h>' src/am/build.c && \
    make -j$(nproc) && \
    make install

# pgsodium
RUN git clone --branch v${PGSODIUM_VERSION} --depth 1 https://github.com/michelp/pgsodium.git && \
    cd pgsodium && \
    make -j$(nproc) && \
    make install

# pg_lake - Postgres with Iceberg and data lake access
RUN git clone --branch ${PG_LAKE_VERSION} --depth 1 --recurse-submodules https://github.com/Snowflake-Labs/pg_lake.git && \
    cd pg_lake && \
    # Build and install avro library
    cd avro && git checkout -f . && git apply --ignore-whitespace ../avro.patch && \
    mkdir -p lang/c/build && cd lang/c/build && \
    cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local -DCMAKE_BUILD_TYPE=RelWithDebInfo && \
    make -j$(nproc) && make install && \
    cd /build/pg_lake && \
    # Build pg_lake extensions (without DuckDB/pgduck_server for Alpine compatibility)
    make -C pg_map && make -C pg_map install && \
    make -C pg_extension_base && make -C pg_extension_base install && \
    make -C pg_extension_updater && make -C pg_extension_updater install && \
    make -C pg_lake_engine && make -C pg_lake_engine install && \
    make -C pg_lake_copy && make -C pg_lake_copy install && \
    make -C pg_lake_iceberg && make -C pg_lake_iceberg install && \
    make -C pg_lake_table && make -C pg_lake_table install && \
    make -C pg_lake && make -C pg_lake install

#############################################
# Stage 2: Final lean runtime image
#############################################
FROM postgres:${PG_VERSION}-alpine

# Runtime deps only
RUN apk add --no-cache \
    geos \
    proj \
    gdal \
    json-c \
    protobuf-c \
    libxml2 \
    pcre2 \
    libsodium \
    # pg_lake runtime dependencies
    snappy \
    jansson \
    lz4-libs \
    xz-libs \
    zstd-libs \
    libpq

# Copy compiled extensions from builder
COPY --from=builder /usr/local/lib/postgresql/ /usr/local/lib/postgresql/
COPY --from=builder /usr/local/share/postgresql/ /usr/local/share/postgresql/
# Copy avro library for pg_lake
COPY --from=builder /usr/local/lib/libavro* /usr/local/lib/

LABEL org.opencontainers.image.source="https://github.com/constructive-io/docker"
LABEL org.opencontainers.image.description="PostgreSQL 17 with pgvector, PostGIS, pg_textsearch, pgsodium, and pg_lake"
