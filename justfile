export IMAGE_NAME := "proxy"
export RESOLVER := "127.0.0.53"
export PORT := "8080"

build:
	docker build . -t $IMAGE_NAME

kill:
	docker kill $IMAGE_NAME && sleep 1 || true

run: build kill
	docker run -d --rm -e RESOLVER -e PORT --network=host --name $IMAGE_NAME $IMAGE_NAME
	sleep 1

test: run
	./ci-tests.sh
