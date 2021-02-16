#!/bin/bash
set -euo pipefail

EXPECTED='realm="https://ghcr.io/token",service="ghcr.io",scope="repository:user/image:pull"'

ACTUAL="$(curl -si https://ghcr.io/v2/ | grep -i www-authenticate | awk -F' ' '{print $3}')"

echo "$EXPECTED"
echo "$ACTUAL"

test "$ACTUAL" = "$EXPECTED"
