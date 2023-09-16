-include .env

IMAGE_VERSION ?= 1.0
IMAGE_TAG ?= registry.docker.libis.be/teneo/services/email:$(IMAGE_VERSION)
SERVICE_NAME ?= email_service
SERVICE_MOUNTS ?= 
SERVICE_PORT ?= 3000

.SILENT:

build:
	docker build --tag $(IMAGE_TAG) .

start:
	docker run -d --rm -it --name $(SERVICE_NAME) -p "$(SERVICE_PORT):9292" $(IMAGE_TAG)

stop:
	docker container stop $(SERVICE_NAME) || true

logs:
	docker logs -f $(SERVICE_NAME)

shell:
	docker run --rm -it $(IMAGE_TAG) bash