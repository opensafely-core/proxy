# Docker Proxy for ghcr.io

This hosts the Dockerfile for building an nginx docker image that will proxy traffic to ghcr.io.

It also caches docker layers, and is RO - no uploads allowed.

To build:

`docker build . -t ghcr.io/opensafely/docker-proxy`

To run

`docker run -d  -e PROXY_DOMAIN=<domain> -e PROXY_ORIGIN=<origin> -e RESOLVER=127.0.01 -e PORT=80 ghcr.io/opensafely/docker-proxy`

To quick test, check that the realm in the www-authenticate header is correct:

`curl -v <domain>/v2/`

Also try

`docker pull <domain>/opensafely/cohortextractor`
