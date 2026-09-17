#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

eval "$(aws configure export-credentials --format env)"

npm run build

BUCKET=$(terraform -chdir=infra output -raw s3_bucket_name)
DIST_ID=$(terraform -chdir=infra output -raw cloudfront_distribution_id)

aws s3 sync dist/ "s3://$BUCKET" --delete
aws cloudfront create-invalidation --distribution-id "$DIST_ID" --paths "/*"

echo "Deploy listo: https://$(terraform -chdir=infra output -raw cloudfront_domain_name)"
