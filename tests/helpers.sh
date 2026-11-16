# Shared helpers for tests/ci-tests.sh.
#
# Source this file; don't execute it. The caller must define the *_PROXY_HOST
# and TLS_VERIFY_TEST_HOST variables before sourcing it, because try and
# git-post use them to route requests to the local proxy.
#
# State shared between helpers:
#   url              the URL of the most recent request
#   body, headers    temp files holding the most recent response body and
#                    curl's verbose output (including headers)
#   last_test_failed 1 if the most recent check failed, so that follow-up
#                    assert-* calls are skipped
#   return_code      1 if any check has failed; the caller exits with it

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
    local user_agent=${4:-}

    local curl_args=()

    curl_args+=(-s --verbose --output "$body")
    curl_args+=(--write-out "%{http_code}")
    curl_args+=(--connect-to "${GITHUB_PROXY_HOST}:80:127.0.0.1:8080")
    curl_args+=(--connect-to "${DOCKER_PROXY_HOST}:80:127.0.0.1:8080")
    curl_args+=(--connect-to "${UBUNTU_ARCHIVE_PROXY_HOST}:80:127.0.0.1:8080")
    curl_args+=(--connect-to "${UBUNTU_SECURITY_PROXY_HOST}:80:127.0.0.1:8080")
    curl_args+=(--connect-to "${RELEASE_PROXY_HOST}:80:127.0.0.1:8080")
    curl_args+=(--connect-to "${TLS_VERIFY_TEST_HOST}:80:127.0.0.1:8080")
    #curl_args+=(--connect-to "${CHANGELOGS_PROXY_HOST}:80:127.0.0.1:8080")

    # Conditionally token if set. Only used for docker-proxy tests.
    if test -n "${token}"; then
        curl_args+=(-H "Authorization: Bearer $token")
    fi

    # Conditionally set user agent; only used for APT proxy tests
    if test -n "${user_agent}"; then
        curl_args+=(--user-agent "$user_agent")
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
        --connect-to "${GITHUB_PROXY_HOST}:80:127.0.0.1:8080" \
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
