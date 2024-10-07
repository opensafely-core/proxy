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
run: 
    docker compose up --build --wait $SERVICE

# run tests
test: run
    ./ci-tests.sh

# view proxy logs
logs:
    docker compose logs $SERVICE
