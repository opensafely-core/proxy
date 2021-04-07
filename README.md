# Proxy servers for OpenSAFELY

To secure and limit access to external services, the OpenSAFELY platform
maintains a proxy service. OpenSAFELY backends explicitly use these proxies
when they need to access external data.

This repository produces a Docker image that uses nginx to host two proxy
domains:
 
 * github-proxy.opensafely.org: this provides access to *only* opensafely
   repositories hosted on https://github.com, and not other repositories.

 * docker-proxy.opensafely.org: this provides read only access to docker images
   published by specific Github organistions on https://ghcr.io, the Github
   Container Registry, where the docker images for running the study code are
   stored.


## Building

To build:

    docker build . -t ghcr.io/opensafely-core/opensafely-proxy

By default, it uses 127.0.0.1 as a DNS resolver, and runs on port 8080. You can
override those values with the environment variables RESOLVER and PORT
respectively. 

or

    docker run -d --rm ghcr.io/opensafely-core/opensafely-proxy


## Testing 

To run basic tests:

    make test

This will build and run the image and run ./ci-tests.sh, which is basic http tests.

Full integraton tests can only be run against the current production
deployment, as it requires TLS and DNS:

    ./full-tests.sh

