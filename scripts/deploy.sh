#!/bin/bash

# ECSデプロイスクリプト
# 使用方法: ./deploy.sh <AWS_REGION> <AWS_ACCOUNT_ID> <CLUSTER_NAME> [SUBNET_ID] [SECURITY_GROUP_ID] [NEW_RELIC_LICENSE_KEY]

set -e

if [ $# -lt 3 ]; then
    echo "使用方法: $0 <AWS_REGION> <AWS_ACCOUNT_ID> <CLUSTER_NAME> [SUBNET_ID] [SECURITY_GROUP_ID] [NEW_RELIC_LICENSE_KEY]"
    echo "例: $0 us-east-1 123456789012 demo-ecs-cluster subnet-xxxxx sg-xxxxx"
    echo ""
    echo "SUBNET_IDとSECURITY_GROUP_IDが指定されない場合、自動で取得または作成を試みます"
    exit 1
fi

AWS_REGION=$1
AWS_ACCOUNT_ID=$2
CLUSTER_NAME=$3
SUBNET_ID=${4:-""}
SECURITY_GROUP_ID=${5:-""}
NEW_RELIC_LICENSE_KEY=${6:-""}

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
EXECUTION_ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/ecsTaskExecutionRole"
sed -i.bak "s|YOUR_ACCOUNT_ID.dkr.ecr.YOUR_REGION.amazonaws.com|${ECR_BASE}|g" "$APP_TASK_DEF"
sed -i.bak "s|YOUR_REGION|${AWS_REGION}|g" "$APP_TASK_DEF"
sed -i.bak "s|arn:aws:iam::YOUR_ACCOUNT_ID:role/ecsTaskExecutionRole|${EXECUTION_ROLE_ARN}|g" "$APP_TASK_DEF"

# nri-prometheusタスク定義の更新（シンプル版を使用）
NRI_TASK_DEF="${PROJECT_DIR}/ecs/nri-prometheus-task-definition-simple.json"
sed -i.bak "s|YOUR_ACCOUNT_ID.dkr.ecr.YOUR_REGION.amazonaws.com|${ECR_BASE}|g" "$NRI_TASK_DEF"
sed -i.bak "s|YOUR_REGION|${AWS_REGION}|g" "$NRI_TASK_DEF"
sed -i.bak "s|YOUR_ACCOUNT_ID|${AWS_ACCOUNT_ID}|g" "$NRI_TASK_DEF"
sed -i.bak "s|arn:aws:iam::YOUR_ACCOUNT_ID:role/ecsTaskExecutionRole|${EXECUTION_ROLE_ARN}|g" "$NRI_TASK_DEF"
sed -i.bak "s|arn:aws:secretsmanager:YOUR_REGION:YOUR_ACCOUNT_ID:secret:newrelic/ecs-demo-license-key|arn:aws:secretsmanager:${AWS_REGION}:${AWS_ACCOUNT_ID}:secret:newrelic/ecs-demo-license-key|g" "$NRI_TASK_DEF"

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

# サブネットIDとセキュリティグループIDの取得または作成
echo ""
echo "Setting up network configuration..."

if [ -z "$SUBNET_ID" ]; then
    echo "Subnet ID not provided. Attempting to find a suitable subnet..."
    SUBNET_ID=$(aws ec2 describe-subnets \
        --region "$AWS_REGION" \
        --filters "Name=default-for-az,Values=true" \
        --query "Subnets[0].SubnetId" \
        --output text 2>/dev/null || \
    aws ec2 describe-subnets \
        --region "$AWS_REGION" \
        --query "Subnets[0].SubnetId" \
        --output text)
    
    if [ -z "$SUBNET_ID" ] || [ "$SUBNET_ID" == "None" ]; then
        echo "Error: Could not find a subnet. Please provide SUBNET_ID as an argument."
        exit 1
    fi
    echo "Using subnet: $SUBNET_ID"
fi

if [ -z "$SECURITY_GROUP_ID" ]; then
    echo "Security Group ID not provided. Attempting to create one..."
    VPC_ID=$(aws ec2 describe-subnets \
        --subnet-ids "$SUBNET_ID" \
        --region "$AWS_REGION" \
        --query "Subnets[0].VpcId" \
        --output text)
    
    SECURITY_GROUP_ID=$(aws ec2 create-security-group \
        --group-name "ecs-demo-${CLUSTER_NAME}-sg" \
        --description "Security group for ECS demo cluster ${CLUSTER_NAME}" \
        --vpc-id "$VPC_ID" \
        --region "$AWS_REGION" \
        --query 'GroupId' \
        --output text 2>/dev/null || \
    aws ec2 describe-security-groups \
        --filters "Name=group-name,Values=ecs-demo-${CLUSTER_NAME}-sg" "Name=vpc-id,Values=$VPC_ID" \
        --region "$AWS_REGION" \
        --query "SecurityGroups[0].GroupId" \
        --output text)
    
    if [ -z "$SECURITY_GROUP_ID" ] || [ "$SECURITY_GROUP_ID" == "None" ]; then
        echo "Error: Could not create or find security group."
        exit 1
    fi
    
    # セキュリティグループにルールを追加（アプリケーション用：ポート8080を許可）
    echo "Adding security group rules..."
    aws ec2 authorize-security-group-ingress \
        --group-id "$SECURITY_GROUP_ID" \
        --protocol tcp \
        --port 8080 \
        --cidr 0.0.0.0/0 \
        --region "$AWS_REGION" 2>/dev/null || echo "Port 8080 rule may already exist"
    
    # アウトバウンドトラフィックを許可（デフォルトで許可されている場合が多い）
    aws ec2 authorize-security-group-egress \
        --group-id "$SECURITY_GROUP_ID" \
        --protocol -1 \
        --cidr 0.0.0.0/0 \
        --region "$AWS_REGION" 2>/dev/null || echo "Egress rule may already exist"
    
    echo "Using security group: $SECURITY_GROUP_ID"
fi

# ECSサービスの作成または更新
echo ""
echo "Creating or updating ECS services..."

# アプリケーションサービスの作成または更新
if aws ecs describe-services \
    --cluster "$CLUSTER_NAME" \
    --services demo-app-service \
    --region "$AWS_REGION" \
    --query 'services[0].status' \
    --output text 2>/dev/null | grep -q ACTIVE; then
    echo "Updating demo-app-service..."
    aws ecs update-service \
        --cluster "$CLUSTER_NAME" \
        --service demo-app-service \
        --task-definition demo-app \
        --force-new-deployment \
        --region "$AWS_REGION" > /dev/null
    echo "demo-app-service updated"
else
    echo "Creating demo-app-service..."
    aws ecs create-service \
        --cluster "$CLUSTER_NAME" \
        --service-name demo-app-service \
        --task-definition demo-app \
        --desired-count 1 \
        --launch-type FARGATE \
        --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_ID],securityGroups=[$SECURITY_GROUP_ID],assignPublicIp=ENABLED}" \
        --region "$AWS_REGION" > /dev/null
    echo "demo-app-service created"
fi

# nri-prometheusサービスの作成または更新
if aws ecs describe-services \
    --cluster "$CLUSTER_NAME" \
    --services nri-prometheus-service \
    --region "$AWS_REGION" \
    --query 'services[0].status' \
    --output text 2>/dev/null | grep -q ACTIVE; then
    echo "Updating nri-prometheus-service..."
    aws ecs update-service \
        --cluster "$CLUSTER_NAME" \
        --service nri-prometheus-service \
        --task-definition nri-prometheus \
        --force-new-deployment \
        --region "$AWS_REGION" > /dev/null
    echo "nri-prometheus-service updated"
else
    echo "Creating nri-prometheus-service..."
    aws ecs create-service \
        --cluster "$CLUSTER_NAME" \
        --service-name nri-prometheus-service \
        --task-definition nri-prometheus \
        --desired-count 1 \
        --launch-type FARGATE \
        --network-configuration "awsvpcConfiguration={subnets=[$SUBNET_ID],securityGroups=[$SECURITY_GROUP_ID],assignPublicIp=ENABLED}" \
        --region "$AWS_REGION" > /dev/null
    echo "nri-prometheus-service created"
fi

echo ""
echo "Deployment completed!"
echo ""
echo "Services are starting up. You can check the status with:"
echo "  aws ecs describe-services --cluster $CLUSTER_NAME --services demo-app-service nri-prometheus-service --region $AWS_REGION"
echo ""
echo "To get the application URL, wait for tasks to start and run:"
echo "  TASK_ARN=\$(aws ecs list-tasks --cluster $CLUSTER_NAME --service-name demo-app-service --region $AWS_REGION --query 'taskArns[0]' --output text)"
echo "  ENI_ID=\$(aws ecs describe-tasks --cluster $CLUSTER_NAME --tasks \$TASK_ARN --region $AWS_REGION --query 'tasks[0].attachments[0].details[?name==\`networkInterfaceId\`].value' --output text)"
echo "  PUBLIC_IP=\$(aws ec2 describe-network-interfaces --network-interface-ids \$ENI_ID --region $AWS_REGION --query 'NetworkInterfaces[0].Association.PublicIp' --output text)"
echo "  echo \"App URL: http://\${PUBLIC_IP}:8080\""
echo "  echo \"Metrics URL: http://\${PUBLIC_IP}:8080/metrics\""
echo ""
echo "Note: Update nri-prometheus/config.yml with the actual app service endpoint and rebuild the image if needed."

