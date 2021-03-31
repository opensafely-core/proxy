#!/bin/bash
set -euo pipefail
# This tests against proxy deployed with TLS and DNS.
#
tmp=$(mktemp -d)
trap 'rm -rf $tmp' EXIT

# test valid repos
git clone https://github-proxy.opensafely.org/opensafely/documentation "$tmp/"
git clone https://github-proxy.opensafely.org/opensafely-core/job-runner "$tmp/"

git clone https://github-proxy.opensafely.org/torvalds/linux "$tmp/" && { echo "ERROR: cloned torvalds/linux!"; exit 1; }

# test we can push, not sure it is worth testing, as it needs creds
#git -C "$tmp/documentation" checkout -b proxy-test-branch
#touch "$tmp/documentation/test"
#git -C "$tmp/documentation" add test
#git -C "$tmp/documentation" ci -m "test" 
#git -C "$tmp/documentation" push origin proxy-test-branch --force
#git -C "$tmp/documentation" push origin proxy-test-branch --delete

docker pull https://docker-proxy.opensafely.org/opensafely-core/base-docker

# we shouldn't be allowed to pull opensafely images, just opensafely-core
docker pull https://docker-proxy.opensafely.org/opensafely/busybox && { echo "ERROR: pulled opensafely/busybox image1"; exit 1; }
