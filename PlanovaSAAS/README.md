# PlanovaSAAS

A custom Go backend + SQLite + HTMX + Encrypted File Storage implementation of Planova for multi-device sync.

## Technology Stack

- **Backend**: Custom Go application (net/http + sqlite)
- **Database**: SQLite
- **Frontend**: HTMX + HTML templates
- **Encryption**: Argon2id key derivation + AES-256-GCM encryption (client-side)
- **File Storage**: Local filesystem
- **Sync Protocol**: Timestamp-based with last-version-wins conflict resolution (no UI, diff merge)
- **Multi-tenancy**: User-based filtering (no shared database)

## Architecture Decisions

- **Password recovery**: No recovery (lost password = lost all data)
- **Password change**: No change (password is permanent)
- **Storage backend**: Local filesystem
- **Search**: Client-side index
- **Conflict UI**: No UI, use diff merge

## Project Structure

```
PlanovaSAAS/
├── backend/
│   ├── main.go
│   ├── go.mod / go.sum
│   ├── internal/
│   │   ├── config/config.go
│   │   ├── models/models.go
│   │   ├── handlers/ (to be implemented)
│   │   ├── services/ (to be implemented)
│   │   ├── database/sqlite.go
│   │   └── middleware/auth.go
│   ├── storage/users/
│   └── data/planova.db
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
│       ├── auth/login.html
│       ├── dashboard/index.html
│       ├── dashboard/calendar.html
│       └── dashboard/daily.html
├── docs/
│   ├── encryption_protocol.md
│   ├── api.md
│   └── deployment.md
└── docker-compose.yml
```

## Getting Started

### Development

```bash
cd PlanovaSAAS
docker-compose up --build
```

Access the application at http://localhost:8090

### Manual Run

```bash
cd backend
go run main.go
```

## Security Features

- End-to-end encryption (server cannot access user data)
- Password never sent to server after login
- Client derives encryption key locally using Argon2id
- Password cache memory-only, auto-clear after 5 minutes
- Unique salt per file
- AES-256-GCM with authenticated encryption
- SHA-256 checksum verification

## API Endpoints

### Authentication
- `POST /api/auth/register` - Register new user
- `POST /api/auth/login` - Login with email/password
- `POST /api/auth/logout` - Logout

### Sync
- `POST /api/sync/pull` - Pull file metadata since last sync
- `POST /api/sync/push` - Push file metadata with conflicts
- `POST /api/sync/register-device` - Register device

### Files
- `POST /api/files/upload` - Upload encrypted file
- `GET /api/files/list` - List user files
- `GET /api/files/download/:id` - Download encrypted file
- `DELETE /api/files/:id` - Delete file

### Dashboard
- `GET /dashboard` - Main dashboard
- `GET /dashboard/calendar` - Calendar view (left sidebar)
- `GET /dashboard/daily/:date` - Daily editor (right side)

## Client-Side Encryption

### Key Derivation (Argon2id)
```javascript
await deriveKey(password, salt);
// Parameters: mem=64MB, time=3, parallelism=4, hashLen=32
```

### File Encryption (AES-256-GCM)
```javascript
await encryptContent(content, password, salt);
// Uses salt as IV
// Returns encrypted + IV
```

### Password Cache
```javascript
passwordCache.setPassword(password);
// Cached in memory only
// Auto-clears after 5 minutes
```

### Sync Protocol

### Pull
1. Client sends `deviceId` + `lastSyncAt`
2. Server returns file metadata since timestamp
3. Client updates local database

### Push
1. Client encrypts files with password
2. Client sends encrypted files + checksums
3. Server stores encrypted files (cannot decrypt)
4. Server compares `serverVersion` for conflicts
5. Higher version wins (no merge possible on server)

### Conflict Resolution (Diff Merge - No UI)
```javascript
mergeContent(localContent, remoteContent);
// Merges line-by-line
// Adds conflicting lines from both versions
// No UI notification (user sees merged result)
```

## Trade-offs

### Advantages
- End-to-end encryption (server cannot access user data)
- Privacy (zero-knowledge architecture)
- GDPR-friendly
- Simple storage backend (local filesystem)

### Limitations
- No server-side search
- No intelligent merge (conflict resolution: last-version-wins)
- No server-side validation
- Complex sync (all logic client-side)
- Password critical (lost password = lost all data)

## Next Steps

1. Implement Go handlers (auth, sync, files, dashboard)
2. Implement file storage service
3. Add calendar rendering logic
4. Add client-side search index
5. Test sync protocol
6. Add real-time updates (optional)
