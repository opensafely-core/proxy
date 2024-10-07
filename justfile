set dotenv-load := true

_env:
    test -f .env || cp dotenv-sample .env

build: _env
    docker compose build proxy

kill:
    docker compose stop

run: 
    docker compose up --build --wait $SERVICE

test: run
    ./ci-tests.sh
