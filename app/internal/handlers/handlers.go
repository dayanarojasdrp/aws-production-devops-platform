package handlers

import (
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"net/mail"
	"strings"
	"time"

	"github.com/your-org/aws-production-devops-platform/app/internal/database"
)

type Handler struct {
	db     *database.Database
	logger *slog.Logger
}

func New(db *database.Database, logger *slog.Logger) *Handler {
	return &Handler{db: db, logger: logger}
}

func (h *Handler) Routes() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", h.health)
	mux.HandleFunc("GET /readyz", h.ready)
	mux.HandleFunc("GET /users", h.listUsers)
	mux.HandleFunc("POST /users", h.createUser)
	return h.logging(mux)
}

func (h *Handler) health(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (h *Handler) ready(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := contextWithTimeout(r, 2*time.Second)
	defer cancel()

	if err := h.db.Ready(ctx); err != nil {
		h.logger.Warn("database readiness check failed", "error", err)
		writeJSON(w, http.StatusServiceUnavailable, map[string]string{
			"status": "not_ready", "database": "disconnected",
		})
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "ready", "database": "connected"})
}

func (h *Handler) listUsers(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := contextWithTimeout(r, 5*time.Second)
	defer cancel()

	users, err := h.db.ListUsers(ctx)
	if err != nil {
		h.internalError(w, "cannot list users", err)
		return
	}
	writeJSON(w, http.StatusOK, users)
}

func (h *Handler) createUser(w http.ResponseWriter, r *http.Request) {
	var input struct {
		Name  string `json:"name"`
		Email string `json:"email"`
	}
	decoder := json.NewDecoder(http.MaxBytesReader(w, r.Body, 1<<20))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&input); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid JSON body"})
		return
	}

	input.Name = strings.TrimSpace(input.Name)
	input.Email = strings.TrimSpace(strings.ToLower(input.Email))
	if input.Name == "" || !validEmail(input.Email) {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "name and a valid email are required"})
		return
	}

	ctx, cancel := contextWithTimeout(r, 5*time.Second)
	defer cancel()
	user, err := h.db.CreateUser(ctx, input.Name, input.Email)
	if errors.Is(err, database.ErrEmailExists) {
		writeJSON(w, http.StatusConflict, map[string]string{"error": "email already exists"})
		return
	}
	if err != nil {
		h.internalError(w, "cannot create user", err)
		return
	}
	writeJSON(w, http.StatusCreated, user)
}

func (h *Handler) internalError(w http.ResponseWriter, message string, err error) {
	h.logger.Error(message, "error", err)
	writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal server error"})
}

func validEmail(value string) bool {
	address, err := mail.ParseAddress(value)
	return err == nil && address.Address == value
}

func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(value)
}
