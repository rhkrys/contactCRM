#!/usr/bin/env bash
# Deploy the ContactCRM web dashboard to sales.awesomeblackbusiness.com
# Usage: ./deploy.sh
set -euo pipefail

BUCKET="sales.awesomeblackbusiness.com"
DISTRIBUTION_ID="E2SWY5YFIV3RV9"
PROFILE="${AWS_PROFILE:-svc-ai-cowork-mcp}"
REGION="us-east-1"

cd "$(dirname "$0")"

echo "→ Syncing site to s3://$BUCKET (cache 5 min)…"
aws s3 sync . "s3://$BUCKET/" \
  --exclude "README.md" \
  --exclude "deploy.sh" \
  --exclude "config.js" \
  --cache-control "public, max-age=300" \
  --delete \
  --profile "$PROFILE" --region "$REGION"

# config.js carries the Google Client ID — keep it uncached so edits apply immediately.
echo "→ Uploading config.js (no-cache)…"
aws s3 cp config.js "s3://$BUCKET/config.js" \
  --cache-control "no-cache" \
  --profile "$PROFILE" --region "$REGION"

echo "→ Invalidating CloudFront cache…"
aws cloudfront create-invalidation \
  --distribution-id "$DISTRIBUTION_ID" \
  --paths "/*" \
  --profile "$PROFILE" \
  --query "Invalidation.{Id:Id,Status:Status}" --output table

echo "✓ Deployed. Live at https://$BUCKET (allow ~1 min for the invalidation to complete)."
