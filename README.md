# Docker Proxy for ghcr.io

This hosts the Dockerfile for building an nginx docker image that will proxy
traffic to ghcr.io for the OpenSAFELY project.

OpenSAFELY publishes its open docker images via ghcr.io, which are needed by
backends to run OpenSAFELY studies. However, we don't want to require backends
to allow network access to ghcr.io, as that could in theory be used to
exfiltrate data.

So this proxy provides a single point of read-only access to only the
OpenSAFELY images on ghcr.io, by only proxying GET requests to /v2/opensafely/
urls.


## Building

To build:

`docker build . -t ghcr.io/opensafely-core/docker-proxy`

Config is supplied via env vars:

 - `PROXY_DOMAIN`: user visible domain, e.g. docker.opensafely.org, which hosted by cloudflare
 - `PROXY_ORIGIN`: the backend, e.g. docker-proxy.dokku2.ebmdatalab.org
 - `RESOLVER`: DNS resolver for dynamically looking up redirect domains
 - `PORT`: provided by dokku, defaults to 80

To run locally:

`docker run -d  -e PROXY_DOMAIN=<domain> -e PROXY_ORIGIN=<origin> -e RESOLVER=127.0.0.1 -e PORT=80 ghcr.io/opensafely-core/docker-proxy`

## Testing 

To quickly test, check that the realm in the www-authenticate header is
correct:

`curl -v docker-proxy.opensafely.org/v2/ |& grep Www-Auth`

Output should include:

`Bearer realm="https://$PROXY_DOMAIN/token",service="$PROXY_DOMAIN",scope="repository:user/image:pull"`

Also try pulling an image via the proxy:

`docker pull $PROXY_DOMAIN/opensafely-core/cohortextractor`

This should pull the image from ghcr.io, but proxied via this nginx proxy.

Note that the images will be tagged locally by docker client as
`$PROXY_DOMAIN/opensafely-core/<name>`, not their official
`ghcr.io/opensafely-core/<name>` tag. This is sadly unavoidable without some kind of
MITM certificate for ghcr.io, as the docker client only communicates over
HTTPS.
