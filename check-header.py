import sys
import requests

resp = requests.get("https://ghcr.io/v2/")
expected = 'Bearer realm="https://ghcr.io/token",service="ghcr.io",scope="repository:user/image:pull"'
header = resp.headers['www-authenticate']

print("www-authenticate: " + header)

if header == expected:
    print('www-authenticate is as expected')
else:
    sys.exit('www-authenticate header has changed!')
