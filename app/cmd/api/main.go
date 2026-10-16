package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/dayanarojasdrp/aws-production-devops-platform/app/internal/config"
	"github.com/dayanarojasdrp/aws-production-devops-platform/app/internal/database"
	"github.com/dayanarojasdrp/aws-production-devops-platform/app/internal/handlers"
)

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))

	cfg, err := config.Load()
	if err != nil {
		logger.Error("invalid configuration", "error", err)
		os.Exit(1)
	}

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	db, err := database.New(ctx, cfg.DatabaseURL())
	if err != nil {
		logger.Error("cannot configure database pool", "error", err)
		os.Exit(1)
	}
	defer db.Close()

	startupCtx, cancelStartup := context.WithTimeout(ctx, 10*time.Second)
	if err := db.Ready(startupCtx); err != nil {
		cancelStartup()
		logger.Error("database startup check failed", "error", err)
		os.Exit(1)
	}
	cancelStartup()
	logger.Info("database startup check passed")

	api := handlers.New(db, logger)
	server := &http.Server{
		Addr:              ":" + cfg.HTTPPort,
		Handler:           api.Routes(),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      10 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	go func() {
		logger.Info("HTTP server started", "address", server.Addr)
		if err := server.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			logger.Error("HTTP server failed", "error", err)
			stop()
		}
	}()

	<-ctx.Done()
	logger.Info("shutting down")

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := server.Shutdown(shutdownCtx); err != nil {
		logger.Error("graceful shutdown failed", "error", err)
	}
}
