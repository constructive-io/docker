.PHONY: build run stop clean test shell push

IMAGE_NAME ?= constructive/postgres
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
		CREATE EXTENSION pgsodium; \
		SELECT 'all extensions OK';"
	@docker stop $(CONTAINER_NAME)-test > /dev/null
	@docker rm $(CONTAINER_NAME)-test > /dev/null

clean: stop
	docker rmi $(IMAGE_NAME):$(IMAGE_TAG) || true

push:
	docker push $(IMAGE_NAME):$(IMAGE_TAG)
