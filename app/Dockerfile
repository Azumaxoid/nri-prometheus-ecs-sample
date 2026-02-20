# ビルドステージ
FROM golang:1.21-alpine AS builder

WORKDIR /app

# go.modをコピー
COPY go.mod ./

# ソースコードをコピー
COPY main.go ./

# 依存関係をダウンロードして整理（main.goのインポートに基づく）
RUN go mod download && go mod tidy

# バイナリをビルド（linux/amd64用、シンプルなビルドフラグ）
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o app .

# 実行ステージ
FROM alpine:latest

RUN apk --no-cache add ca-certificates

WORKDIR /root/

# ビルドしたバイナリをコピー
COPY --from=builder /app/app .

# ポート8080を公開
EXPOSE 8080

# アプリケーションを起動
CMD ["./app"]

