#!/bin/bash
set -euo pipefail
# Functional test of the proxy deployed with TLS and DNS.
#
BASE_DOMAIN=${BASE_DOMAIN:-opensafely.org}
GITHUB_PROXY_HOST=github-proxy.${BASE_DOMAIN}
DOCKER_PROXY_HOST=docker-proxy.${BASE_DOMAIN}

tmp=$(mktemp -d)
trap 'rm -rf $tmp' EXIT

# test valid org repos
if test "$BASE_DOMAIN" = "opensafely.org"; then
    git clone "https://${GITHUB_PROXY_HOST}/opensafely/documentation" "$tmp/documentation"
    git clone "https://${GITHUB_PROXY_HOST}/opensafely-core/job-runner" "$tmp/job-runner"
elif test "$BASE_DOMAIN" = "ted.bennettoxford.org"; then
    git clone "https://${GITHUB_PROXY_HOST}/niot-ted/os-schools-data" "$tmp/os-schools-data"
fi

# test known invalid org repo
if git clone "https://${GITHUB_PROXY_HOST}/torvalds/linux" "$tmp/linux"; then
    echo "ERROR: succesful cloned torvalds/linux!"
    exit 1
fi

# test we can push, not sure it is worth testing, as it needs creds
#git -C "$tmp/documentation" checkout -b proxy-test-branch
#touch "$tmp/documentation/test"
#git -C "$tmp/documentation" add test
#git -C "$tmp/documentation" ci -m "test" 
#git -C "$tmp/documentation" push origin proxy-test-branch --force
#git -C "$tmp/documentation" push origin proxy-test-branch --delete

# test we can pull opensafely-core images
docker pull "${DOCKER_PROXY_HOST}/opensafely-core/base-docker"

# we shouldn't be allowed to pull opensafely images, just opensafely-core
code=0
docker pull "${DOCKER_PROXY_HOST}/opensafely/busybox" 2>/dev/null || code=$?
if test "$code" = "0"; then
    echo "ERROR: succesfully pulled opensafely/busybox image"
    exit 1
fi
