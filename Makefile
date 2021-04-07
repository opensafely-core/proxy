IMAGE_NAME ?= proxy

.PHONY: build
build: Dockerfile
	docker build . -t $(IMAGE_NAME)

.PHONY: run
run:
	docker kill $(IMAGE_NAME) && sleep 1 || true
	docker run -d --rm -p 80:8080 --name $(IMAGE_NAME) $(IMAGE_NAME)
	sleep 1

.PHONY: test
test: run
	./ci-tests.sh
