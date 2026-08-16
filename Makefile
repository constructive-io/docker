.PHONY: build run stop clean test verify-security shell push

IMAGE_NAME ?= constructiveio/postgres-plus
IMAGE_TAG ?= latest
CONTAINER_NAME ?= constructive-pg
POSTGRES_PASSWORD ?= postgres

build:
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) .

run:
	docker run -d \
		--name $(CONTAINER_NAME) \
		-e POSTGRES_PASSWORD=$(POSTGRES_PASSWORD) \
		-p 5432:5432 \
		$(IMAGE_NAME):$(IMAGE_TAG)

stop:
	docker stop $(CONTAINER_NAME) || true
	docker rm $(CONTAINER_NAME) || true

restart: stop run

shell:
	docker exec -it $(CONTAINER_NAME) psql -U postgres

logs:
	docker logs -f $(CONTAINER_NAME)

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
		CREATE EXTENSION pg_partman; \
		SELECT 'all extensions OK';"
	@./scripts/verify-postgis-security.sh $(CONTAINER_NAME)-test
	@docker stop $(CONTAINER_NAME)-test > /dev/null
	@docker rm $(CONTAINER_NAME)-test > /dev/null

# Assert the running $(CONTAINER_NAME) is not a PostGIS build vulnerable to
# CVE-2026-73514 / CVE-2026-73515.
verify-security:
	@./scripts/verify-postgis-security.sh $(CONTAINER_NAME)

clean: stop
	docker rmi $(IMAGE_NAME):$(IMAGE_TAG) || true

push:
	docker push $(IMAGE_NAME):$(IMAGE_TAG)
