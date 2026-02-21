# ベースイメージに /bin/sh がないため、shell を用意するステージ
FROM alpine:3.19 AS shell
RUN cp /bin/sh /sh

FROM newrelic/nrdot-collector:latest

# 設定ファイルとentrypointをコピー
COPY config.yml /etc/otelcol/config.yaml
COPY --chmod=755 entrypoint.sh /entrypoint.sh
# entrypoint 実行用の shell（nrdot ベースイメージに /bin/sh がないため）
COPY --from=shell /sh /bin/sh

# entrypointでTASK_IDを設定してからcollectorを起動（configの host.name=${TASK_ID} 用）
ENTRYPOINT ["/bin/sh", "/entrypoint.sh"]
CMD ["--config", "/etc/otelcol/config.yaml"]
