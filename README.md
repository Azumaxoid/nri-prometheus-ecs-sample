# nri-prometheus ECS連携デモ

このプロジェクトは、ECS（Fargate）にデプロイされたGoアプリケーションのPrometheusメトリクスを、nri-prometheus（独立サービス）経由でNew Relicに送信するデモ環境です。

## アーキテクチャ

```
Goアプリケーション (ECSサービス、ポート8080)
  └─ /metrics エンドポイント
      └─ Prometheus形式のメトリクス出力
          └─ (ネットワーク経由)
              └─ nri-prometheus (独立ECSサービス)
                  └─ スクレイピング (デフォルト30秒間隔)
                      └─ 複数のアプリケーションエンドポイントを監視可能
                          └─ New Relic Platform
```

### 特徴

- **独立サービス方式**: 1つのnri-prometheusサービスで複数のアプリケーションを監視可能
- **リソース効率**: nri-prometheusのインスタンスが1つで済む
- **管理性**: 設定変更が1箇所で済む
- **スケーラビリティ**: アプリケーションタスクの増減に影響されない

## 前提条件

- AWS CLIがインストール・設定済み（ローカルデプロイの場合）
- Dockerがインストール済み（ローカルデプロイの場合、mac arm64環境ではGitHub Actions推奨）
- New RelicアカウントとLicense Keyを取得済み
- ECSクラスタ（Fargate）が作成済み
- VPC、サブネット、セキュリティグループが設定済み
- **ECSタスク実行ロール（ecsTaskExecutionRole）が作成済み**（CloudWatch Logsへの書き込み権限が必要）

## セットアップ手順

### 方法A: GitHub Actionsを使用（推奨）

GitHub Actionsを使用すると、mac arm64環境でも問題なくlinux/amd64用のイメージをビルドできます。

#### 1. GitHub Secretsの設定

リポジトリのSettings > Secrets and variables > Actionsで以下のシークレットを設定：

- `AWS_ACCESS_KEY_ID`: AWSアクセスキーID
- `AWS_SECRET_ACCESS_KEY`: AWSシークレットアクセスキー
- `NEW_RELIC_LICENSE_KEY`: New Relic License Key（オプション、タスク定義で直接設定する場合は不要）

#### 2. ECSタスク実行ロールの作成（初回のみ）

FargateでCloudWatch Logsを使用するために、ECSタスク実行ロールが必要です。以下のコマンドで作成してください：

```bash
# タスク実行ロールの作成
aws iam create-role \
    --role-name ecsTaskExecutionRole \
    --assume-role-policy-document '{
      "Version": "2012-10-17",
      "Statement": [{
        "Effect": "Allow",
        "Principal": {"Service": "ecs-tasks.amazonaws.com"},
        "Action": "sts:AssumeRole"
      }]
    }'

# CloudWatch Logsへの書き込み権限を付与
aws iam attach-role-policy \
    --role-name ecsTaskExecutionRole \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy

# ECRへのアクセス権限を付与（既に含まれている場合もあります）
aws iam attach-role-policy \
    --role-name ecsTaskExecutionRole \
    --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
```

#### 3. ワークフローの環境変数を設定（オプション）

リポジトリのSettings > Secrets and variables > Actions > Variablesで以下を設定（または`.github/workflows/deploy.yml`の`env`セクションを直接編集）：

- `ECS_CLUSTER_NAME`: ECSクラスタ名（デフォルト: `demo-ecs-cluster`）
- `AWS_REGION`: AWSリージョン（デフォルト: `ap-northeast-1`）
- `ECS_TASK_EXECUTION_ROLE`: ECSタスク実行ロール名（デフォルト: `ecsTaskExecutionRole`）

#### 4. デプロイの実行

- `main`ブランチにプッシュすると自動的にデプロイが実行されます
- 手動実行する場合は、Actionsタブから`Build and Deploy to ECS`ワークフローを選択して`Run workflow`をクリック

#### 5. ECSサービスの作成（初回のみ）

GitHub Actionsはタスク定義を登録しますが、ECSサービスは作成しません。初回のみ、以下のコマンドでサービスを作成してください：

```bash
# アプリケーションサービスの作成
aws ecs create-service \
    --cluster <CLUSTER_NAME> \
    --service-name demo-app-service \
    --task-definition demo-app \
    --desired-count 1 \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[<SUBNET_ID>],securityGroups=[<SECURITY_GROUP_ID>],assignPublicIp=ENABLED}" \
    --region <AWS_REGION>

# nri-prometheusサービスの作成
aws ecs create-service \
    --cluster <CLUSTER_NAME> \
    --service-name nri-prometheus-service \
    --task-definition nri-prometheus \
    --desired-count 1 \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[<SUBNET_ID>],securityGroups=[<SECURITY_GROUP_ID>],assignPublicIp=ENABLED}" \
    --region <AWS_REGION>
```

### 方法B: ローカルからデプロイ

### 1. New Relic License Keyの準備

New Relic License Keyを取得し、以下のいずれかの方法で設定します：

#### 方法A: AWS Secrets Managerを使用（推奨）

```bash
aws secretsmanager create-secret \
    --name newrelic/license-key \
    --secret-string "YOUR_NEW_RELIC_LICENSE_KEY" \
    --region YOUR_REGION
```

#### 方法B: 環境変数で直接指定（デモ用）

`ecs/nri-prometheus-task-definition-simple.json`の`NRIA_LICENSE_KEY`環境変数を直接編集してください。

### 2. ECRリポジトリの作成

```bash
./scripts/setup-ecr.sh <AWS_REGION> <AWS_ACCOUNT_ID>
```

例:
```bash
./scripts/setup-ecr.sh us-east-1 123456789012
```

### 3. イメージのビルドとプッシュ

```bash
./scripts/build-and-push.sh <AWS_REGION> <AWS_ACCOUNT_ID>
```

例:
```bash
./scripts/build-and-push.sh us-east-1 123456789012
```

### 4. nri-prometheus設定ファイルの更新

`nri-prometheus/config.yml`を編集して、アプリケーションのメトリクスエンドポイントURLを設定します。

```yaml
scrape_configs:
  - job_name: "demo-app"
    static_configs:
      - targets:
          # アプリケーションの実際のエンドポイントに変更
          - "demo-app-service:8080"  # または ALB/NLB のエンドポイント
```

設定を変更した場合は、nri-prometheusイメージを再ビルド・再プッシュしてください。

### 5. ECSタスク定義の登録とデプロイ

```bash
./scripts/deploy.sh <AWS_REGION> <AWS_ACCOUNT_ID> <CLUSTER_NAME> [NEW_RELIC_LICENSE_KEY]
```

例:
```bash
./scripts/deploy.sh us-east-1 123456789012 demo-ecs-cluster
```

または、License Keyを直接指定する場合:
```bash
./scripts/deploy.sh us-east-1 123456789012 demo-ecs-cluster YOUR_NEW_RELIC_LICENSE_KEY
```

### 6. ECSサービスの作成

#### アプリケーションサービスの作成

```bash
aws ecs create-service \
    --cluster <CLUSTER_NAME> \
    --service-name demo-app-service \
    --task-definition demo-app \
    --desired-count 1 \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[<SUBNET_ID>],securityGroups=[<SECURITY_GROUP_ID>],assignPublicIp=ENABLED}" \
    --region <AWS_REGION>
```

#### nri-prometheusサービスの作成

```bash
aws ecs create-service \
    --cluster <CLUSTER_NAME> \
    --service-name nri-prometheus-service \
    --task-definition nri-prometheus \
    --desired-count 1 \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[<SUBNET_ID>],securityGroups=[<SECURITY_GROUP_ID>],assignPublicIp=ENABLED}" \
    --region <AWS_REGION>
```

**重要**: nri-prometheusのセキュリティグループで、アプリケーションサービスのポート8080へのアクセスを許可してください。

### 7. アプリケーションエンドポイントの確認

アプリケーションサービスが起動したら、タスクのプライベートIPアドレスまたはALBエンドポイントを確認し、`nri-prometheus/config.yml`の`targets`を更新します。

設定を更新したら、nri-prometheusイメージを再ビルド・再プッシュし、サービスを更新してください：

```bash
# イメージの再ビルド・プッシュ
./scripts/build-and-push.sh <AWS_REGION> <AWS_ACCOUNT_ID>

# サービスの強制新規デプロイ
aws ecs update-service \
    --cluster <CLUSTER_NAME> \
    --service nri-prometheus-service \
    --force-new-deployment \
    --region <AWS_REGION>
```

## 動作確認

### 1. アプリケーションの確認

アプリケーションの`/metrics`エンドポイントにアクセスして、Prometheusメトリクスが出力されていることを確認：

```bash
curl http://<APP_ENDPOINT>/metrics
```

以下のような出力が表示されるはずです：

```
# HELP http_requests_total Total number of HTTP requests
# TYPE http_requests_total counter
http_requests_total{endpoint="/",method="GET"} 1
```

### 2. CloudWatch Logsの確認

nri-prometheusサービスのログを確認：

```bash
aws logs tail /ecs/nri-prometheus --follow --region <AWS_REGION>
```

スクレイピングが成功している場合、以下のようなログが表示されます。

### 3. New Relicでの確認

New Relic UIで以下のNRQLクエリを実行して、メトリクスが表示されることを確認：

```sql
SELECT * FROM Metric WHERE metricName = 'http_requests_total' SINCE 1 hour ago
```

## トラブルシューティング

### nri-prometheusタスクがPendingのまま起動しない

1. **Secrets Managerのシークレットを確認**
   ```bash
   aws secretsmanager describe-secret \
       --secret-id "newrelic/ecs-demo-license-key" \
       --region <AWS_REGION>
   ```
   シークレットが存在しない場合は作成してください。

2. **タスク実行ロールにSecrets Managerへのアクセス権限があるか確認**
   ```bash
   # タスク実行ロールにSecrets Managerへのアクセス権限を付与
   aws iam attach-role-policy \
       --role-name ecsTaskExecutionRole \
       --policy-arn arn:aws:iam::aws:policy/SecretsManagerReadWrite
   ```
   または、より制限されたポリシーを作成して、特定のシークレットへのアクセスのみを許可することもできます。

3. **タスクの停止理由を確認**
   ```bash
   TASK_ARN=$(aws ecs list-tasks \
       --cluster <CLUSTER_NAME> \
       --service-name nri-prometheus-service \
       --region <AWS_REGION> \
       --query "taskArns[0]" \
       --output text)
   
   aws ecs describe-tasks \
       --cluster <CLUSTER_NAME> \
       --tasks $TASK_ARN \
       --region <AWS_REGION> \
       --query "tasks[0].[lastStatus,stoppedReason,containers[0].reason]" \
       --output table
   ```

4. **サービスのイベントを確認**
   ```bash
   aws ecs describe-services \
       --cluster <CLUSTER_NAME> \
       --services nri-prometheus-service \
       --region <AWS_REGION> \
       --query "services[0].events[:10]" \
       --output table
   ```

5. **CloudWatch Logsを確認**（タスクが起動している場合）
   ```bash
   aws logs tail /ecs/nri-prometheus --follow --region <AWS_REGION>
   ```

### メトリクスがNew Relicに表示されない

1. **nri-prometheusのログを確認**
   ```bash
   aws logs tail /ecs/nri-prometheus --follow --region <AWS_REGION>
   ```

2. **設定ファイルの確認**
   - `nri-prometheus/config.yml`の`targets`が正しいエンドポイントを指しているか
   - アプリケーションの`/metrics`エンドポイントにアクセスできるか

3. **セキュリティグループの確認**
   - nri-prometheusタスクからアプリケーションタスクのポート8080へのアクセスが許可されているか

4. **New Relic License Keyの確認**
   - License Keyが正しく設定されているか
   - Secrets Managerを使用している場合、タスク定義の`secrets`セクションが正しく設定されているか

### アプリケーションにアクセスできない

1. **タスクの状態を確認**
   ```bash
   aws ecs list-tasks --cluster <CLUSTER_NAME> --service-name demo-app-service --region <AWS_REGION>
   ```

2. **タスクのログを確認**
   ```bash
   aws logs tail /ecs/demo-app --follow --region <AWS_REGION>
   ```

3. **セキュリティグループの確認**
   - 必要なポート（8080）が開いているか

## ファイル構成

```
.
├── app/
│   ├── main.go              # Goアプリケーション
│   ├── go.mod               # Go依存関係
│   └── Dockerfile           # アプリケーション用Dockerfile
├── nri-prometheus/
│   ├── config.yml           # nri-prometheus設定ファイル
│   └── Dockerfile           # nri-prometheusカスタムイメージ用Dockerfile
├── ecs/
│   ├── app-task-definition.json                    # アプリケーション用タスク定義
│   ├── nri-prometheus-task-definition.json         # nri-prometheus用タスク定義（EFS使用）
│   └── nri-prometheus-task-definition-simple.json  # nri-prometheus用タスク定義（シンプル版）
├── scripts/
│   ├── setup-ecr.sh         # ECRリポジトリ作成スクリプト
│   ├── build-and-push.sh    # イメージビルド・プッシュスクリプト
│   └── deploy.sh            # ECSデプロイスクリプト
└── README.md                # このファイル
```

## カスタマイズ

### スクレイピング間隔の変更

`nri-prometheus/config.yml`の`scrape_interval`を変更：

```yaml
scrape_interval: 60s  # 60秒に変更（コスト削減）
```

### 複数のアプリケーションを監視

`nri-prometheus/config.yml`に複数の`scrape_configs`を追加：

```yaml
scrape_configs:
  - job_name: "demo-app-1"
    static_configs:
      - targets:
          - "app-1-service:8080"
  - job_name: "demo-app-2"
    static_configs:
      - targets:
          - "app-2-service:8080"
```

### メトリクスのフィルタリング

`nri-prometheus/config.yml`の`metric_relabel_configs`でフィルタリング：

```yaml
metric_relabel_configs:
  - source_labels: [__name__]
    regex: "http_requests_total|http_request_duration_seconds"
    action: keep  # これらのメトリクスのみ保持
```

## ライセンス

このプロジェクトはデモ目的で作成されています。

