package handlers

import (
	"crypto/sha256"
	"encoding/hex"
	"io"
	"log"
	"mime/multipart"
	"net/http"
	"os"
	"path/filepath"
	"time"

	"github.com/google/uuid"
	"github.com/planovasaas/backend/internal/database"
	"github.com/planovasaas/backend/internal/models"
)

func UploadFile(db *database.DB, storagePath string) func(http.ResponseWriter, *http.Request) {
	userID := r.Header.Get("X-User-ID")
	if userID == "" {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	r.ParseMultipartForm(32 << 20)
	file, handler, err := r.FormFile("file")
	if err != nil {
		log.Printf("Error getting file: %v", err)
		http.Error(w, "Failed to get file", http.StatusBadRequest)
		return
	}
	defer file.Close()

	content, err := io.ReadAll(file)
	if err != nil {
		log.Printf("Error reading file: %v", err)
		http.Error(w, "Failed to read file", http.StatusInternalServerError)
		return
	}

	salt := generateSalt()
	checksum := sha256Sum(content)
	encryptedContent := string(content)

	fileID := uuid.New().String()
	filename := handler.Filename
	if filename == "" {
		filename = fileID + ".md"
	}

	storageDir := filepath.Join(storagePath, userID, "dailies")
	if err := os.MkdirAll(storageDir, 0755); err != nil {
		log.Printf("Error creating storage directory: %v", err)
		http.Error(w, "Failed to create storage directory", http.StatusInternalServerError)
		return
	}

	filePath := filepath.Join(storageDir, filename)

	if err := os.WriteFile(filePath, encryptedContent); err != nil {
		log.Printf("Error writing file: %v", err)
		http.Error(w, "Failed to write file", http.StatusInternalServerError)
		return
	}

	fileSize := int64(len(encryptedContent))

	log.Printf("File uploaded: %s for user %s", filePath, userID)

	fileMetadata := &models.FileMetadata{
		ID:                fileID,
		UserID:            userID,
		FileType:          "daily",
		FilePath:          filePath,
		Filename:          filename,
		FileSize:          fileSize,
		EncryptedChecksum: checksum,
		EncryptedAt:       time.Now(),
		ServerVersion:     1,
	}

	if err := db.InsertFileMetadata(fileMetadata); err != nil {
		log.Printf("Error inserting file metadata: %v", err)
		http.Error(w, "Failed to insert file metadata", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	w.Write([]byte(fmt.Sprintf(`{"id":"%s","status":"uploaded"}`, fileID)))
}

func UpdateFile(db *database.DB, storagePath string) func(http.ResponseWriter, *http.Request) {
	userID := r.Header.Get("X-User-ID")
	if userID == "" {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	var req struct {
		ID      string `json:"id"`
		Content string `json:"content"`
		Salt    string `json:"salt"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	existing, err := db.GetFileMetadata(req.ID)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	saltBytes, err := hex.DecodeString(req.Salt)
	if err != nil {
		http.Error(w, "Invalid salt", http.StatusBadRequest)
		return
	}
	salt := string(saltBytes)

	oldFilePath := filepath.Join(storagePath, userID, "dailies", existing.Filename)
	newFilePath := filepath.Join(storagePath, userID, "dailies", existing.Filename)

	if _, err := os.Stat(oldFilePath); err == nil {
		log.Printf("Removing old file: %s", oldFilePath)
		os.Remove(oldFilePath)
	}

	if err := os.WriteFile(newFilePath, req.Content); err != nil {
		log.Printf("Error writing file: %v", err)
		http.Error(w, "Failed to write file", http.StatusInternalServerError)
		return
	}

	fileInfo, err := os.Stat(newFilePath)
	if err != nil {
		http.Error(w, "Failed to stat file", http.StatusInternalServerError)
		return
	}

	fileSize := int64(fileInfo.Size())

	checksum := sha256Sum([]byte(req.Content))

	newVersion := existing.ServerVersion + 1

	fileMetadata := &models.FileMetadata{
		ID:                req.ID,
		UserID:            userID,
		FileType:          existing.FileType,
		FilePath:          newFilePath,
		Filename:          existing.Filename,
		FileSize:          fileSize,
		EncryptedChecksum: checksum,
		EncryptedAt:       time.Now(),
		ServerVersion:     newVersion,
	}

	if err := db.UpdateFileMetadata(fileMetadata); err != nil {
		log.Printf("Error updating file metadata: %v", err)
		http.Error(w, "Failed to update file metadata", http.StatusInternalServerError)
		return
	}

	log.Printf("File updated: %s for user %s", newFilePath, userID)

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(fmt.Sprintf(`{"id":"%s","status":"updated"}`, req.ID)))
}

func DownloadFile(db *database.DB, storagePath string) func(http.ResponseWriter, *http.Request) {
	userID := r.Header.Get("X-User-ID")
	if userID == "" {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	id := r.PathValue("id")
	file, err := db.GetFileMetadata(id)
	if err != nil {
		log.Printf("Error getting file metadata: %v", err)
		http.Error(w, "File not found", http.StatusNotFound)
		return
	}

	filePath := filepath.Join(storagePath, userID, "dailies", file.Filename)

	if _, err := os.Stat(filePath); os.IsNotExist(err) {
		log.Printf("File not found: %s", filePath)
		http.Error(w, "File not found", http.StatusNotFound)
		return
	}

	log.Printf("File downloaded: %s for user %s", filePath, userID)

	http.ServeFile(w, r, filePath)
}

func DeleteFile(db *database.DB, storagePath string) func(http.ResponseWriter, *http.Request) {
	userID := r.Header.Get("X-User-ID")
	if userID == "" {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	id := r.PathValue("id")
	file, err := db.GetFileMetadata(id)
	if err != nil {
		log.Printf("Error getting file metadata: %v", err)
		http.Error(w, "File not found", http.StatusNotFound)
		return
	}

	filePath := filepath.Join(storagePath, userID, "dailies", file.Filename+".md")

	if err := os.Remove(filePath); err != nil {
		log.Printf("Error deleting file: %v", err)
		http.Error(w, "Failed to delete file", http.StatusInternalServerError)
		return
	}

	log.Printf("File deleted: %s for user %s", filePath, userID)

	now := time.Now()

	if err := db.Exec(`UPDATE files_metadata SET deleted_at = ? WHERE id = ?`, now, id); err != nil {
		log.Printf("Error soft deleting file: %v", err)
		http.Error(w, "Failed to delete file metadata", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(`{"status":"deleted"}`))
}

func ListFiles(db *database.DB, storagePath string) func(http.ResponseWriter, *http.Request) {
	userID := r.Header.Get("X-User-ID")
	if userID == "" {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	fileType := r.URL.Query().Get("type")

	var query string
	if fileType == "" || fileType == "daily" {
		query = `SELECT id, user_id, file_type, file_path, filename, file_size, encrypted_at, server_version, deleted_at, created_at, updated_at FROM files_metadata WHERE user_id = ? AND file_type = 'daily' AND deleted_at IS NULL ORDER BY updated_at DESC`
	} else if fileType == "note" {
		query = `SELECT id, user_id, file_type, file_path, filename, file_size, encrypted_at, server_version, deleted_at, created_at, updated_at FROM files_metadata WHERE user_id = ? AND file_type = 'note' AND deleted_at IS NULL ORDER BY updated_at DESC`
	} else {
		http.Error(w, "Invalid file type", http.StatusBadRequest)
		return
	}

	rows, err := db.DB.Query(query, userID)
	if err != nil {
		log.Printf("Error querying files: %v", err)
		http.Error(w, "Failed to query files", http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	var files []models.FileMetadata
	for rows.Next() {
		var file models.FileMetadata
		err := rows.Scan(&file.ID, &file.UserID, &file.FileType, &file.FilePath, &file.Filename, &file.FileSize, &file.EncryptedAt, &file.ServerVersion, &file.DeletedAt, &file.CreatedAt, &file.UpdatedAt)
		if err != nil {
			log.Printf("Error scanning file row: %v", err)
			continue
		}
		files = append(files, file)
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(files)
}

func sha256Sum(data []byte) string {
	hash := sha256.Sum256(data)
	return hex.EncodeToString(hash[:])
}

func generateSalt() string {
	salt := make([]byte, 16)
	for i := range salt {
		salt[i] = byte(time.Now().UnixNano() >> (i * 8))
	}
	return hex.EncodeToString(salt)
}
