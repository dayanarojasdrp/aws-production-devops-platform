package config

import (
	"net/url"
	"strings"
	"testing"
)

func TestLoadUsesSecureDefaults(t *testing.T) {
	setRequiredEnvironment(t)

	cfg, err := Load()
	if err != nil {
		t.Fatalf("Load() returned an unexpected error: %v", err)
	}
	if cfg.HTTPPort != "8080" || cfg.DBPort != "5432" {
		t.Fatalf("Load() returned unexpected port defaults: HTTP=%s DB=%s", cfg.HTTPPort, cfg.DBPort)
	}
	if cfg.DBSSLMode != "require" {
		t.Fatalf("Load() DBSSLMode = %q, want require", cfg.DBSSLMode)
	}
}

func TestLoadRejectsMissingRequiredVariable(t *testing.T) {
	setRequiredEnvironment(t)
	t.Setenv("DB_PASSWORD", "")

	_, err := Load()
	if err == nil || !strings.Contains(err.Error(), "DB_PASSWORD") {
		t.Fatalf("Load() error = %v, want an error naming DB_PASSWORD", err)
	}
}

func TestLoadRejectsInvalidPort(t *testing.T) {
	setRequiredEnvironment(t)
	t.Setenv("HTTP_PORT", "70000")

	_, err := Load()
	if err == nil || !strings.Contains(err.Error(), "HTTP_PORT") {
		t.Fatalf("Load() error = %v, want an error naming HTTP_PORT", err)
	}
}

func TestLoadRejectsUnsupportedSSLMode(t *testing.T) {
	setRequiredEnvironment(t)
	t.Setenv("DB_SSLMODE", "insecure")

	_, err := Load()
	if err == nil || !strings.Contains(err.Error(), "DB_SSLMODE") {
		t.Fatalf("Load() error = %v, want an error naming DB_SSLMODE", err)
	}
}

func TestDatabaseURLEscapesCredentialsAndUsesConfiguredSSLMode(t *testing.T) {
	cfg := Config{
		DBHost:     "database.internal",
		DBPort:     "5432",
		DBName:     "platform",
		DBUser:     "api-user",
		DBPassword: "p@ss/word",
		DBSSLMode:  "verify-full",
	}

	parsed, err := url.Parse(cfg.DatabaseURL())
	if err != nil {
		t.Fatalf("DatabaseURL() produced an invalid URL: %v", err)
	}
	password, _ := parsed.User.Password()
	if parsed.User.Username() != cfg.DBUser || password != cfg.DBPassword {
		t.Fatalf("DatabaseURL() did not preserve encoded credentials")
	}
	if parsed.Query().Get("sslmode") != "verify-full" {
		t.Fatalf("DatabaseURL() sslmode = %q, want verify-full", parsed.Query().Get("sslmode"))
	}
}

func setRequiredEnvironment(t *testing.T) {
	t.Helper()
	for name, value := range map[string]string{
		"HTTP_PORT":   "",
		"DB_HOST":     "postgres",
		"DB_PORT":     "",
		"DB_NAME":     "platform",
		"DB_USER":     "platform",
		"DB_PASSWORD": "local-password",
		"DB_SSLMODE":  "",
	} {
		t.Setenv(name, value)
	}
}
