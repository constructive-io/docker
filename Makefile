.PHONY: build build-lake run run-lake stop clean test test-lake shell push push-lake

IMAGE_NAME ?= constructive/postgres
IMAGE_NAME_LAKE ?= constructive/postgres-lake
IMAGE_TAG ?= latest
CONTAINER_NAME ?= constructive-pg
POSTGRES_PASSWORD ?= postgres

# Build postgres-plus (Alpine, lean)
build:
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) .

# Build postgres-plus-lake (Debian, with pg_lake)
build-lake:
	docker build -t $(IMAGE_NAME_LAKE):$(IMAGE_TAG) -f Dockerfile.pg_lake .

# Build both images
build-all: build build-lake

run:
	docker run -d \
		--name $(CONTAINER_NAME) \
		-e POSTGRES_PASSWORD=$(POSTGRES_PASSWORD) \
		-p 5432:5432 \
		$(IMAGE_NAME):$(IMAGE_TAG)

run-lake:
	docker run -d \
		--name $(CONTAINER_NAME)-lake \
		-e POSTGRES_PASSWORD=$(POSTGRES_PASSWORD) \
		-p 5432:5432 \
		$(IMAGE_NAME_LAKE):$(IMAGE_TAG)

stop:
	docker stop $(CONTAINER_NAME) || true
	docker rm $(CONTAINER_NAME) || true
	docker stop $(CONTAINER_NAME)-lake || true
	docker rm $(CONTAINER_NAME)-lake || true

restart: stop run

shell:
	docker exec -it $(CONTAINER_NAME) psql -U postgres

logs:
	docker logs -f $(CONTAINER_NAME)

# Test postgres-plus (Alpine)
test: build
	@echo "Starting container..."
	@docker run -d --name $(CONTAINER_NAME)-test \
		-e POSTGRES_PASSWORD=test \
		$(IMAGE_NAME):$(IMAGE_TAG) > /dev/null
	@echo "Waiting for postgres..."
	@sleep 5
	@echo "Testing extensions..."
	@docker exec $(CONTAINER_NAME)-test psql -U postgres -c " \
		CREATE EXTENSION vector; \
		CREATE EXTENSION postgis; \
		CREATE EXTENSION pg_textsearch; \
		CREATE EXTENSION pgsodium; \
		SELECT 'all extensions OK';"
	@docker stop $(CONTAINER_NAME)-test > /dev/null
	@docker rm $(CONTAINER_NAME)-test > /dev/null

# Test postgres-plus-lake (Debian with pg_lake)
test-lake: build-lake
	@echo "Starting container..."
	@docker run -d --name $(CONTAINER_NAME)-lake-test \
		-e POSTGRES_PASSWORD=test \
		$(IMAGE_NAME_LAKE):$(IMAGE_TAG) > /dev/null
	@echo "Waiting for postgres..."
	@sleep 5
	@echo "Testing extensions..."
	@docker exec $(CONTAINER_NAME)-lake-test psql -U postgres -c " \
		CREATE EXTENSION vector; \
		CREATE EXTENSION postgis; \
		CREATE EXTENSION pg_textsearch; \
		CREATE EXTENSION pgsodium; \
		CREATE EXTENSION pg_lake; \
		SELECT 'all extensions OK';"
	@docker stop $(CONTAINER_NAME)-lake-test > /dev/null
	@docker rm $(CONTAINER_NAME)-lake-test > /dev/null

# Test both images
test-all: test test-lake

clean: stop
	docker rmi $(IMAGE_NAME):$(IMAGE_TAG) || true
	docker rmi $(IMAGE_NAME_LAKE):$(IMAGE_TAG) || true

push:
	docker push $(IMAGE_NAME):$(IMAGE_TAG)

push-lake:
	docker push $(IMAGE_NAME_LAKE):$(IMAGE_TAG)
