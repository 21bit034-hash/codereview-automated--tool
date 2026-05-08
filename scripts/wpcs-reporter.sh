#!/bin/bash

# ================================
#  WPCS Terminal Reporter
# ================================

USERNAME=$GITHUB_USERNAME
REPO=$GITHUB_REPO
TOKEN=$GITHUB_TOKEN

echo ""
echo "================================"
echo "   WPCS Terminal Reporter"
echo "================================"
echo ""

# Step 1 - Wait for new run to appear then get its ID
echo "⏳ Waiting for GitHub Actions to start..."
sleep 20

echo "⏳ Fetching latest workflow run..."

# Retry up to 5 times to get the newest run
for i in 1 2 3 4 5; do
  API_RESPONSE=$(curl -s \
    -H "Authorization: token $TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/$USERNAME/$REPO/actions/runs?per_page=1&event=push")

  RUN_ID=$(echo "$API_RESPONSE" | jq -r '.workflow_runs[0].id')
  RUN_STATUS=$(echo "$API_RESPONSE" | jq -r '.workflow_runs[0].status')

  echo "   Attempt $i - Run ID: $RUN_ID - Status: $RUN_STATUS"

  if [ "$RUN_STATUS" != "completed" ]; then
    echo "   New run found! Monitoring..."
    break
  fi

  echo "   Waiting for new run to appear..."
  sleep 10
done

echo "✅ Workflow Run ID: $RUN_ID"
echo ""

# Step 2 - Wait for workflow to complete
echo "⏳ Waiting for GitHub Actions to complete..."

while true; do
  RUN_RESPONSE=$(curl -s \
    -H "Authorization: token $TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/$USERNAME/$REPO/actions/runs/$RUN_ID")

  STATUS=$(echo "$RUN_RESPONSE" | jq -r '.status')
  CONCLUSION=$(echo "$RUN_RESPONSE" | jq -r '.conclusion')

  echo "   Status: $STATUS"

  if [ "$STATUS" = "completed" ]; then
    echo ""
    echo "✅ GitHub Actions Completed!"
    echo "   Result: $CONCLUSION"
    break
  fi

  echo "   Waiting 10 seconds..."
  sleep 10
done

echo ""

# Step 3 - Download artifact
# Wait for artifact to be ready
echo "⏳ Waiting for artifact to be ready..."
sleep 5

ARTIFACT_RESPONSE=$(curl -s \
  -H "Authorization: token $TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/$USERNAME/$REPO/actions/runs/$RUN_ID/artifacts")

ARTIFACT_COUNT=$(echo "$ARTIFACT_RESPONSE" | jq -r '.total_count')
echo "   Found $ARTIFACT_COUNT artifact(s) for this run"

ARTIFACT_URL=$(echo "$ARTIFACT_RESPONSE" | jq -r '.artifacts[0].archive_download_url')
ARTIFACT_NAME=$(echo "$ARTIFACT_RESPONSE" | jq -r '.artifacts[0].name')
echo "   Artifact Name: $ARTIFACT_NAME"

# Step 4 - Display results
echo "================================"
echo "      WPCS CHECK RESULTS        "
echo "================================"
echo ""

if [ -f wpcs-output/wpcs-results.txt ]; then
  ERRORS=$(grep -c "ERROR" wpcs-output/wpcs-results.txt 2>/dev/null || true)
WARNINGS=$(grep -c "WARNING" wpcs-output/wpcs-results.txt 2>/dev/null || true)
ERRORS=${ERRORS:-0}
WARNINGS=${WARNINGS:-0}

  cat wpcs-output/wpcs-results.txt

  echo ""
  echo "================================"
  echo " Total Errors   : $ERRORS"
  echo " Total Warnings : $WARNINGS"

  if [ "$ERRORS" -gt 0 ]; then
    echo " Status         : ❌ FAILED"
    echo "================================"
    echo " Fix errors and push again!"
  else
    echo " Status         : ✅ PASSED"
    echo "================================"
    echo " Great work! No errors found!"
  fi
else
  echo "⚠️  No results file found"
fi

echo ""

# Cleanup
rm -rf wpcs-results.zip wpcs-output