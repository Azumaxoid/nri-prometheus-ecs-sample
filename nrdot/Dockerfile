FROM newrelic/nrdot-collector:latest

# 設定ファイルをコピー
COPY config.yml /etc/otelcol/config.yaml

CMD ["--config", "/etc/otelcol/config.yaml"]
