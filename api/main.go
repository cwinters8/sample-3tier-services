package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/jackc/pgx/v5"
)

func getTimestamp(ctx context.Context, db *pgx.Conn) (time.Time, error) {
	var t time.Time
	row := db.QueryRow(ctx, `SELECT now() AS time`)
	if err := row.Scan(&t); err != nil {
		return time.Time{}, fmt.Errorf("failed to select timestamp from db: %w", err)
	}
	return t, nil
}

func setup() error {
	ctx := context.Background()
	dbCfg, err := pgx.ParseConfig(fmt.Sprintf(
		"postgres://%s@%s:%s/%s",
		os.Getenv("DB_USER"),
		os.Getenv("DB_HOST"),
		os.Getenv("DB_PORT"),
		os.Getenv("DB_NAME"),
	))
	if err != nil {
		return fmt.Errorf("failed to parse db config: %w", err)
	}
	dbCfg.Password = os.Getenv("DB_PASS")
	db, err := pgx.ConnectConfig(ctx, dbCfg)
	if err != nil {
		return fmt.Errorf("failed to connect to db: %w", err)
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		t, err := getTimestamp(ctx, db)
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		msg, err := json.Marshal(struct {
			Message   string    `json:"message"`
			Timestamp time.Time `json:"timestamp"`
		}{
			Message:   "Hello, world!",
			Timestamp: t,
		})
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		w.Write(msg)
	})
	return http.ListenAndServe(fmt.Sprintf(":%s", os.Getenv("PORT")), mux)
}

func main() {
	if err := setup(); err != nil {
		log.Fatal(err)
	}
}
