FROM newrelic/nri-prometheus:latest

# 設定ディレクトリを作成
RUN mkdir -p /etc/nri-prometheus

# 設定ファイルをコピー（nri-prometheusが期待するパス）
COPY config.yml /etc/nri-prometheus/config.yml
