include .env
-include .env.local


.SILENT:

restart: stop build start logs

build:
	docker build --tag $(IMAGE_TAG) .

start:
	docker run -d --rm -it --name $(SERVICE_NAME) $(SERVICE_MOUNTS) -p "$(SERVICE_PORT):9292" $(IMAGE_TAG)

stop:
	docker container stop $(SERVICE_NAME) || true

logs:
	docker logs -f $(SERVICE_NAME)

shell:
	docker run --rm -it $(IMAGE_TAG) bash

dev-build:
	docker build --tag $(IMAGE_TAG_DEV) -f Dockerfile.dev .

dev-start:
	docker run -d --rm -it --name $(SERVICE_NAME_DEV) $(SERVICE_MOUNTS_DEV) -p "$(SERVICE_PORT_DEV):9292" $(IMAGE_TAG_DEV)

dev-logs:
	docker logs -f $(SERVICE_NAME_DEV)

dev-stop:
	docker container stop $(SERVICE_NAME_DEV) || true

dev-restart: dev-stop dev-build dev-start dev-logs

dev: dev-stop dev-start dev-logs

test:
	rerun --dir . --pattern="**/*.{rb,ru}" "bundle exec puma -p $(SERVICE_PORT_TEST)"

install:
	bundle install
