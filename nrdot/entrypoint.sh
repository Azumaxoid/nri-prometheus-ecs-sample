#!/bin/sh

# ECSタスクメタデータエンドポイントからタスクIDを取得
# ECS_CONTAINER_METADATA_URI_V4は自動的に設定される環境変数
if [ -n "$ECS_CONTAINER_METADATA_URI_V4" ]; then
  # タスクメタデータエンドポイントからタスクARNを取得
  METADATA_URL="${ECS_CONTAINER_METADATA_URI_V4}/task"
  
  # wgetまたはcurlを使用してメタデータを取得
  if command -v wget >/dev/null 2>&1; then
    TASK_ARN=$(wget -qO- "$METADATA_URL" 2>/dev/null | grep -o '"TaskARN":"[^"]*"' | sed 's/.*"TaskARN":"\([^"]*\)".*/\1/' || echo "")
  elif command -v curl >/dev/null 2>&1; then
    TASK_ARN=$(curl -s "$METADATA_URL" 2>/dev/null | grep -o '"TaskARN":"[^"]*"' | sed 's/.*"TaskARN":"\([^"]*\)".*/\1/' || echo "")
  fi
  
  if [ -n "$TASK_ARN" ]; then
    # タスクARNからタスクID（最後の部分）を抽出
    # 例: arn:aws:ecs:region:account:task/cluster-name/task-id -> task-id
    TASK_ID=$(echo "$TASK_ARN" | awk -F'/' '{print $NF}')
    export TASK_ID
    echo "Setting TASK_ID for host.name: $TASK_ID"
  else
    echo "Warning: Could not retrieve task ID from metadata endpoint"
  fi
else
  # ローカル環境やdocker-compose環境のフォールバック（configの ${TASK_ID:-unknown} 用）
  if [ -z "$TASK_ID" ]; then
    export TASK_ID="local-$(hostname)"
    echo "Using fallback TASK_ID: $TASK_ID"
  fi
fi

# NRDOT (OpenTelemetry Collector) を実行
exec "$@"

