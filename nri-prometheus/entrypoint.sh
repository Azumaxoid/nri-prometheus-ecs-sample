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
    export NRIA_HOSTNAME="$TASK_ID"
    echo "Setting NRIA_HOSTNAME to task ID: $TASK_ID"
  else
    echo "Warning: Could not retrieve task ID from metadata endpoint"
  fi
else
  # ローカル環境やdocker-compose環境の場合のフォールバック
  if [ -z "$NRIA_HOSTNAME" ]; then
    export NRIA_HOSTNAME="local-$(hostname)"
    echo "Using fallback hostname: $NRIA_HOSTNAME"
  fi
fi

# nri-prometheusを実行
exec "$@"

