package main

import (
	"log"

	"github.com/planovasaas/backend/internal/config"
	"github.com/planovasaas/backend/internal/database"
	"github.com/planovasaas/backend/internal/handlers/auth"
	"github.com/planovasaas/backend/internal/handlers/dashboard"
	"github.com/planovasaas/backend/internal/handlers/files"
	"github.com/planovasaas/backend/internal/handlers/sync"
	"net/http"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("Failed to load config: %v", err)
	}

	db, err := database.Init(cfg.DatabasePath)
	if err != nil {
		log.Fatalf("Failed to init database: %v", err)
	}
	defer db.Close()

	mux := http.NewServeMux()

	mux.HandleFunc("/api/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"status":"ok"}`))
	})

	mux.HandleFunc("/api/auth/register", auth.Register(db))
	mux.HandleFunc("/api/auth/login", auth.Login(db))
	mux.HandleFunc("/api/auth/logout", auth.Logout)
	mux.HandleFunc("/api/sync/register-device", auth.RegisterDevice(db))

	mux.HandleFunc("/api/sync/pull", sync.Pull(db))
	mux.HandleFunc("/api/sync/push", sync.Push(db))

	mux.HandleFunc("/api/files/upload", files.UploadFile(db, cfg.StoragePath))
	mux.HandleFunc("/api/files/list", files.ListFiles(db, cfg.StoragePath))
	mux.HandleFunc("/api/files/download/", files.DownloadFile(db, cfg.StoragePath))
	mux.HandleFunc("/api/files/", files.DeleteFile(db, cfg.StoragePath))

	mux.HandleFunc("/dashboard", dashboard.HTML(db))

	mux.Handle("/static/", http.StripPrefix(http.FileServer(http.Dir("./frontend/static")))

	api := mux.PathPrefix("/api").Subrouter()

	api.Use(func(next http.Handler) http.Handler {
		http.StripPrefix("/api").Use(func(next http.Handler) http.HandlerFunc {
			return func(w http.ResponseWriter, r *http.Request) {
				log.Printf("%s %s %s", r.Method, r.URL.Path)
				next.ServeHTTP(w, r)
			}
		})

	log.Printf("Server starting on %s", cfg.Port)
	log.Fatal(mux.ListenAndServe(cfg.Port))
}
