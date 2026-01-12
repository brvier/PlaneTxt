package database

import (
	"database/sql"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"time"

	_ "github.com/mattn/go-sqlite3"
	"github.com/planovasaas/backend/internal/models"
)

type DB struct {
	*sql.DB
}

func Init(dbPath string) (*DB, error) {
	if err := os.MkdirAll(filepath.Dir(dbPath), 0755); err != nil {
		return nil, fmt.Errorf("failed to create database directory: %w", err)
	}

	db, err := sql.Open("sqlite3", dbPath)
	if err != nil {
		return nil, fmt.Errorf("failed to open database: %w", err)
	}

	if err := runMigrations(db); err != nil {
		return nil, fmt.Errorf("failed to run migrations: %w", err)
	}

	log.Printf("Database initialized at %s", dbPath)
	return &DB{db}, nil
}

func (db *DB) Close() error {
	return db.DB.Close()
}

func runMigrations(db *sql.DB) error {
	migrations := []struct {
		name string
		sql  string
	}{
		{
			name: "create_users_table",
			sql: `CREATE TABLE IF NOT EXISTS users (
				id TEXT PRIMARY KEY,
				email TEXT UNIQUE NOT NULL,
				username TEXT,
				password_hash TEXT NOT NULL,
				timezone TEXT,
				preferred_theme TEXT DEFAULT 'light',
				created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
				updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
			)`,
		},
		{
			name: "create_devices_table",
			sql: `CREATE TABLE IF NOT EXISTS devices (
				id TEXT PRIMARY KEY,
				user_id TEXT NOT NULL,
				device_name TEXT,
				platform TEXT,
				last_sync_at DATETIME,
				created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
				FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
			)`,
		},
		{
			name: "create_files_metadata_table",
			sql: `CREATE TABLE IF NOT EXISTS files_metadata (
				id TEXT PRIMARY KEY,
				user_id TEXT NOT NULL,
				file_type TEXT NOT NULL,
				file_path TEXT NOT NULL,
				filename TEXT NOT NULL,
				encrypted_checksum TEXT,
				file_size INTEGER,
				encrypted_at DATETIME,
				server_version INTEGER DEFAULT 0,
				deleted_at DATETIME,
				created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
				updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
				FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
			)`,
		},
		{
			name: "create_sync_log_table",
			sql: `CREATE TABLE IF NOT EXISTS sync_log (
				id TEXT PRIMARY KEY,
				device_id TEXT NOT NULL,
				action TEXT NOT NULL,
				records_count INTEGER,
				status TEXT,
				error_message TEXT,
				timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
				FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE CASCADE
			)`,
		},
		{
			name: "create_indexes",
			sql: `CREATE INDEX IF NOT EXISTS idx_files_user_id ON files_metadata(user_id);
				 CREATE INDEX IF NOT EXISTS idx_files_deleted_at ON files_metadata(deleted_at);
				 CREATE INDEX IF NOT EXISTS idx_devices_user_id ON devices(user_id);`,
		},
	}

	for _, migration := range migrations {
		if _, err := db.Exec(migration.sql); err != nil {
			log.Printf("Migration failed: %s - %v", migration.name, err)
			return err
		}
		log.Printf("Migration applied: %s", migration.name)
	}

	return nil
}

func (db *DB) CreateUser(user *models.User) error {
	query := `INSERT INTO users (id, email, username, password_hash, timezone, preferred_theme) VALUES (?, ?, ?, ?, ?, ?)`
	_, err := db.Exec(query, user.ID, user.Email, user.Username, user.PasswordHash, user.Timezone, user.PreferredTheme)
	return err
}

func (db *DB) GetUserByEmail(email string) (*models.User, error) {
	query := `SELECT id, email, username, password_hash, timezone, preferred_theme, created_at, updated_at FROM users WHERE email = ?`
	row := db.QueryRow(query, email)

	var user models.User
	err := row.Scan(&user.ID, &user.Email, &user.Username, &user.PasswordHash, &user.Timezone, &user.PreferredTheme, &user.CreatedAt, &user.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return &user, nil
}

func (db *DB) CreateDevice(device *models.Device) error {
	query := `INSERT INTO devices (id, user_id, device_name, platform, last_sync_at) VALUES (?, ?, ?, ?, ?)`
	_, err := db.Exec(query, device.ID, device.UserID, device.DeviceName, device.Platform, device.LastSyncAt)
	return err
}

func (db *DB) UpdateDeviceSync(deviceID string, lastSync time.Time) error {
	query := `UPDATE devices SET last_sync_at = ? WHERE id = ?`
	_, err := db.Exec(query, lastSync, deviceID)
	return err
}

func (db *DB) GetDevicesByUserID(userID string) ([]models.Device, error) {
	query := `SELECT id, user_id, device_name, platform, last_sync_at, created_at FROM devices WHERE user_id = ?`
	rows, err := db.Query(query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var devices []models.Device
	for rows.Next() {
		var device models.Device
		err := rows.Scan(&device.ID, &device.UserID, &device.DeviceName, &device.Platform, &device.LastSyncAt, &device.CreatedAt)
		if err != nil {
			return nil, err
		}
		devices = append(devices, device)
	}
	return devices, nil
}

func (db *DB) InsertFileMetadata(file *models.FileMetadata) error {
	query := `INSERT INTO files_metadata (id, user_id, file_type, file_path, filename, encrypted_checksum, file_size, encrypted_at, server_version) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`
	_, err := db.Exec(query, file.ID, file.UserID, file.FileType, file.FilePath, file.Filename, file.EncryptedChecksum, file.FileSize, file.EncryptedAt, file.ServerVersion)
	return err
}

func (db *DB) GetFileMetadata(id string) (*models.FileMetadata, error) {
	query := `SELECT id, user_id, file_type, file_path, filename, file_size, encrypted_at, server_version, deleted_at, created_at, updated_at FROM files_metadata WHERE id = ?`
	row := db.QueryRow(query, id)

	var file models.FileMetadata
	err := row.Scan(&file.ID, &file.UserID, &file.FileType, &file.FilePath, &file.Filename, &file.FileSize, &file.EncryptedAt, &file.ServerVersion, &file.DeletedAt, &file.CreatedAt, &file.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return &file, nil
}

func (db *DB) GetFilesSince(userID string, since time.Time) ([]models.FileMetadata, error) {
	query := `SELECT id, user_id, file_type, file_path, filename, file_size, encrypted_at, server_version, deleted_at, created_at, updated_at FROM files_metadata WHERE user_id = ? AND (updated_at > ? OR updated_at IS NULL) AND deleted_at IS NULL ORDER BY updated_at DESC`
	rows, err := db.Query(query, userID, since)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var files []models.FileMetadata
	for rows.Next() {
		var file models.FileMetadata
		err := rows.Scan(&file.ID, &file.UserID, &file.FileType, &file.FilePath, &file.Filename, &file.FileSize, &file.EncryptedAt, &file.ServerVersion, &file.DeletedAt, &file.CreatedAt, &file.UpdatedAt)
		if err != nil {
			return nil, err
		}
		files = append(files, file)
	}
	return files, nil
}

func (db *DB) LogSync(deviceID, action string, recordsCount int, status string, errorMsg string) error {
	query := `INSERT INTO sync_log (id, device_id, action, records_count, status, error_message) VALUES (?, ?, ?, ?, ?, ?)`
	_, err := db.Exec(query, generateUUID(), deviceID, action, recordsCount, status, errorMsg)
	return err
}

func generateUUID() string {
	return fmt.Sprintf("%d", time.Now().UnixNano())
}
