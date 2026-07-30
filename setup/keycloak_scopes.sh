#!/bin/bash

KC_URL="http://localhost:8180"
KC_REALM="trustification"

echo "Getting admin token..."
TOKEN=$(curl -sf -X POST "$KC_URL/realms/master/protocol/openid-connect/token" \
  -d "client_id=admin-cli" \
  -d "username=admin" \
  -d "password=admin" \
  -d "grant_type=password" | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

if [ -z "$TOKEN" ]; then
  echo "ERROR: Failed to get admin token"
  exit 1
fi

SCOPES="create:document read:document update:document delete:document"

for SCOPE in $SCOPES; do
  echo "Creating client scope: $SCOPE"
  curl -sf -o /dev/null -w "  HTTP: %{http_code}\n" \
    -X POST "$KC_URL/admin/realms/$KC_REALM/client-scopes" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
      \"name\": \"$SCOPE\",
      \"protocol\": \"openid-connect\",
      \"attributes\": {
        \"include.in.token.scope\": \"true\",
        \"display.on.consent.screen\": \"false\"
      }
    }"
done

echo ""
echo "Getting walker client ID..."
WALKER_ID=$(curl -sf "$KC_URL/admin/realms/$KC_REALM/clients?clientId=walker" \
  -H "Authorization: Bearer $TOKEN" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['id'])")
echo "  Walker UUID: $WALKER_ID"

echo ""
echo "Assigning scopes to walker client..."
SCOPE_IDS=$(curl -sf "$KC_URL/admin/realms/$KC_REALM/client-scopes" \
  -H "Authorization: Bearer $TOKEN")

for SCOPE in $SCOPES; do
  SCOPE_ID=$(echo "$SCOPE_IDS" | python3 -c "
import sys, json
scopes = json.load(sys.stdin)
for s in scopes:
    if s['name'] == '$SCOPE':
        print(s['id'])
        break
")
  if [ -n "$SCOPE_ID" ]; then
    curl -sf -o /dev/null -w "  $SCOPE -> HTTP: %{http_code}\n" \
      -X PUT "$KC_URL/admin/realms/$KC_REALM/clients/$WALKER_ID/default-client-scopes/$SCOPE_ID" \
      -H "Authorization: Bearer $TOKEN"
  fi
done

echo ""
echo "Getting frontend client ID..."
FRONTEND_ID=$(curl -sf "$KC_URL/admin/realms/$KC_REALM/clients?clientId=frontend" \
  -H "Authorization: Bearer $TOKEN" | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['id'])")
echo "  Frontend UUID: $FRONTEND_ID"

echo ""
echo "Assigning scopes to frontend client..."
for SCOPE in $SCOPES; do
  SCOPE_ID=$(echo "$SCOPE_IDS" | python3 -c "
import sys, json
scopes = json.load(sys.stdin)
for s in scopes:
    if s['name'] == '$SCOPE':
        print(s['id'])
        break
")
  if [ -n "$SCOPE_ID" ]; then
    curl -sf -o /dev/null -w "  $SCOPE -> HTTP: %{http_code}\n" \
      -X PUT "$KC_URL/admin/realms/$KC_REALM/clients/$FRONTEND_ID/default-client-scopes/$SCOPE_ID" \
      -H "Authorization: Bearer $TOKEN"
  fi
done

echo ""
echo "SCOPES_CONFIGURED"

echo ""
echo "=== Verify: get token with scopes ==="
SVC_TOKEN=$(curl -sf -X POST "$KC_URL/realms/$KC_REALM/protocol/openid-connect/token" \
  -d "client_id=walker" \
  -d "client_secret=service-secret-2026" \
  -d "grant_type=client_credentials" \
  -d "scope=openid create:document read:document update:document delete:document" | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

echo "$SVC_TOKEN" | python3 -c "
import sys, base64, json
token = sys.stdin.read().strip()
parts = token.split('.')
payload = parts[1] + '=' * (4 - len(parts[1]) % 4)
decoded = json.loads(base64.urlsafe_b64decode(payload))
print('Issuer:', decoded.get('iss'))
print('Scope:', decoded.get('scope'))
print('Client:', decoded.get('client_id'))
"
