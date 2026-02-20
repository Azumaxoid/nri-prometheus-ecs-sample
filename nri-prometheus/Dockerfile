FROM newrelic/nrdot:latest

# 設定ファイルをコピー
# NRDOT (OpenTelemetry Collector) は /etc/otelcol/config.yaml を確認します
COPY config.yml /etc/otelcol/config.yaml

# デフォルトのコマンドでNRDOTを起動
CMD ["--config", "/etc/otelcol/config.yaml"]
