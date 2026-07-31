#!/usr/bin/env bash
# Demo Trigger: App Dependency Fix (CI/CD Direct Path)
#
# Fires a webhook to EDA simulating Lightwell publishing a fixed library
# to an internal package index. This triggers the CI/CD rebuild workflow.
#
# Use: ./demo/trigger_app_dependency_fix.sh [cicd|gitops]

set -euo pipefail

EDA_HOST="${EDA_HOST:-localhost}"
EDA_PORT="${EDA_PORT:-5000}"
MODE="${1:-cicd}"

echo "=== App Dependency Fix Event ==="
echo "Target: http://${EDA_HOST}:${EDA_PORT}/endpoint"
echo "Mode: ${MODE}"
echo ""
echo "Narrative: Project Lightwell resolved CVE-2026-52891 (pyyaml deserialization)"
echo "           and published the fixed package to internal PyPI index."
echo ""
echo "KEY DISTINCTION: This is a BUILD-TIME fix, not deploy-time."
echo "The library is an application dependency — remediation requires"
echo "rebuilding the application via CI/CD, not running dnf update."
echo ""

if [[ "${MODE}" == "gitops" ]]; then
  EVENT_TYPE="app_dependency_fix_gitops"
  WORKFLOW_DESC="GitOps PR → CI build → merge → CD deploy → health check"
else
  EVENT_TYPE="app_dependency_fix"
  WORKFLOW_DESC="Update dep → trigger CI/CD → build artifact → deploy → health check"
fi

curl -s -X POST "http://${EDA_HOST}:${EDA_PORT}/endpoint" \
  -H "Content-Type: application/json" \
  -d "{
    \"type\": \"${EVENT_TYPE}\",
    \"cve_id\": \"CVE-2026-52891\",
    \"affected_library\": \"pyyaml\",
    \"affected_versions\": \"< 6.0.2\",
    \"fixed_version\": \"6.0.2\",
    \"app_name\": \"config-service\",
    \"app_repo\": \"http://rhel02.nostromo.io:3000/demo-admin/config-service\",
    \"target_branch\": \"main\",
    \"remediation_mode\": \"${MODE}\",
    \"lightwell_index\": \"http://rhel02.nostromo.io:8081/simple/pyyaml/\",
    \"resolved_by\": \"Project Lightwell\",
    \"resolution_date\": \"2026-07-30T15:00:00Z\",
    \"description\": \"Lightwell published pyyaml 6.0.2 resolving deserialization RCE (CVE-2026-52891)\",
    \"source\": \"Lightwell Package Registry\",
    \"remediation_note\": \"App dependency — requires CI/CD rebuild, not host-level patching\"
  }" | jq . 2>/dev/null || echo "(sent)"

echo ""
echo "Event fired (mode=${MODE}). Check EDA UI for rule activation."
echo ""
echo "Expected workflow: ${WORKFLOW_DESC}"
echo ""
echo "=== Remediation Flow Comparison ==="
echo ""
echo "  OS Package (Demo 3):        App Dependency (Demo 4):"
echo "  ─────────────────────        ──────────────────────────"
echo "  Lightwell → RHSA             Lightwell → PyPI index"
echo "  dnf update on host           Update version pin"
echo "  Package installed live        Rebuild app via CI/CD"
echo "  Verify via rpm -q            Deploy rebuilt artifact"
echo "                                Verify via health check"
echo ""
echo "  The fix is INSTALLED          The fix is BUILT INTO"
echo "  onto the system.              the application."
echo ""
