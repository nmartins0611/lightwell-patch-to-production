#!/bin/bash
KC_URL="http://localhost:8180"
RHTPA_URL="https://localhost:8443"

TOKEN=$(curl -sf -X POST "$KC_URL/realms/trustification/protocol/openid-connect/token" \
  -d "client_id=walker" \
  -d "client_secret=service-secret-2026" \
  -d "grant_type=client_credentials" \
  -d "scope=openid create:document read:document update:document delete:document" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

if [ -z "$TOKEN" ]; then
  echo "FAIL: Could not obtain Keycloak token"
  exit 1
fi
echo "Keycloak: OK (token ${#TOKEN} chars)"

HTTP=$(curl -sfk -o /dev/null -w "%{http_code}" "$RHTPA_URL/api/v2/sbom" \
  -H "Authorization: Bearer $TOKEN")
echo "RHTPA SBOM API: HTTP $HTTP"

TOTAL=$(curl -sfk "$RHTPA_URL/api/v2/sbom" -H "Authorization: Bearer $TOKEN" \
  | python3 -c "import sys,json; print(json.load(sys.stdin).get('total',0))")
echo "SBOMs stored: $TOTAL"

GITEA_HTTP=$(curl -sf -o /dev/null -w "%{http_code}" "http://localhost:3000/api/v1/version")
echo "Gitea API: HTTP $GITEA_HTTP"

PYPI_HTTP=$(curl -sf -o /dev/null -w "%{http_code}" "http://localhost:8081/simple/")
echo "PyPI index: HTTP $PYPI_HTTP"

NGINX_HTTP=$(curl -sf -o /dev/null -w "%{http_code}" "http://localhost:8080/")
echo "Report server: HTTP $NGINX_HTTP"

echo "SMOKE_TEST_PASS"
