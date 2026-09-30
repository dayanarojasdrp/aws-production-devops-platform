package config

import (
	"fmt"
	"net/url"
	"os"
)

type Config struct {
	HTTPPort   string
	DBHost     string
	DBPort     string
	DBName     string
	DBUser     string
	DBPassword string
}

func Load() (Config, error) {
	cfg := Config{
		HTTPPort:   valueOrDefault("HTTP_PORT", "8080"),
		DBHost:     os.Getenv("DB_HOST"),
		DBPort:     valueOrDefault("DB_PORT", "5432"),
		DBName:     os.Getenv("DB_NAME"),
		DBUser:     os.Getenv("DB_USER"),
		DBPassword: os.Getenv("DB_PASSWORD"),
	}

	for name, value := range map[string]string{
		"DB_HOST": cfg.DBHost, "DB_NAME": cfg.DBName,
		"DB_USER": cfg.DBUser, "DB_PASSWORD": cfg.DBPassword,
	} {
		if value == "" {
			return Config{}, fmt.Errorf("environment variable %s is required", name)
		}
	}

	return cfg, nil
}

func (c Config) DatabaseURL() string {
	u := &url.URL{
		Scheme: "postgres",
		User:   url.UserPassword(c.DBUser, c.DBPassword),
		Host:   c.DBHost + ":" + c.DBPort,
		Path:   c.DBName,
	}
	query := u.Query()
	query.Set("sslmode", "disable")
	u.RawQuery = query.Encode()
	return u.String()
}

func valueOrDefault(name, fallback string) string {
	if value := os.Getenv(name); value != "" {
		return value
	}
	return fallback
}
