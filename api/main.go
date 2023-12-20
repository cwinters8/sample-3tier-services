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
	var (
		userKey = "DB_USER"
		passKey = "DB_PASS"
		hostKey = "DB_HOST"
		portKey = "DB_PORT"
		nameKey = "DB_NAME"
	)
	env, err := getEnv(userKey, passKey, hostKey, portKey, nameKey)
	if err != nil {
		return err
	}
	dbURL := fmt.Sprintf(
		"postgresql://%s:%s@%s:%s/%s",
		env[userKey], env[passKey], env[hostKey], env[portKey], env[nameKey],
	)
	fmt.Printf("database url: %s\n", dbURL)
	db, err := pgx.Connect(ctx, dbURL)
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

func getEnv(keys ...string) (map[string]string, error) {
	result := map[string]string{}
	missing := []string{}
	for _, key := range keys {
		value := os.Getenv(key)
		if len(value) == 0 {
			missing = append(missing, key)
		} else {
			result[key] = value
		}
	}
	if len(missing) > 0 {
		return nil, fmt.Errorf("missing environment variables: %v", missing)
	}
	return result, nil
}
