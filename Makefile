IMAGE_NAME := ghcr.io/ri0day/alidns-webhook-with-role
IMAGE_TAG := $(shell cat VERSION)

test:
	go test -v .

docker:
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) .

release:
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) .
	docker push $(IMAGE_NAME):$(IMAGE_TAG)
