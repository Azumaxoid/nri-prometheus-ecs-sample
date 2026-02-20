#!/bin/bash

# ECRリポジトリ作成スクリプト
# 使用方法: ./setup-ecr.sh <AWS_REGION> <AWS_ACCOUNT_ID>

set -e

if [ $# -lt 2 ]; then
    echo "使用方法: $0 <AWS_REGION> <AWS_ACCOUNT_ID>"
    echo "例: $0 us-east-1 123456789012"
    exit 1
fi

AWS_REGION=$1
AWS_ACCOUNT_ID=$2

echo "AWS Region: $AWS_REGION"
echo "AWS Account ID: $AWS_ACCOUNT_ID"

# ECRリポジトリの作成
REPOSITORIES=("demo-app" "nri-prometheus")

for REPO in "${REPOSITORIES[@]}"; do
    echo "Creating ECR repository: $REPO"
    
    # リポジトリが存在するか確認
    if aws ecr describe-repositories --repository-names "$REPO" --region "$AWS_REGION" 2>/dev/null; then
        echo "Repository $REPO already exists, skipping..."
    else
        aws ecr create-repository \
            --repository-name "$REPO" \
            --region "$AWS_REGION" \
            --image-scanning-configuration scanOnPush=true \
            --encryption-configuration encryptionType=AES256
        echo "Repository $REPO created successfully"
    fi
done

echo ""
echo "ECR repositories setup completed!"
echo ""
echo "Next steps:"
echo "1. Build and push images using: ./scripts/build-and-push.sh $AWS_REGION $AWS_ACCOUNT_ID"

