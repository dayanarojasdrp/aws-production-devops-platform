package config

import (
	"fmt"
	"net"
	"net/url"
	"os"
	"strconv"
)

type Config struct {
	HTTPPort   string
	DBHost     string
	DBPort     string
	DBName     string
	DBUser     string
	DBPassword string
	DBSSLMode  string
}

func Load() (Config, error) {
	cfg := Config{
		HTTPPort:   valueOrDefault("HTTP_PORT", "8080"),
		DBHost:     os.Getenv("DB_HOST"),
		DBPort:     valueOrDefault("DB_PORT", "5432"),
		DBName:     os.Getenv("DB_NAME"),
		DBUser:     os.Getenv("DB_USER"),
		DBPassword: os.Getenv("DB_PASSWORD"),
		DBSSLMode:  valueOrDefault("DB_SSLMODE", "require"),
	}

	for name, value := range map[string]string{
		"DB_HOST": cfg.DBHost, "DB_NAME": cfg.DBName,
		"DB_USER": cfg.DBUser, "DB_PASSWORD": cfg.DBPassword,
	} {
		if value == "" {
			return Config{}, fmt.Errorf("environment variable %s is required", name)
		}
	}

	if err := validatePort("HTTP_PORT", cfg.HTTPPort); err != nil {
		return Config{}, err
	}
	if err := validatePort("DB_PORT", cfg.DBPort); err != nil {
		return Config{}, err
	}
	if !validSSLMode(cfg.DBSSLMode) {
		return Config{}, fmt.Errorf("environment variable DB_SSLMODE has unsupported value %q", cfg.DBSSLMode)
	}

	return cfg, nil
}

func (c Config) DatabaseURL() string {
	u := &url.URL{
		Scheme: "postgres",
		User:   url.UserPassword(c.DBUser, c.DBPassword),
		Host:   net.JoinHostPort(c.DBHost, c.DBPort),
		Path:   c.DBName,
	}
	query := u.Query()
	query.Set("sslmode", c.DBSSLMode)
	u.RawQuery = query.Encode()
	return u.String()
}

func validatePort(name, value string) error {
	port, err := strconv.Atoi(value)
	if err != nil || port < 1 || port > 65535 {
		return fmt.Errorf("environment variable %s must be a port between 1 and 65535", name)
	}
	return nil
}

func validSSLMode(value string) bool {
	switch value {
	case "disable", "allow", "prefer", "require", "verify-ca", "verify-full":
		return true
	default:
		return false
	}
}

func valueOrDefault(name, fallback string) string {
	if value := os.Getenv(name); value != "" {
		return value
	}
	return fallback
}
