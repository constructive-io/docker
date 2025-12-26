# Lean PostgreSQL image with pgvector, PostGIS, Tiger geocoder, and pgsodium
# Multi-stage build - all toolchains discarded, only artifacts kept

ARG PG_VERSION=17
ARG PGVECTOR_VERSION=0.8.0
ARG POSTGIS_VERSION=3.5.1
ARG PGSODIUM_VERSION=3.1.9

#############################################
# Stage 1: Build extensions
#############################################
FROM postgres:${PG_VERSION}-alpine AS builder

ARG PGVECTOR_VERSION
ARG POSTGIS_VERSION
ARG PGSODIUM_VERSION

RUN apk add --no-cache \
    git \
    build-base \
    postgresql-dev \
    curl \
    # PostGIS dependencies
    geos-dev \
    proj-dev \
    gdal-dev \
    json-c-dev \
    protobuf-c-dev \
    libxml2-dev \
    pcre2-dev \
    libsodium-dev

WORKDIR /build

# pgvector (disable LLVM bitcode)
RUN git clone --branch v${PGVECTOR_VERSION} --depth 1 https://github.com/pgvector/pgvector.git && \
    cd pgvector && \
    make OPTFLAGS="" USE_PGXS=1 WITH_LLVM=no -j$(nproc) && \
    make USE_PGXS=1 WITH_LLVM=no install

# PostGIS with Tiger geocoder and address standardizer
RUN curl -L https://download.osgeo.org/postgis/source/postgis-${POSTGIS_VERSION}.tar.gz | tar xz && \
    cd postgis-${POSTGIS_VERSION} && \
    ./configure --without-raster --without-topology && \
    make -j$(nproc) && \
    make install

# pgsodium
RUN git clone --branch v${PGSODIUM_VERSION} --depth 1 https://github.com/michelp/pgsodium.git && \
    cd pgsodium && \
    make -j$(nproc) && \
    make install

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
    libsodium

# Copy compiled extensions from builder
COPY --from=builder /usr/local/lib/postgresql/ /usr/local/lib/postgresql/
COPY --from=builder /usr/local/share/postgresql/ /usr/local/share/postgresql/

LABEL org.opencontainers.image.source="https://github.com/constructive-io/docker"
LABEL org.opencontainers.image.description="PostgreSQL 17 with pgvector, PostGIS, Tiger geocoder, and pgsodium"
