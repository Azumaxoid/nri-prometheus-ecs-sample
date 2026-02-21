FROM newrelic/nrdot-collector:latest

# 設定ファイルとentrypointをコピー
COPY config.yml /etc/otelcol/config.yaml
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# entrypointでTASK_IDを設定してからcollectorを起動（configの host.name=${TASK_ID} 用）
ENTRYPOINT ["/entrypoint.sh"]
CMD ["--config", "/etc/otelcol/config.yaml"]
