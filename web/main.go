package main

import (
	"encoding/json"
	"fmt"
	"html/template"
	"io"
	"log"
	"net/http"
	"os"
	"time"
)

type status struct {
	Message   string    `json:"message"`
	Timestamp time.Time `json:"timestamp"`
}

func getStatus(api string) (*status, error) {
	resp, err := http.Get(api)
	if err != nil {
		return nil, fmt.Errorf("failed to get status from api: %w", err)
	}
	b, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response body: %w", err)
	}
	var s status
	if err := json.Unmarshal(b, &s); err != nil {
		return nil, fmt.Errorf("failed to unmarshal status: %w", err)
	}
	return &s, nil
}

func setup() error {
	api := os.Getenv("API_HOST")
	if len(api) == 0 {
		return fmt.Errorf("API_HOST environment variable not set")
	}
	t, err := template.New("index.html").ParseFiles("./index.html")
	if err != nil {
		return fmt.Errorf("failed to parse index.html: %w", err)
	}
	mux := http.NewServeMux()
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		s, err := getStatus(api)
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		if err := t.Execute(w, s); err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
	})
	return http.ListenAndServe(fmt.Sprintf(":%s", os.Getenv("PORT")), mux)
}

func main() {
	if err := setup(); err != nil {
		log.Fatal(err)
	}
}
