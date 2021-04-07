#!/bin/bash
set -euo pipefail
# This tests against proxy deployed with TLS and DNS.
#
tmp=$(mktemp -d)
trap 'rm -rf $tmp' EXIT

# test valid repos
git clone https://github-proxy.opensafely.org/opensafely/documentation "$tmp/documentation"
git clone https://github-proxy.opensafely.org/opensafely-core/job-runner "$tmp/job-runner"

if git clone https://github-proxy.opensafely.org/torvalds/linux "$tmp/linux"; then
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

docker pull docker-proxy.opensafely.org/opensafely-core/base-docker

# we shouldn't be allowed to pull opensafely images, just opensafely-core
if docker pull docker-proxy.opensafely.org/opensafely/busybox; then
    echo "ERROR: succesfully pulled opensafely/busybox image"
    exit 1
fi
