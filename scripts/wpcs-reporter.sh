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

# Step 1 - Wait for new run to appear
echo "⏳ Waiting for GitHub Actions to start..."
sleep 15

echo "⏳ Fetching latest workflow run..."

API_RESPONSE=$(curl -s \
  -H "Authorization: token $TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/$USERNAME/$REPO/actions/runs?per_page=1")

RUN_ID=$(echo "$API_RESPONSE" | jq -r '.workflow_runs[0].id')
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
echo "⏳ Downloading WPCS results..."

ARTIFACT_RESPONSE=$(curl -s \
  -H "Authorization: token $TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/$USERNAME/$REPO/actions/runs/$RUN_ID/artifacts")

ARTIFACT_URL=$(echo "$ARTIFACT_RESPONSE" | jq -r '.artifacts[0].archive_download_url')

echo "   Artifact URL: $ARTIFACT_URL"

curl -s -L \
  -H "Authorization: token $TOKEN" \
  -o wpcs-results.zip \
  "$ARTIFACT_URL"

unzip -o wpcs-results.zip -d wpcs-output > /dev/null 2>&1
echo "✅ Results downloaded!"
echo ""

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