#!/usr/bin/env bash
# Demo Trigger: RHSA Available (Lightwell resolved the CVE)
#
# Fires a webhook to EDA simulating the upstream fix being published.
# This triggers Demo 3 (container test → patch → verify → close loop).

set -euo pipefail

EDA_HOST="${EDA_HOST:-localhost}"
EDA_PORT="${EDA_PORT:-5000}"

echo "=== Firing RHSA Available Event ==="
echo "Target: http://${EDA_HOST}:${EDA_PORT}/endpoint"
echo ""
echo "Narrative: Project Lightwell resolved CVE-2026-51234 upstream."
echo "           Red Hat published RHSA-2026:4521."
echo ""

curl -s -X POST "http://${EDA_HOST}:${EDA_PORT}/endpoint" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "rhsa_available",
    "cve_id": "CVE-2026-51234",
    "advisory_id": "RHSA-2026:4521",
    "fixed_package": "python3-cryptography",
    "fixed_version": "43.0.1-2.el9",
    "resolved_by": "Project Lightwell",
    "resolution_date": "2026-07-30T12:00:00Z",
    "description": "Red Hat has released python-cryptography 43.0.1-2.el9 which resolves the buffer overflow in X.509 certificate parsing",
    "source": "Red Hat Security Advisory"
  }' | jq . 2>/dev/null || echo "(sent)"

echo ""
echo "Event fired. Check EDA UI for rule activation."
echo "Expected: Workflow 'Patch Test and Deploy' should launch."
