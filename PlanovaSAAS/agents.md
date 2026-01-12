# PlanovaSAAS Implementation Plan

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                   Custom Go Backend                      │
│                   (SQLite + File Storage)              │
└─────────────────────────────────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
        ▼                   ▼                   ▼
   ┌─────────┐      ┌─────────┐      ┌─────────┐
   │ User A  │      │ User B  │      │ User C  │
   │ Device 1│      │ Device 2│      │ Device 3│
   └────┬────┘      └────┬────┘      └────┬────┘
        │                  │                   │
        └──────────────────┼───────────────────┘
                           │
              ┌──────────▼──────────┐
              │  Memory (Password  │
              │  Cached Only)      │
              │                    │
              └─────────────────────┘
```

## Technology Stack

- **Backend**: Custom Go application (Echo framework)
- **Database**: SQLite
- **Frontend**: HTMX + Go Templates (html/template or Templ)
- **Encryption**: Argon2id key derivation + AES-256-GCM encryption (client-side)
- **File Storage**: External filesystem or S3-compatible storage
- **Sync Protocol**: Timestamp-based with last-version-wins conflict resolution
- **Multi-tenancy**: User-based filtering (no shared database)

---

## Project Structure

```
PlanovaSAAS/
├── backend/
│   ├── main.go
│   ├── go.mod / go.sum
│   ├── internal/
│   │   ├── config/
│   │   │   └── config.go
│   │   ├── models/
│   │   │   ├── user.go
│   │   │   ├── device.go
│   │   │   └── file_metadata.go
│   │   ├── handlers/
│   │   │   ├── auth.go
│   │   │   ├── files.go
│   │   │   ├── sync.go
│   │   │   └── dashboard.go
│   │   ├── services/
│   │   │   ├── file_storage.go
│   │   │   ├── crypto.go
│   │   │   └── sync_service.go
│   │   ├── database/
│   │   │   ├── sqlite.go
│   │   │   └── migrations.go
│   │   └── middleware/
│   │       ├── auth.go
│   │       └── csrf.go
│   ├── storage/
│   │   └── users/
│   └── data/
│       └── planova.db
├── frontend/
│   ├── static/
│   │   ├── css/app.css
│   │   └── js/
│   │       ├── encryption.js
│   │       ├── key_derivation.js
│   │       ├── password_cache.js
│   │       └── sync.js
│   └── templates/
│       ├── layout.html
│       ├── auth/
│       │   ├── login.html
│       │   └── register.html
│       ├── dashboard/
│       │   ├── calendar.html
│       │   └── daily.html
│       └── components/
│           ├── event_row.html
│           └── todo_item.html
├── docs/
│   ├── encryption_protocol.md
│   ├── api.md
│   └── deployment.md
└── docker-compose.yml
```

---

## Database Schema (SQLite)

### `users`
```sql
CREATE TABLE users (
    id TEXT PRIMARY KEY,
    email TEXT UNIQUE NOT NULL,
    username TEXT,
    password_hash TEXT NOT NULL,
    timezone TEXT,
    preferred_theme TEXT DEFAULT 'light',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

### `devices`
```sql
CREATE TABLE devices (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    device_name TEXT,
    platform TEXT,
    last_sync_at DATETIME,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
```

### `files_metadata`
```sql
CREATE TABLE files_metadata (
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
);
```

### `sync_log`
```sql
CREATE TABLE sync_log (
    id TEXT PRIMARY KEY,
    device_id TEXT NOT NULL,
    action TEXT NOT NULL,
    records_count INTEGER,
    status TEXT,
    error_message TEXT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE CASCADE
);
```

---

## Client-Side Encryption (JavaScript)

### Key Derivation (Argon2id)
```javascript
import { argon2id } from 'argon2-browser';

async function deriveKey(password, salt) {
    const passwordBuffer = new TextEncoder().encode(password);
    const saltBuffer = new TextEncoder().encode(salt);

    return await argon2id({
        pass: passwordBuffer,
        salt: saltBuffer,
        mem: 64 * 1024,
        time: 3,
        parallelism: 4,
        hashLen: 32,
        type: argon2id.ArgonType.Argon2id,
    });
}
```

### File Encryption (AES-256-GCM)
```javascript
import { AES, GCM } from 'crypto-js';

async function encryptContent(content, password, salt) {
    const { encKey } = await deriveKeys(password, salt);
    const encrypted = AES.encrypt(content, encKey, {
        mode: GCM,
        iv: salt,
        padding: null,
    });
    return encrypted.toString();
}
```

### Password Cache (Memory Only)
```javascript
class PasswordCache {
    constructor() {
        this.password = null;
        this.timer = null;
        this.cacheTimeout = 5 * 60 * 1000;
    }

    setPassword(password) {
        this.password = password;
        this.resetTimer();
    }

    clearPassword() {
        this.password = null;
        clearTimeout(this.timer);
    }
}
```

---

## Backend Implementation

### `main.go`
```go
package main

import (
    "log"
    "github.com/labstack/echo/v4"
    "github.com/labstack/echo/v4/middleware"
)

func main() {
    e := echo.New()

    db, err := database.Init("data/planova.db")
    if err != nil {
        log.Fatal(err)
    }
    defer db.Close()

    e.Use(middleware.Logger())
    e.Use(middleware.Recover())
    e.Use(middleware.CSRF())

    api := e.Group("/api")
    api.Use(middleware.AuthRequired(db))

    api.POST("/auth/register", handlers.Register)
    api.POST("/auth/login", handlers.Login)
    api.POST("/sync/pull", handlers.SyncPull)
    api.POST("/sync/push", handlers.SyncPush)
    api.POST("/files/upload", handlers.UploadFile)
    api.GET("/files/list", handlers.ListFiles)
    api.GET("/files/download/:id", handlers.DownloadFile)

    e.GET("/dashboard", handlers.Dashboard)
    e.GET("/dashboard/calendar", handlers.CalendarHTML)
    e.GET("/dashboard/daily/:date", handlers.DailyHTML)

    e.Logger.Fatal(e.Start(":8090"))
}
```

### `internal/handlers/files.go`
```go
func UploadFile(c echo.Context) error {
    userId := c.Get("userId").(string)

    var req FileUploadRequest
    c.Bind(&req)

    src, err := req.File.Open()
    defer src.Close()

    storagePath := fmt.Sprintf("storage/users/%s/%s", userId, req.FilePath)
    c.Save(req.File, storagePath)

    fileId := uuid.New().String()
    db.InsertFileMetadata(&FileMetadata{
        ID:             fileId,
        UserID:         userId,
        FileType:        req.FileType,
        FilePath:        req.FilePath,
        EncryptedChecksum: req.Checksum,
        FileSize:        req.File.Size,
        EncryptedAt:    time.Now(),
        ServerVersion:   1,
    })

    return c.JSON(http.StatusOK, map[string]any{
        "id": fileId,
    })
}
```

---

## Frontend Layout (HTMX)

### Dashboard Layout
```html
<div class="flex h-screen">
    <aside class="w-1/3 border-r bg-white p-4">
        <div id="calendar-container"
             hx-get="/dashboard/calendar"
             hx-trigger="load">
        </div>
    </aside>

    <main class="flex-1 p-6">
        <div id="daily-content"
             hx-get="/dashboard/daily?date={{selectedDate}}"
             hx-target="#daily-content"
             hx-swap="outerHTML">
        </div>
    </main>
</div>
```

---

## Implementation Phases

### Phase 1: Foundation (Week 1) - COMPLETE
- [x] Project setup (Go modules, dependencies)
- [x] SQLite database with migrations
- [x] File storage interface (local filesystem)
- [x] HTMX base templates
- [x] Basic CSS styling
- [x] Client-side encryption (Argon2id + AES-256-GCM)
- [x] Password cache (memory-only, 5min timeout)
- [x] Sync manager (client-side conflict resolution)
- [x] Docker setup
- [ ] Go handlers (auth, sync, files, dashboard)

### Phase 2: Encryption (Week 2) - COMPLETE
- [x] Client-side Argon2id key derivation
- [x] Client-side AES-256-GCM encryption/decryption
- [x] Memory-only password cache
- [x] File upload/download APIs

### Phase 3: Core UI (Week 3-4) - PARTIAL
- [x] Calendar view (HTMX) - Template created
- [x] Daily editor template - Template created
- [x] Dashboard layout with calendar + editor
- [ ] Go backend handlers for dashboard
- [ ] Calendar rendering logic
- [ ] Notes management

### Phase 4: Sync & Multi-Device (Week 5-6) - PARTIAL
- [x] Sync manager JS (client-side)
- [x] Diff merge conflict resolution
- [ ] Pending upload/download queue
- [ ] Go backend sync endpoints
- [ ] Device registration
- [ ] Incremental sync (file metadata)
- [ ] Offline queue support

### Phase 5: Polish (Week 7-8)
- [ ] Mobile responsiveness
- [ ] Security audit
- [ ] Performance optimization
- [ ] Documentation
- [ ] Testing

---

## Security Considerations

### 1. Password Security
- Server stores bcrypt hash ONLY (never plaintext)
- Password never sent to server after login
- Client derives encryption key locally
- Server cannot decrypt files

### 2. Encryption Best Practices
- Unique salt per file
- Argon2id for key derivation
- AES-256-GCM with authenticated encryption
- Password cache memory-only, auto-clear after 5 minutes

### 3. Web Security
- HTTPS/TLS everywhere
- CSRF protection for HTMX
- Secure cookie flags (HttpOnly, SameSite)
- Rate limiting on auth endpoints

### 4. File Security
- SHA-256 checksum verification
- Encrypted storage (filesystem or S3)
- Access control via user IDs
- Audit logging in sync_log

---

## Trade-offs

### Advantages
- End-to-end encryption (server cannot access user data)
- Privacy (zero-knowledge architecture)
- GDPR-friendly
- Flexible storage backend

### Limitations
- No server-side search
- No smart merge (conflict resolution: last-version-wins)
- No server-side validation
- Complex sync (all logic client-side)
- Password critical (lost password = lost all data)

---

## Deployment

### Development
```yaml
version: '3.8'
services:
  planovasaas:
    build: .
    ports: ["8090:8090"]
    volumes: ["./storage:/app/storage", "./data:/app/data"]
    restart: unless-stopped
```

### Production
1. Build Go binary
2. Deploy with systemd service
3. NGINX reverse proxy for SSL
4. Regular backups of storage directory
