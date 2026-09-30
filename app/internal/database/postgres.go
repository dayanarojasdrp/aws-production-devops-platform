package database

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/your-org/aws-production-devops-platform/app/internal/models"
)

var ErrEmailExists = errors.New("email already exists")

type Database struct {
	pool *pgxpool.Pool
}

func New(ctx context.Context, databaseURL string) (*Database, error) {
	config, err := pgxpool.ParseConfig(databaseURL)
	if err != nil {
		return nil, err
	}
	config.MaxConns = 10
	config.MinConns = 1
	config.MaxConnLifetime = time.Hour
	config.MaxConnIdleTime = 30 * time.Minute

	pool, err := pgxpool.NewWithConfig(ctx, config)
	if err != nil {
		return nil, err
	}
	return &Database{pool: pool}, nil
}

func (d *Database) Close() {
	d.pool.Close()
}

func (d *Database) Ready(ctx context.Context) error {
	if err := d.pool.Ping(ctx); err != nil {
		return err
	}
	return d.ensureSchema(ctx)
}

func (d *Database) ensureSchema(ctx context.Context) error {
	const query = `
		CREATE TABLE IF NOT EXISTS users (
			id BIGSERIAL PRIMARY KEY,
			name TEXT NOT NULL,
			email TEXT NOT NULL UNIQUE,
			created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
		)`
	_, err := d.pool.Exec(ctx, query)
	return err
}

func (d *Database) ListUsers(ctx context.Context) ([]models.User, error) {
	if err := d.ensureSchema(ctx); err != nil {
		return nil, err
	}

	rows, err := d.pool.Query(ctx, `SELECT id, name, email, created_at FROM users ORDER BY id`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	users, err := pgx.CollectRows(rows, pgx.RowToStructByName[models.User])
	if err != nil {
		return nil, err
	}
	return users, nil
}

func (d *Database) CreateUser(ctx context.Context, name, email string) (models.User, error) {
	if err := d.ensureSchema(ctx); err != nil {
		return models.User{}, err
	}

	var user models.User
	err := d.pool.QueryRow(ctx,
		`INSERT INTO users (name, email) VALUES ($1, $2) RETURNING id, name, email, created_at`,
		name, email,
	).Scan(&user.ID, &user.Name, &user.Email, &user.CreatedAt)
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			return models.User{}, ErrEmailExists
		}
		return models.User{}, err
	}
	return user, nil
}
