# Proxy servers for OpenSAFELY

To secure and limit access to external services, the OpenSAFELY platform
maintains a proxy service. OpenSAFELY backends explicitly use these proxies
when they need to access external data.

This repository produces a Docker image that uses nginx to host three proxy
domains:
 
 * github-proxy.opensafely.org: this provides access to *only* opensafely
   repositories hosted on https://github.com, and not other repositories. It
   also restricts access to certain paths within those organisations.

 * docker-proxy.opensafely.org: this provides read only access to docker images
   published by specific Github organistions on https://ghcr.io, the Github
   Container Registry, where the docker images for running the study code are
   stored.

 * opencodelists-proxy.opensafely.org: this provides access to a single OpenCodelists
   API endpoint.


## Building
 
To build

    just build

## Running

Because we use handle redirects dyanmically, we need to configure a DNS
resolver at run time. The Makefile uses 127.0.0.53 by default, assumes you are
running modern Ubuntu, you may need to use something different

    just run [RESOLVER=...]

This will run the container in docker on port 8080. It uses --network=host in
order to have access to the hosts resolver at 127.0.0.53

## Testing 

To run basic tests:

    just test

This will build and run the image and run ./ci-tests.sh, which is basic http
tests.

Full integraton tests can only be run against the current production
deployment, as it requires TLS and DNS:

    ./full-tests.sh

## Debug build

Ir you `export IMAGE_NAME=proxy-debug`, just run/test will now use build of the
image with nginx debug logs on, for diagnosing issues.



