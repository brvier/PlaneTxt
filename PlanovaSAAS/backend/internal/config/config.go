package config

import (
	"log"
	"os"
)

type Config struct {
	Port         string
	DatabasePath string
	StoragePath  string
}

func Load() (*Config, error) {
	cfg := &Config{
		Port:         ":8090",
		DatabasePath: "data/planova.db",
		StoragePath:  "storage/users",
	}

	if port := os.Getenv("PORT"); port != "" {
		cfg.Port = ":" + port
	}

	if dbPath := os.Getenv("DB_PATH"); dbPath != "" {
		cfg.DatabasePath = dbPath
	}

	if storagePath := os.Getenv("STORAGE_PATH"); storagePath != "" {
		cfg.StoragePath = storagePath
	}

	log.Printf("Config loaded: Port=%s, DB=%s, Storage=%s", cfg.Port, cfg.DatabasePath, cfg.StoragePath)
	return cfg, nil
}
