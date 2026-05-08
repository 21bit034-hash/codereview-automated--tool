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

# Step 1 - Read last run ID saved by hook before push
LAST_RUN_ID=$(cat /tmp/last_wpcs_run_id 2>/dev/null || echo "0")
echo "   Last Run ID before push: $LAST_RUN_ID"
echo ""

# Wait for NEW run to appear
echo "⏳ Waiting for new GitHub Actions run to start..."

RUN_ID=""
ATTEMPTS=0

while true; do
  ATTEMPTS=$((ATTEMPTS + 1))
  sleep 8

  API_RESPONSE=$(curl -s \
    -H "Authorization: token $TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/$USERNAME/$REPO/actions/runs?per_page=1&event=push")

  NEW_RUN_ID=$(echo "$API_RESPONSE" | jq -r '.workflow_runs[0].id')
  NEW_STATUS=$(echo "$API_RESPONSE" | jq -r '.workflow_runs[0].status')

  echo "   Attempt $ATTEMPTS - Run ID: $NEW_RUN_ID - Status: $NEW_STATUS"

  if [ "$NEW_RUN_ID" != "$LAST_RUN_ID" ]; then
    RUN_ID=$NEW_RUN_ID
    echo ""
    echo "✅ New workflow run detected!"
    break
  fi

  if [ "$ATTEMPTS" -ge 15 ]; then
    echo "⚠️  Timeout. Using latest run."
    RUN_ID=$NEW_RUN_ID
    break
  fi
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
echo "⏳ Downloading WPCS results..."
sleep 5

ARTIFACT_RESPONSE=$(curl -s \
  -H "Authorization: token $TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/$USERNAME/$REPO/actions/runs/$RUN_ID/artifacts")

ARTIFACT_COUNT=$(echo "$ARTIFACT_RESPONSE" | jq -r '.total_count')
ARTIFACT_URL=$(echo "$ARTIFACT_RESPONSE" | jq -r '.artifacts[0].archive_download_url')
ARTIFACT_NAME=$(echo "$ARTIFACT_RESPONSE" | jq -r '.artifacts[0].name')

echo "   Found $ARTIFACT_COUNT artifact(s)"
echo "   Artifact Name: $ARTIFACT_NAME"

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

  ERRORS=$(grep -c "| ERROR" wpcs-output/wpcs-results.txt 2>/dev/null || echo "0")
  WARNINGS=$(grep -c "| WARNING" wpcs-output/wpcs-results.txt 2>/dev/null || echo "0")
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