# Proxy servers for OpenSAFELY

To secure and limit access to external services, the OpenSAFELY platform
maintains a proxy service. OpenSAFELY backends explicitly use these proxies
when they need to access external data.

This repository produces a Docker image that uses nginx to host four proxy
domains, each has their own nginx config file:
 
 * github-proxy.opensafely.org: this provides access to *only* opensafely
   repositories hosted on https://github.com, and not other repositories. It
   also restricts access to certain paths within those organisations.

 * docker-proxy.opensafely.org: this provides read only access to docker images
   published by specific Github organistions on https://ghcr.io, the Github
   Container Registry, where the docker images for running the study code are
   stored.

 * opencodelists-proxy.opensafely.org: this provides access to a single OpenCodelists
   API endpoint.

 * changelogs.opensafely.org: this allows us to use the do-release-upgrade tool
   to perform major OS upgrades.

Whilst the last two are very simple, the first two requires some shenagins in
order to proxy git http protocol and docker registry API v2.0 protocol. 

Of particular note is that ghcr.io issues 307 redirects for blob urls to
a Fastly CDN url. Normally, this is pass back to the client, which fetchs the
CDN url. However, that won't work in our backends, as we do not have access to
Fastly. So, we use an `internal` nginx handler to resolve and fetch the Fastly
url, and return the response to the original client.  Basically, we follow the
redirect in nginx.

## Building docker image
 
To build

    just build

## Running

This will run the container in docker on port 8080. It uses `network_mode:
host` in order to have access to the hosts resolver at 127.0.0.53.

    just run 

Because we use handle redirects dynamically, we need to configure a DNS
resolver at run time.  We use 127.0.0.53 by default, assuming you are running
modern Ubuntu, you may need to use something different by editing .env

## Testing 

To run basic tests:

    just test

This will build and run the image and run ./ci-tests.sh, which is basic http
tests. These tests use the very useful `--connect-to` argument to curl, and as
such, are written in bash.

You can inspect the nginx logs with:

    docker compose logs proxy


## Integration tests

Full integraton tests can only be run against the current production
deployment, as it requires TLS and DNS:

    ./full-tests.sh


## Debug build

If you change SERVICE=debug in .env, `just run` will use the debug docker
compose service, which runs with nginx debug logs. This is very verbose, but
logs all request and response headers, so can be useful.

To look at the debug logs, you can do:
    
    docker compose logs debug


## Deployment notes

The proxy is deployed like any other dokku app, as a docker image.  This means
the proxy is behind dokku's nginx, so doesn't handle TLS. The flow is:

    HTTPS/433 --> dokku nginx --> HTTP/8080 --> proxy nginx --> HTTPS/443 --> Proxied domain

This means we need to pay attention to some nginx settings on the dokku nginx
too.  Specifically, in order to successfully get user keys from Github, some
buffer settings need to be tweaked - in both the conf file in this repo as well
as the dokku config. You can do this thusly:

```
dokku:~$ dokku nginx:set proxy proxy-busy-buffers-size 16k
=====> Setting proxy-busy-buffers-size to 16k
dokku:~$ dokku nginx:set proxy proxy-buffer-size 16k
=====> Setting proxy-buffer-size to 16k
dokku:~$ dokku ps:restart proxy
```
