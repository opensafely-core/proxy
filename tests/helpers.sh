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

# Usage: try URL EXPECTED_CODE [TOKEN] [USER_AGENT]
try() {
    # reset tests
    last_test_failed=0
    # global
    url=$1
    local expected=$2
    local token=${3:-}
    local user_agent=${4:-}

    local args=()

    # Conditionally token if set. Only used for docker-proxy tests.
    if test -n "${token}"; then
        args+=(-H "Authorization: Bearer $token")
    fi

    # Conditionally set user agent; only used for APT proxy tests
    if test -n "${user_agent}"; then
        args+=(--user-agent "$user_agent")
    fi

    _curl "${args[@]}" "$url"
    _check_code "$expected"
}

# Usage: git-post SERVICE URL EXPECTED_CODE
git-post() {
    # reset tests
    last_test_failed=0

    local type_=$1
    # global
    url=$2
    local expected=$3

    _curl -X POST \
        -H "accept-encoding: deflate, gzip, br, zstd" \
        -H "content-type: application/x-$type_-request" \
        -H "accept: application/x-$type_-result" \
        -H "git-protocol: version=2" \
        "$url"
    _check_code "$expected"
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

# Usage: assert-header 'Name: value-prefix'
#
# Passes if the most recent response has a header called Name whose value
# starts with value-prefix. The name is matched case-insensitively, as HTTP
# header names are. The value is matched literally and case-sensitively.
# 'Name:' on its own checks only that the header is present. Only response
# headers are checked, not the request headers that curl --verbose also
# logs.
assert-header() {
    if test "$last_test_failed" = "1"; then
        echo "SKIP assert header"
        return
    fi
    local expected=$1
    local expected_name=${expected%%:*}
    local expected_value=${expected#*:}
    local line name value
    # curl --verbose logs response headers as "< Name: value"
    while IFS= read -r line; do
        [[ $line == "< "* ]] || continue
        line=${line#< }
        name=${line%%:*}
        value=${line#*:}
        if [[ ${name,,} == "${expected_name,,}" && $value == "$expected_value"* ]]; then
            ok "$url returned expected header $expected"
            return
        fi
    done < "$headers"
    fail "$url did not return header $expected"
}

# Internal helpers.

# Run curl against the local proxy, routing every proxy hostname to
# 127.0.0.1:8080. Extra curl arguments (method, headers, URL) are passed
# through. The response body goes to $body and curl's verbose output
# (including headers) to $headers.
#
# Sets the global $code to the HTTP status. If curl itself fails (e.g.
# connection refused), $code is set to "curl-exit-N" instead, so the failure
# is recorded by the caller rather than aborting the script under `set -e`.
_curl() {
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

    curl_args+=("$@")

    code=$(curl "${curl_args[@]}" 2> "$headers") || code="curl-exit-$?"
}

# Compare $code (set by _curl) with the expected status code.
_check_code() {
    local expected=$1
    if test "$code" != "$expected"; then
        fail "$url returned $code, not $expected"
    else
        ok "$url returned $code"
    fi
}
