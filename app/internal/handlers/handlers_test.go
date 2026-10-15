package handlers

import (
	"bytes"
	"context"
	"errors"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/dayanarojasdrp/aws-production-devops-platform/app/internal/database"
	"github.com/dayanarojasdrp/aws-production-devops-platform/app/internal/models"
)

type fakeStore struct {
	readyErr  error
	users     []models.User
	listErr   error
	created   models.User
	createErr error
	createHit bool
	name      string
	email     string
}

func (store *fakeStore) Ready(context.Context) error {
	return store.readyErr
}

func (store *fakeStore) ListUsers(context.Context) ([]models.User, error) {
	return store.users, store.listErr
}

func (store *fakeStore) CreateUser(_ context.Context, name, email string) (models.User, error) {
	store.createHit = true
	store.name = name
	store.email = email
	if store.createErr != nil {
		return models.User{}, store.createErr
	}
	created := store.created
	created.Name = name
	created.Email = email
	return created, nil
}

func TestHealthDoesNotDependOnDatabase(t *testing.T) {
	store := &fakeStore{readyErr: errors.New("database unavailable")}
	response := performRequest(t, store, http.MethodGet, "/healthz", nil)

	if response.Code != http.StatusOK {
		t.Fatalf("GET /healthz status = %d, want %d", response.Code, http.StatusOK)
	}
}

func TestReadinessReportsDatabaseFailure(t *testing.T) {
	store := &fakeStore{readyErr: errors.New("database unavailable")}
	response := performRequest(t, store, http.MethodGet, "/readyz", nil)

	if response.Code != http.StatusServiceUnavailable {
		t.Fatalf("GET /readyz status = %d, want %d", response.Code, http.StatusServiceUnavailable)
	}
}

func TestCreateUserNormalizesInput(t *testing.T) {
	store := &fakeStore{created: models.User{ID: 7, CreatedAt: time.Unix(0, 0).UTC()}}
	body := bytes.NewBufferString(`{"name":"  Dayana  ","email":"DAYANA@EXAMPLE.COM"}`)
	response := performRequest(t, store, http.MethodPost, "/users", body)

	if response.Code != http.StatusCreated {
		t.Fatalf("POST /users status = %d, want %d; body=%s", response.Code, http.StatusCreated, response.Body.String())
	}
	if !store.createHit || store.name != "Dayana" || store.email != "dayana@example.com" {
		t.Fatalf("POST /users did not pass normalized values to the store: name=%q email=%q", store.name, store.email)
	}
	if !bytes.Contains(response.Body.Bytes(), []byte(`"name":"Dayana"`)) ||
		!bytes.Contains(response.Body.Bytes(), []byte(`"email":"dayana@example.com"`)) {
		t.Fatalf("POST /users returned unexpected body: %s", response.Body.String())
	}
}

func TestCreateUserRejectsMultipleJSONObjects(t *testing.T) {
	store := &fakeStore{}
	body := bytes.NewBufferString(`{"name":"A","email":"a@example.com"} {"name":"B","email":"b@example.com"}`)
	response := performRequest(t, store, http.MethodPost, "/users", body)

	if response.Code != http.StatusBadRequest {
		t.Fatalf("POST /users status = %d, want %d", response.Code, http.StatusBadRequest)
	}
	if store.createHit {
		t.Fatal("POST /users called the store for an invalid body")
	}
}

func TestCreateUserMapsDuplicateEmailToConflict(t *testing.T) {
	store := &fakeStore{createErr: database.ErrEmailExists}
	body := bytes.NewBufferString(`{"name":"Dayana","email":"dayana@example.com"}`)
	response := performRequest(t, store, http.MethodPost, "/users", body)

	if response.Code != http.StatusConflict {
		t.Fatalf("POST /users status = %d, want %d", response.Code, http.StatusConflict)
	}
}

func performRequest(t *testing.T, store Store, method, target string, body io.Reader) *httptest.ResponseRecorder {
	t.Helper()
	request := httptest.NewRequest(method, target, body)
	if body != nil {
		request.Header.Set("Content-Type", "application/json")
	}
	response := httptest.NewRecorder()
	logger := slog.New(slog.NewTextHandler(io.Discard, nil))
	New(store, logger).Routes().ServeHTTP(response, request)
	return response
}
