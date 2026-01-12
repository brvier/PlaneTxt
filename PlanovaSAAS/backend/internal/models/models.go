package models

import "time"

type User struct {
	ID             string    `json:"id" db:"id"`
	Email          string    `json:"email" db:"email"`
	Username       string    `json:"username" db:"username"`
	PasswordHash   string    `json:"-" db:"password_hash"`
	Timezone       string    `json:"timezone" db:"timezone"`
	PreferredTheme string    `json:"preferredTheme" db:"preferred_theme"`
	CreatedAt      time.Time `json:"createdAt" db:"created_at"`
	UpdatedAt      time.Time `json:"updatedAt" db:"updated_at"`
}

type Device struct {
	ID         string     `json:"id" db:"id"`
	UserID     string     `json:"userId" db:"user_id"`
	DeviceName string     `json:"deviceName" db:"device_name"`
	Platform   string     `json:"platform" db:"platform"`
	LastSyncAt *time.Time `json:"lastSyncAt" db:"last_sync_at"`
	CreatedAt  time.Time  `json:"createdAt" db:"created_at"`
}

type FileMetadata struct {
	ID                string     `json:"id" db:"id"`
	UserID            string     `json:"userId" db:"user_id"`
	FileType          string     `json:"fileType" db:"file_type"`
	FilePath          string     `json:"filePath" db:"file_path"`
	Filename          string     `json:"filename" db:"filename"`
	EncryptedChecksum string     `json:"-" db:"encrypted_checksum"`
	FileSize          int64      `json:"fileSize" db:"file_size"`
	EncryptedAt       time.Time  `json:"encryptedAt" db:"encrypted_at"`
	ServerVersion     int        `json:"serverVersion" db:"server_version"`
	DeletedAt         *time.Time `json:"deletedAt" db:"deleted_at"`
	CreatedAt         time.Time  `json:"createdAt" db:"created_at"`
	UpdatedAt         time.Time  `json:"updatedAt" db:"updated_at"`
}

type SyncLog struct {
	ID           string    `json:"id" db:"id"`
	DeviceID     string    `json:"deviceId" db:"device_id"`
	Action       string    `json:"action" db:"action"`
	RecordsCount int       `json:"recordsCount" db:"records_count"`
	Status       string    `json:"status" db:"status"`
	ErrorMessage string    `json:"errorMessage" db:"error_message"`
	Timestamp    time.Time `json:"timestamp" db:"timestamp"`
}
