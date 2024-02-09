export IMAGE_NAME := env_var_or_default('IMAGE_NAME', "proxy")
export RESOLVER := "127.0.0.53"
export PORT := "8080"

build:
    docker build . -t $IMAGE_NAME

kill:
    docker kill $IMAGE_NAME && sleep 1 || true
    docker container rm $IMAGE_NAME || true

run: build kill
    #!/bin/bash
    set -euo pipefail
    docker run -d -e RESOLVER -e PORT --network=host --name $IMAGE_NAME $IMAGE_NAME
    sleep 1
    if test "$(docker container inspect -f '{{{{.State.Running}}' $IMAGE_NAME)" != "true"; then
        docker logs $IMAGE_NAME
        exit 1
    fi


test: run
    ./ci-tests.sh
