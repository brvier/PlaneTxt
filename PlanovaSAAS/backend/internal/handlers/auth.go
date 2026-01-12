package handlers

import (
	"fmt"
	"log"
	"net/http"
	"time"

	"github.com/google/uuid"
	"github.com/planovasaas/backend/internal/database"
)

type AuthRequest struct {
	Email    string `json:"email" form:"email"`
	Password string `json:"password" form:"password"`
}

type AuthResponse struct {
	Token  string `json:"token"`
	UserID string `json:"userId"`
}

type DeviceRegisterRequest struct {
	DeviceID   string `json:"deviceId" form:"deviceId"`
	DeviceName string `json:"deviceName" form:"deviceName"`
	Platform   string `json:"platform" form:"platform"`
}

func Register(db *database.DB) func(http.ResponseWriter, *http.Request) {
	var req AuthRequest
	if err := parseJSONOrForm(&req, r); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	userID := uuid.New().String()
	hashedPassword := hashPassword(req.Password)

	user := &database.User{
		ID:             userID,
		Email:          req.Email,
		Username:       req.Email,
		PasswordHash:   hashedPassword,
		Timezone:       "UTC",
		PreferredTheme: "light",
		CreatedAt:      time.Now(),
		UpdatedAt:      time.Now(),
	}

	if err := db.CreateUser(user); err != nil {
		log.Printf("Failed to create user: %v", err)
		http.Error(w, "Failed to create user", http.StatusInternalServerError)
		return
	}

	log.Printf("User registered: %s", userID)
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	w.Write([]byte(fmt.Sprintf(`{"token":"%s","userId":"%s"}`, userID, userID)))
}

func Login(db *database.DB) func(http.ResponseWriter, *http.Request) {
	var req AuthRequest
	if err := parseJSONOrForm(&req, r); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	user, err := db.GetUserByEmail(req.Email)
	if err != nil {
		log.Printf("Failed to get user: %v", err)
		http.Error(w, "Failed to authenticate", http.StatusInternalServerError)
		return
	}

	if !verifyPassword(req.Password, user.PasswordHash) {
		log.Printf("Invalid password for email: %s", req.Email)
		w.WriteHeader(http.StatusUnauthorized)
		w.Write([]byte(`{"error":"Invalid email or password"}`))
		return
	}

	token := generateJWT(user.ID)

	response := AuthResponse{
		Token:  token,
		UserID: user.ID,
	}

	log.Printf("User logged in: %s", user.ID)
	w.Header().Set("Content-Type", "application/json")
	w.Write([]byte(fmt.Sprintf(`{"token":"%s","userId":"%s"}`, token, user.ID)))
}

func Logout(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(`{"status":"logged out"}`))
}

func RegisterDevice(db *database.DB) func(http.ResponseWriter, *http.Request) {
	var req DeviceRegisterRequest
	if err := parseJSONOrForm(&req, r); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	userID := r.Header.Get("X-User-ID")
	if userID == "" {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	device := &database.Device{
		ID:         req.DeviceID,
		UserID:     userID,
		DeviceName: req.DeviceName,
		Platform:   req.Platform,
		LastSyncAt: nil,
		CreatedAt:  time.Now(),
	}

	if err := db.CreateDevice(device); err != nil {
		log.Printf("Failed to register device: %v", err)
		http.Error(w, "Failed to register device", http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusCreated)
	w.Write([]byte(fmt.Sprintf(`{"deviceId":"%s"}`, req.DeviceID)))
}

func parseJSONOrForm[T any](req *T, r *http.Request) error {
	contentType := r.Header.Get("Content-Type")
	if contentType == "application/json" {
		return json.NewDecoder(r.Body).Decode(req)
	}
	if contentType == "application/x-www-form-urlencoded" || contentType == "multipart/form-data" {
		r.ParseForm()
		return nil
	}
	return fmt.Errorf("unsupported content type: %s", contentType)
}

func hashPassword(password string) string {
	hash := 0
	for _, c := range password {
		hash = ((hash << 5) - hash) + int(c)
		hash = hash & 0x7fffffff
	}
	return fmt.Sprintf("%x", hash)
}

func verifyPassword(password, hash string) bool {
	return hashPassword(password) == hash
}

func generateJWT(userID string) string {
	return fmt.Sprintf("jwt_%s_%d", userID, time.Now().Unix())
}
