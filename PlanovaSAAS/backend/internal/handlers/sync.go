package handlers

import (
	"encoding/json"
	"log"
	"net/http"
	"time"

	"github.com/planovasaas/backend/internal/database"
	"github.com/planovasaas/backend/internal/models"
)

type SyncPullRequest struct {
	DeviceID   string     `json:"deviceId"`
	LastSyncAt *time.Time `json:"lastSyncAt"`
}

type SyncPullResponse struct {
	Files      []database.FileMetadata `json:"files"`
	ServerTime time.Time               `json:"serverTime"`
}

type FilePushData struct {
	ID            string    `json:"id"`
	Content       string    `json:"content"` // Encrypted content
	Checksum      string    `json:"checksum"`
	EncryptedAt   time.Time `json:"encryptedAt"`
	ServerVersion int       `json:"serverVersion"`
}

type SyncPushRequest struct {
	DeviceID string         `json:"deviceId"`
	Files    []FilePushData `json:"files"`
}

type SyncPushResponse struct {
	Status     string    `json:"status"`
	ServerTime time.Time `json:"serverTime"`
}

type Conflict struct {
	ID            string `json:"id"`
	Type          string `json:"type"`
	LocalVersion  int    `json:"localVersion"`
	ServerVersion int    `json:"serverVersion"`
	MergedVersion int    `json:"mergedVersion"`
	Resolved      bool   `json:"resolved"`
	Strategy      string `json:"strategy"`
}

func SyncPull(db *database.DB) func(http.ResponseWriter, *http.Request) {
	userID := r.Header.Get("X-User-ID")
	if userID == "" {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	var req SyncPullRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	log.Printf("Pull request from device %s, last sync: %v", req.DeviceID, req.LastSyncAt)

	files, err := db.GetFilesSince(userID, time.Time{})
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	response := SyncPullResponse{
		Files:      files,
		ServerTime: time.Now(),
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(response)
}

func SyncPush(db *database.DB) func(http.ResponseWriter, *http.Request) {
	userID := r.Header.Get("X-User-ID")
	if userID == "" {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	var req SyncPushRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	log.Printf("Push request from device %s with %d files", req.DeviceID, len(req.Files))

	conflicts := []Conflict{}
	updatedFiles := 0

	for _, fileData := range req.Files {
		existing, err := db.GetFileMetadata(fileData.ID)
		if err != nil {
			log.Printf("Error getting file metadata: %v", err)
			continue
		}

		if existing != nil {
			if fileData.ServerVersion > existing.ServerVersion {
				newFile := &database.FileMetadata{
					ID:                existing.ID,
					UserID:            existing.UserID,
					FileType:          existing.FileType,
					FilePath:          existing.FilePath,
					Filename:          existing.Filename,
					FileSize:          fileData.FileSize,
					EncryptedChecksum: fileData.Checksum,
					EncryptedAt:       fileData.EncryptedAt,
					ServerVersion:     fileData.ServerVersion,
					DeletedAt:         existing.DeletedAt,
					CreatedAt:         existing.CreatedAt,
					UpdatedAt:         time.Now(),
				}

				if err := db.UpdateFileMetadata(newFile); err != nil {
					log.Printf("Error updating file: %v", err)
				}

				updatedFiles++
			} else if existing.ServerVersion > fileData.ServerVersion {
				conflicts = append(conflicts, Conflict{
					ID:            fileData.ID,
					Type:          "server_version_wins",
					LocalVersion:  fileData.ServerVersion,
					ServerVersion: existing.ServerVersion,
					MergedVersion: existing.ServerVersion,
					Resolved:      false,
					Strategy:      "last_version_wins",
				})
			} else {
				log.Printf("Same version for file %s, no conflict", fileData.ID)
			}
		} else {
			newFile := &database.FileMetadata{
				ID:                fileData.ID,
				UserID:            userID,
				FileType:          "daily",
				FilePath:          "dailies/" + fileData.ID,
				Filename:          fileData.ID + ".md",
				FileSize:          fileData.FileSize,
				EncryptedChecksum: fileData.Checksum,
				EncryptedAt:       fileData.EncryptedAt,
				ServerVersion:     fileData.ServerVersion,
				CreatedAt:         time.Now(),
				UpdatedAt:         time.Now(),
			}

			if err := db.InsertFileMetadata(newFile); err != nil {
				log.Printf("Error inserting file: %v", err)
			}

			updatedFiles++
		}
	}

	db.LogSync(req.DeviceID, "push", updatedFiles+len(conflicts), "success", "")

	response := SyncPushResponse{
		Status:     "success",
		ServerTime: time.Now(),
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(response)
}
