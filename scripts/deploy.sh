#!/bin/bash

# ECSデプロイスクリプト
# 使用方法: ./deploy.sh <AWS_REGION> <AWS_ACCOUNT_ID> <CLUSTER_NAME> [NEW_RELIC_LICENSE_KEY]

set -e

if [ $# -lt 3 ]; then
    echo "使用方法: $0 <AWS_REGION> <AWS_ACCOUNT_ID> <CLUSTER_NAME> [NEW_RELIC_LICENSE_KEY]"
    echo "例: $0 us-east-1 123456789012 demo-ecs-cluster"
    exit 1
fi

AWS_REGION=$1
AWS_ACCOUNT_ID=$2
CLUSTER_NAME=$3
NEW_RELIC_LICENSE_KEY=${4:-""}

ECR_BASE="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "AWS Region: $AWS_REGION"
echo "AWS Account ID: $AWS_ACCOUNT_ID"
echo "Cluster Name: $CLUSTER_NAME"

# タスク定義ファイルのパスを更新
echo ""
echo "Updating task definitions with ECR image URIs..."

# アプリケーションタスク定義の更新
APP_TASK_DEF="${PROJECT_DIR}/ecs/app-task-definition.json"
sed -i.bak "s|YOUR_ACCOUNT_ID.dkr.ecr.YOUR_REGION.amazonaws.com|${ECR_BASE}|g" "$APP_TASK_DEF"
sed -i.bak "s|YOUR_REGION|${AWS_REGION}|g" "$APP_TASK_DEF"

# nri-prometheusタスク定義の更新（シンプル版を使用）
NRI_TASK_DEF="${PROJECT_DIR}/ecs/nri-prometheus-task-definition-simple.json"
sed -i.bak "s|YOUR_ACCOUNT_ID.dkr.ecr.YOUR_REGION.amazonaws.com|${ECR_BASE}|g" "$NRI_TASK_DEF"
sed -i.bak "s|YOUR_REGION|${AWS_REGION}|g" "$NRI_TASK_DEF"
sed -i.bak "s|YOUR_ACCOUNT_ID|${AWS_ACCOUNT_ID}|g" "$NRI_TASK_DEF"

if [ -n "$NEW_RELIC_LICENSE_KEY" ]; then
    # 環境変数で直接指定する場合（デモ用）
    sed -i.bak "s|YOUR_NEW_RELIC_LICENSE_KEY|${NEW_RELIC_LICENSE_KEY}|g" "$NRI_TASK_DEF"
    echo "New Relic License Key set in task definition"
else
    echo "Warning: New Relic License Key not provided. Please update the task definition manually or use AWS Secrets Manager."
fi

# CloudWatch Logsグループの作成
echo ""
echo "Creating CloudWatch Logs groups..."
aws logs create-log-group --log-group-name "/ecs/demo-app" --region "$AWS_REGION" 2>/dev/null || echo "Log group /ecs/demo-app already exists"
aws logs create-log-group --log-group-name "/ecs/nri-prometheus" --region "$AWS_REGION" 2>/dev/null || echo "Log group /ecs/nri-prometheus already exists"

# タスク定義の登録
echo ""
echo "Registering task definitions..."

# アプリケーションタスク定義
echo "Registering demo-app task definition..."
aws ecs register-task-definition \
    --cli-input-json "file://${APP_TASK_DEF}" \
    --region "$AWS_REGION" > /dev/null
echo "demo-app task definition registered"

# nri-prometheusタスク定義
echo "Registering nri-prometheus task definition..."
aws ecs register-task-definition \
    --cli-input-json "file://${NRI_TASK_DEF}" \
    --region "$AWS_REGION" > /dev/null
echo "nri-prometheus task definition registered"

# バックアップファイルの削除
rm -f "${APP_TASK_DEF}.bak" "${NRI_TASK_DEF}.bak"

echo ""
echo "Deployment completed!"
echo ""
echo "Next steps:"
echo "1. Create ECS services or run tasks manually:"
echo "   - App service: aws ecs create-service --cluster $CLUSTER_NAME --service-name demo-app-service --task-definition demo-app --desired-count 1 --launch-type FARGATE --network-configuration 'awsvpcConfiguration={subnets=[subnet-xxx],securityGroups=[sg-xxx],assignPublicIp=ENABLED}' --region $AWS_REGION"
echo "   - nri-prometheus service: aws ecs create-service --cluster $CLUSTER_NAME --service-name nri-prometheus-service --task-definition nri-prometheus --desired-count 1 --launch-type FARGATE --network-configuration 'awsvpcConfiguration={subnets=[subnet-xxx],securityGroups=[sg-xxx],assignPublicIp=ENABLED}' --region $AWS_REGION"
echo ""
echo "2. Update nri-prometheus config.yml with the actual app service endpoint"
echo "3. Rebuild and push nri-prometheus image if config changed"

