#!/bin/bash

# TODO: read from config
STACK_NAME="static-website-dev" # <-- Change this to your stack name
REGION="us-east-1"        # <-- Change this to your region

echo "Initiating drift detection for stack: $STACK_NAME in region: $REGION"
DRIFT_ID=$(aws cloudformation detect-stack-drift --stack-name "$STACK_NAME" --region "$REGION" --query "StackDriftDetectionId" --output text)

if [ -z "$DRIFT_ID" ]; then
  echo "Error: Could not initiate drift detection."
  exit 1
fi

echo "Drift detection initiated. ID: $DRIFT_ID"
echo "Waiting for drift detection to complete..."

STATUS="DETECTION_IN_PROGRESS"
while [ "$STATUS" == "DETECTION_IN_PROGRESS" ]; do
  sleep 10 # Wait for 10 seconds before checking again
  RESPONSE=$(aws cloudformation describe-stack-drift-detection-status \
    --stack-drift-detection-id "$DRIFT_ID" \
    --region "$REGION" \
    --query "[DetectionStatus, StackDriftStatus]" --output text)

  STATUS=$(echo "$RESPONSE" | awk '{print $1}')
  STACK_DRIFT_STATUS=$(echo "$RESPONSE" | awk '{print $2}')

  echo "Current status: $STATUS, Stack Drift Status: ${STACK_DRIFT_STATUS:-N/A}" # N/A for when still IN_PROGRESS

  if [ "$STATUS" == "DETECTION_FAILED" ]; then
    echo "Drift detection failed!"
    exit 1
  fi
done

echo "Drift detection complete. Final Stack Drift Status: $STACK_DRIFT_STATUS"

if [ "$STACK_DRIFT_STATUS" == "DRIFTED" ]; then
  echo "Stack has drifted! Listing drifted resources:"
  aws cloudformation describe-stack-resource-drifts --stack-name "$STACK_NAME" --region "$REGION" | jq
else
  echo "Stack is IN_SYNC (no drift detected)."
fi