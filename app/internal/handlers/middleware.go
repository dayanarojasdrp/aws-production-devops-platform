package handlers

import (
	"context"
	"net/http"
	"time"
)

func (h *Handler) logging(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		started := time.Now()
		next.ServeHTTP(w, r)
		h.logger.Info("request completed",
			"method", r.Method,
			"path", r.URL.Path,
			"duration_ms", time.Since(started).Milliseconds(),
		)
	})
}

func contextWithTimeout(r *http.Request, timeout time.Duration) (context.Context, context.CancelFunc) {
	return context.WithTimeout(r.Context(), timeout)
}
