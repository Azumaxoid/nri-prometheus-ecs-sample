package main

import (
	"fmt"
	"log"
	"net/http"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
	httpRequestsTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "http_requests_total",
			Help: "Total number of HTTP requests",
		},
		[]string{"method", "endpoint"},
	)
)

func init() {
	prometheus.MustRegister(httpRequestsTotal)
}

func main() {
	// メトリクスエンドポイント
	http.Handle("/metrics", promhttp.Handler())

	// サンプルエンドポイント
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		httpRequestsTotal.WithLabelValues(r.Method, r.URL.Path).Inc()
		w.WriteHeader(http.StatusOK)
		fmt.Fprintf(w, "Hello from Prometheus demo app!\n")
		fmt.Fprintf(w, "Visit /metrics to see Prometheus metrics\n")
	})

	// ヘルスチェックエンドポイント
	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		fmt.Fprintf(w, "OK\n")
	})

	port := ":8080"
	log.Printf("Server starting on port %s", port)
	log.Printf("Metrics available at http://localhost%s/metrics", port)
	if err := http.ListenAndServe(port, nil); err != nil {
		log.Fatal(err)
	}
}

