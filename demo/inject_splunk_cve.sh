#!/usr/bin/env bash
# Inject a CVE disclosure event into Splunk via HEC
#
# This simulates a security scanner or threat feed pushing a CVE advisory
# into the cve_events index. The Splunk saved search fires every minute,
# detects the event, and sends a webhook to EDA.
#
# Usage:
#   ./inject_splunk_cve.sh                       # uses defaults
#   SPLUNK_HOST=10.0.0.5 ./inject_splunk_cve.sh  # custom host

set -euo pipefail

SPLUNK_HOST="${SPLUNK_HOST:-192.168.88.168}"
SPLUNK_HEC_PORT="${SPLUNK_HEC_PORT:-8088}"
SPLUNK_HEC_TOKEN="${SPLUNK_HEC_TOKEN:-fdd3db64-dba0-43f6-8f7e-b9225996faba}"

echo "=== Injecting CVE Disclosure into Splunk ==="
echo "Target: http://${SPLUNK_HOST}:${SPLUNK_HEC_PORT}/services/collector/event"
echo ""

RESPONSE=$(curl -sk "http://${SPLUNK_HOST}:${SPLUNK_HEC_PORT}/services/collector/event" \
  -H "Authorization: Splunk ${SPLUNK_HEC_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "index": "cve_events",
    "sourcetype": "cve_advisory",
    "source": "threat_intel_feed",
    "event": {
      "event_type": "cve_disclosure",
      "cve_id": "CVE-2026-51234",
      "affected_package": "python-cryptography",
      "affected_version_range": "< 43.0.1",
      "cvss_vector": "CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:C/C:H/I:H/A:H",
      "cvss_score": 10.0,
      "cwe_ids": "[\"CWE-119\", \"CWE-787\"]",
      "description": "Remote code execution vulnerability in python-cryptography due to buffer overflow in X.509 certificate parsing",
      "source": "CISA KEV / NVD",
      "fix_available": false,
      "published_date": "2026-07-30T08:00:00Z",
      "severity": "critical"
    }
  }')

echo "Splunk response: ${RESPONSE}"
echo ""
echo "Event injected into index=cve_events, sourcetype=cve_advisory"
echo ""
echo "Next steps:"
echo "  1. Verify in Splunk UI:  http://${SPLUNK_HOST}:8000/en-US/app/search/search?q=index%3Dcve_events"
echo "  2. The saved search runs every minute and will fire the webhook to EDA"
echo "  3. Check EDA UI for rule activation: 'Splunk alert — CVE disclosure detected'"
echo "  4. Expected workflow: 'Demo — SBOM Correlate and Mitigate'"
