set dotenv-load := true

_env:
    test -f .env || cp dotenv-sample .env

# build docker image
build: _env
    docker compose build proxy

# kill any runnign services
kill:
    docker compose stop

# run the proxy locally
run domain="opensafely.org": _env
    #!/usr/bin/env bash
    export BASE_DOMAIN="{{ domain }}"
    docker compose up --build --wait $SERVICE

# run tests for specific base domain
test domain="opensafely.org": (run domain)
    #!/usr/bin/env bash
    export BASE_DOMAIN="{{ domain }}"
    ./ci-tests.sh

# view proxy logs
logs:
    docker compose logs $SERVICE
