#!/bin/bash
set -euo pipefail
# In CI, we do not have TLS/DNS set up. Docker requires TLS, so we cannot do
# proper functional tests until post deployment. And most tools require DNS in
# order to hit the right vhost in nginx.
#
# So we use curl's --resolve option to query the base APIs to check we get the
# appropriate responses at the http level.
#
# see also: full-tests.sh, which can be run post deploy 
# 
url=
body=$(mktemp)
headers=$(mktemp)
return_code=0

last_test_failed=0

fail() {
    echo "FAIL: $*"
    last_test_failed=1
    return_code=1
    cat "$headers"
    cat "$body"
}

ok() {
    echo "OK: $*"
    last_test_failed=0
}

try() {
    # reset tests
    last_test_failed=0
    # global
    url=$1
    local expected=$2
    local token=${3:-}

    local curl_args=()

    curl_args+=(-s --verbose --output "$body")
    curl_args+=(--write-out "%{http_code}")
    curl_args+=(--connect-to github-proxy.opensafely.org:80:127.0.0.1:8080)
    curl_args+=(--connect-to docker-proxy.opensafely.org:80:127.0.0.1:8080)
    curl_args+=(--connect-to opencodelists-proxy.opensafely.org:80:127.0.0.1:8080)
    curl_args+=(--connect-to changelogs.opensafely.org:80:127.0.0.1:8080)

    # Conditionally token if set. Only used for docker-proxy tests.
    if test -n "${token}"; then
        curl_args+=(-H "Authorization: Bearer $token")
    fi

    curl_args+=("$url")         # Add the URL

    # Call curl with the arguments
    code=$(curl "${curl_args[@]}" 2> "$headers")

    if test "$code" != "$expected"; then
        fail "$url returned $code, not $expected"
    else
        ok "$url returned $code"
    fi
}

git-post() {
    # reset tests
    last_test_failed=0
 
    type_=$1
    url=$2
    local expected=$3

    code="$(
        curl --verbose --output "$body" -X POST \
        -H "accept-encoding: deflate, gzip, br, zstd" \
        -H "content-type: application/x-$type_-request" \
        -H "accept: application/x-$type_-result" \
        -H "git-protocol: version=2" \
        --connect-to github-proxy.opensafely.org:80:127.0.0.1:8080 \
        --write-out "%{http_code}"\
        "$url" \
        2> "$headers"
    )"

    if test "$code" != "$expected"; then
        fail "$url returned $code, not $expected"
    else
        ok "$url returned $code"
    fi
}

    
assert-in-body() {
    if test "$last_test_failed" = "1"; then
        echo "SKIP assert body"
        return
    fi
    local expected=$1
    if grep -sq -F "$expected" "$body"; then
        ok "$url returned expected body"
    else
        fail "$url returned unexpected body"
    fi
}

assert-header() {
    if test "$last_test_failed" = "1"; then
        echo "SKIP assert header"
        return
    fi
    local expected=$1
    if grep -sq "$1" "$headers"; then
        ok "$url returned expected header $1"
    else
        fail "$url did not return header $1"
    fi
}

### github-proxy.opensafely.org ###

# test we can query the clone metadata endpoint
try github-proxy.opensafely.org/opensafely/documentation/info/refs?service=git-upload-pack 200
assert-header 'X-GitHub-Request-Id:'

# test we can query the actul clone endpoint on public repo
git-post git-upload-pack github-proxy.opensafely.org/opensafely/documentation/git-upload-pack 200
assert-header 'X-GitHub-Request-Id:'

# test we can query the actul clone endpoint on private repo
git-post git-upload-pack github-proxy.opensafely.org/opensafely/server-instructions/git-upload-pack 401
assert-header 'X-GitHub-Request-Id:'


# test we cannot query the push metadata endpoint
try github-proxy.opensafely.org/opensafely/documentation/info/refs?service=git-receive-pack 403

# test we cannot query the actual push endpoint
git-post git-recieve-pack github-proxy.opensafely.org/opensafely/documentation/git-receive-pack 403

# test we cannot access other parts of the repo
try github-proxy.opensafely.org/opensafely/documentation 403
# test we cannot access other /info/refs queries
try github-proxy.opensafely.org/opensafely/documentation/info/refs?foo=bar 403

# test we cannot access other parts of the repo
try github-proxy.opensafely.org/opensafely-core/job-runner 403

# test for opensafely-actions org
try github-proxy.opensafely.org/opensafely-actions/safetab/info/refs?service=git-upload-pack 200
assert-header 'X-GitHub-Request-Id:'

# test other orgs are 403'd, even when they exist
try github-proxy.opensafely.org/torvalds/linux/info/refs?service=git-upload-pack 403
assert-in-body 'This proxy only supports fetching commits from specific github organisations.'
assert-header 'Content-Type: text/plain; charset=UTF-8'

# test keys
try github-proxy.opensafely.org/bloodearnest.keys 200
assert-in-body ed25519

# test download
try github-proxy.opensafely.org/opensafely-core/backend-server/releases/download/v0.1/test-download 200
assert-in-body test

### docker-proxy.opensafely.org ###

# test the initial docker request is rewritten correctly
try docker-proxy.opensafely.org/v2/ 401
assert-in-body '{"errors":[{"code":"UNAUTHORIZED","message":"authentication required"}]}'
assert-header 'X-GitHub-Request-Id:'
assert-header 'Www-Authenticate: Bearer realm="https://docker-proxy.opensafely.org/token",service="docker-proxy.opensafely.org",scope="repository:user/image:pull"'

# test other projects are 404'd
try docker-proxy.opensafely.org/v2/other/project 404 
assert-in-body '{ "errors": [{"code": "NAME_UNKNOWN", "message": "only opensafely repositories allowed" }] }';
assert-header 'Content-Type: application/json; charset=UTF-8'

# test the anonlymous login dance. ffs.
# get a token
try "docker-proxy.opensafely.org/token?scope=repository%3Aopensafely-core%2Fairlock%3Apull&service=ghcr.io" 200
token=$(jq -r .token < "$body")

# use the token to get the manifest
try docker-proxy.opensafely.org/v2/opensafely-core/busybox/manifests/latest 200 "$token"
digest=$(jq -r .config.digest < "$body")

# try download a content blob, which will test our internal redirect handling,
# including the strict ssl/host config
try "docker-proxy.opensafely.org/v2/opensafely-core/busybox/blobs/$digest?" 200 "$token"

### opencodelists-proxy.opensafely.org ###

# we should allow this specific call...
try opencodelists-proxy.opensafely.org/api/v1/dmd-mapping/ 200

# ...but not any others
try opencodelists-proxy.opensafely.org/api/v1/codelist/ 404

### changelogs.opensafely.org ###

# This allows us to use the do-release-upgrade tool to perform major backend OS upgrades.
try changelogs.opensafely.org/meta-release-lts 200

exit $return_code
