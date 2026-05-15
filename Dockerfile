# Lean PostgreSQL image with pgvector, PostGIS, pg_textsearch, pg_cron, and pg_partman
# Multi-stage build - all toolchains discarded, only artifacts kept

ARG PG_VERSION=18
ARG PGVECTOR_VERSION=0.8.2
ARG POSTGIS_VERSION=3.6.2
ARG PG_TEXTSEARCH_VERSION=0.6.1
ARG PG_CRON_VERSION=1.6.7
ARG PG_PARTMAN_VERSION=5.4.3

#############################################
# Stage 1: Build extensions
#############################################
FROM postgres:${PG_VERSION}-alpine AS builder

ARG PGVECTOR_VERSION
ARG POSTGIS_VERSION
ARG PG_TEXTSEARCH_VERSION
ARG PG_CRON_VERSION
ARG PG_PARTMAN_VERSION

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
    # PostGIS build tools
    perl \
    flex \
    bison

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
    make -j$(nproc) && \
    make install

# pg_cron (job scheduler)
RUN git clone --branch v${PG_CRON_VERSION} --depth 1 https://github.com/citusdata/pg_cron.git && \
    cd pg_cron && \
    make -j$(nproc) && \
    make install

# pg_partman (partition management)
RUN git clone --branch v${PG_PARTMAN_VERSION} --depth 1 https://github.com/pgpartman/pg_partman.git && \
    cd pg_partman && \
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
    pcre2

# Copy compiled extensions from builder
COPY --from=builder /usr/local/lib/postgresql/ /usr/local/lib/postgresql/
COPY --from=builder /usr/local/share/postgresql/ /usr/local/share/postgresql/

# Preload extensions that require shared_preload_libraries
RUN echo "shared_preload_libraries = 'pg_textsearch,pg_cron,pg_partman_bgw'" >> /usr/local/share/postgresql/postgresql.conf.sample

LABEL org.opencontainers.image.source="https://github.com/constructive-io/docker"
LABEL org.opencontainers.image.description="PostgreSQL 18 with pgvector, PostGIS, pg_textsearch, pg_cron, and pg_partman"
