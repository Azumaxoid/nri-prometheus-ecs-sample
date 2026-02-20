FROM newrelic/nri-prometheus:latest

# 設定ファイルをコピー
# nri-prometheusは /etc/newrelic-infra/integrations.d/ または /etc/nri-prometheus/ を確認します
# 両方のパスにコピーして確実に読み込まれるようにします
COPY config.yml /etc/newrelic-infra/integrations.d/nri-prometheus-config.yml
COPY config.yml /etc/nri-prometheus/config.yml
