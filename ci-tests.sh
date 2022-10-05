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

    code="$(
        curl --verbose --output "$body" \
        --connect-to github-proxy.opensafely.org:80:127.0.0.1:8080 \
        --connect-to docker-proxy.opensafely.org:80:127.0.0.1:8080 \
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

# test we can hit our org public repo's http protocol endpoints
try github-proxy.opensafely.org/opensafely/documentation/info/refs?service=git-upload-pack 200
assert-header 'X-GitHub-Request-Id:'
# test we cannot access other parts of the repo
try github-proxy.opensafely.org/opensafely/documentation 403
# test we cannot access other /info/refs queries
try github-proxy.opensafely.org/opensafely/documentation/info/refs?foo=bar 404

# test for opensafely-core org
try github-proxy.opensafely.org/opensafely-core/job-runner/info/refs?service=git-upload-pack 200
assert-header 'X-GitHub-Request-Id:'
# test we cannot access other parts of the repo
try github-proxy.opensafely.org/opensafely-core/job-runner 403

# test for opensafely-actions org
try github-proxy.opensafely.org/opensafely-actions/safetab/info/refs?service=git-upload-pack 200
assert-header 'X-GitHub-Request-Id:'

# test for graphnet-opensafely org
try github-proxy.opensafely.org/graphnet-opensafely/os-demo-research/info/refs?service=git-upload-pack 200
assert-header 'X-GitHub-Request-Id:'

# test other orgs are 403'd, even when they exist
try github-proxy.opensafely.org/torvalds/linux/info/refs?service=git-upload-pack 403
assert-in-body 'Only specific github organisations are supported by this proxy.';
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


exit $return_code
