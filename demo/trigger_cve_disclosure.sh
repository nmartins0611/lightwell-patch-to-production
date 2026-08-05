#!/usr/bin/env bash
# Demo Trigger: CVE Disclosure (no fix available yet)
#
# Fires a webhook to EDA simulating a CVE advisory notification.
# This triggers Demo 1 (SBOM correlation) + Demo 2 (CME mitigation).

set -euo pipefail

EDA_HOST="${EDA_HOST:-localhost}"
EDA_PORT="${EDA_PORT:-5000}"

echo "=== Firing CVE Disclosure Event ==="
echo "Target: http://${EDA_HOST}:${EDA_PORT}/endpoint"
echo ""

curl -s -X POST "http://${EDA_HOST}:${EDA_PORT}/endpoint" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "cve_disclosure",
    "cve_id": "CVE-2026-51234",
    "affected_package": "python-cryptography",
    "affected_version_range": "< 43.0.1",
    "cvss_vector": "CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:C/C:H/I:H/A:H",
    "cvss_score": 10.0,
    "cwe_ids": ["CWE-119", "CWE-787"],
    "description": "Remote code execution vulnerability in python-cryptography due to buffer overflow in X.509 certificate parsing",
    "source": "CISA KEV / NVD",
    "fix_available": false,
    "published_date": "2026-07-30T08:00:00Z"
  }' | jq . 2>/dev/null || echo "(sent)"

echo ""
echo "Event fired. Check EDA UI for rule activation."
echo "Expected: Workflow 'SBOM Correlate and Mitigate' should launch."
