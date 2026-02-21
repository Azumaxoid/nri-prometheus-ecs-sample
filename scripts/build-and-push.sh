#!/bin/bash

# イメージビルドとECRプッシュスクリプト
# 使用方法: ./build-and-push.sh <AWS_REGION> <AWS_ACCOUNT_ID>

set -e

if [ $# -lt 2 ]; then
    echo "使用方法: $0 <AWS_REGION> <AWS_ACCOUNT_ID>"
    echo "例: $0 us-east-1 123456789012"
    exit 1
fi

AWS_REGION=$1
AWS_ACCOUNT_ID=$2
ECR_BASE="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

echo "AWS Region: $AWS_REGION"
echo "AWS Account ID: $AWS_ACCOUNT_ID"
echo "ECR Base: $ECR_BASE"

# ECRにログイン
echo "Logging in to ECR..."
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_BASE"

# アプリケーションイメージのビルドとプッシュ
echo ""
echo "Building demo-app image (linux/amd64)..."
cd "$(dirname "$0")/../app"

# buildxを使用してマルチプラットフォームビルド（より安定）
if docker buildx version > /dev/null 2>&1; then
    echo "Using Docker buildx for cross-platform build..."
    docker buildx build --platform linux/amd64 --load -t demo-app:latest .
else
    echo "Using standard docker build..."
    DOCKER_BUILDKIT=1 docker build --platform linux/amd64 -t demo-app:latest .
fi

docker tag demo-app:latest "${ECR_BASE}/demo-app:latest"
echo "Pushing demo-app image..."
docker push "${ECR_BASE}/demo-app:latest"
echo "demo-app image pushed successfully"

# NRDOTカスタムイメージのビルドとプッシュ（設定ファイルを含む）
echo ""
echo "Building NRDOT custom image with config (linux/amd64)..."
cd "$(dirname "$0")/../nrdot"

# buildxを使用してマルチプラットフォームビルド（より安定）
if docker buildx version > /dev/null 2>&1; then
    echo "Using Docker buildx for cross-platform build..."
    docker buildx build --platform linux/amd64 --load -t nrdot:latest .
else
    echo "Using standard docker build..."
    DOCKER_BUILDKIT=1 docker build --platform linux/amd64 -t nrdot:latest .
fi

docker tag nrdot:latest "${ECR_BASE}/nrdot:latest"
echo "Pushing NRDOT image..."
docker push "${ECR_BASE}/nrdot:latest"
echo "NRDOT image pushed successfully"

echo ""
echo "All images built and pushed successfully!"
echo ""
echo "Image URIs:"
echo "  - ${ECR_BASE}/demo-app:latest"
echo "  - ${ECR_BASE}/nrdot:latest (NRDOT with config)"

