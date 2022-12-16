IMAGE_NAME ?= proxy
export RESOLVER ?= 127.0.0.53
export PORT ?= 8080

.PHONY: build
build: Dockerfile
	docker build . -t $(IMAGE_NAME)

.PHONY: run
run: build
	docker kill $(IMAGE_NAME) && sleep 1 || true
	docker run -d --rm -e RESOLVER -e PORT --network=host --name $(IMAGE_NAME) $(IMAGE_NAME)
	sleep 1


.PHONY: test
test: run
	./ci-tests.sh
