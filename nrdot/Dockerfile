FROM newrelic/nrdot-collector:latest

# 設定ファイルとentrypointをコピー（--chmodで実行権付与、RUN不要でUSER 10001問題を回避）
COPY config.yml /etc/otelcol/config.yaml
COPY --chmod=755 entrypoint.sh /entrypoint.sh

# entrypointでTASK_IDを設定してからcollectorを起動（configの host.name=${TASK_ID} 用）
ENTRYPOINT ["/entrypoint.sh"]
CMD ["--config", "/etc/otelcol/config.yaml"]
