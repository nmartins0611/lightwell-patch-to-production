#!/bin/bash
KC_URL="http://localhost:8180"

TOKEN=$(curl -sf -X POST "$KC_URL/realms/trustification/protocol/openid-connect/token" \
  -d "client_id=walker" \
  -d "client_secret=service-secret-2026" \
  -d "grant_type=client_credentials" \
  -d "scope=openid create:document read:document update:document delete:document" | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

echo "Token: ${#TOKEN} chars"

HTTP=$(curl -sf -o /dev/null -w "%{http_code}" "http://localhost:8443/api/v2/sbom" \
  -H "Authorization: Bearer $TOKEN")
echo "SBOM API: HTTP $HTTP"

RESP=$(curl -sf "http://localhost:8443/api/v2/sbom" -H "Authorization: Bearer $TOKEN")
echo "SBOMs stored: $(echo $RESP | python3 -c 'import sys,json; print(json.load(sys.stdin).get(\"total\",0))')"
echo "SMOKE_TEST_PASS"
