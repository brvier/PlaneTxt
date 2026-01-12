package handlers

import (
	"log"
	"net/http"

	"github.com/planovasaas/backend/internal/database"
	"github.com/planovasaas/backend/internal/models"
)

func DashboardHTML(db *database.DB) func(http.ResponseWriter, *http.Request) {
	userID := r.Header.Get("X-User-ID")
	if userID == "" {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	dateStr := r.URL.Query().Get("date")
	log.Printf("Dashboard loaded for user %s, date: %s", userID, dateStr)

	year, _ := time.Parse("2006", dateStr[:4])
	month, _ := time.Parse("01", dateStr[4:6])
	day, _ := time.Parse("02", dateStr[6:8])

	files, err := db.GetFilesSince(userID, time.Time{})
	if err != nil {
		log.Printf("Error loading files: %v", err)
		http.Error(w, "Failed to load files", http.StatusInternalServerError)
		return
	}

	todaysByDate := make(map[string]int)
	for _, file := range files {
		todaysByDate[file.FilePath] = countTodos(file.FileType)
	}

	days := generateCalendarDays(year, month, day, todaysByDate)

	w.Header().Set("Content-Type", "text/html")
	w.WriteHeader(http.StatusOK)
	renderCalendarTemplate(w, days)
}

func DailyHTML(db *database.DB) func(http.ResponseWriter, *http.Request) {
	userID := r.Header.Get("X-User-ID")
	if userID == "" {
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
		return
	}

	dateStr := r.PathValue("date")
	log.Printf("Daily view for date: %s, user: %s", dateStr, userID)

	formattedDate := formatDate(dateStr)
	fileID := dateStr + ".md"

	file, err := db.GetFileMetadata(fileID)
	if err != nil {
		log.Printf("Error getting file metadata: %v", err)
		http.Error(w, "File not found", http.StatusNotFound)
		return
	}

	lastSyncStr := ""
	if file.LastSyncAt != nil {
		lastSyncStr = file.LastSyncAt.Format("2006-01-02 15:04:05")
	}

	dailyData := struct {
		ID:         fileID,
		Date:       formattedDate,
		Content:    file.FileType,
		ServerVersion: file.ServerVersion,
		LastSyncAt: file.LastSyncAt,
	}

	w.Header().Set("Content-Type", "text/html")
	w.WriteHeader(http.StatusOK)
	renderDailyTemplate(w, dailyData)
}

func renderCalendarTemplate(w http.ResponseWriter, days []CalendarDay) {
	html := `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Calendar</title>
    <link rel="stylesheet" href="/static/css/app.css">
    <script src="https://unpkg.com/htmx.org@1.9.10/dist/htmx.min.js"></script>
</head>
<body class="bg-gray-100">
    <div class="p-4">
        <h1 class="text-2xl font-bold">Calendar</h1>
        <div class="mb-4 flex justify-between items-center">
            <button class="px-4 py-2 bg-gray-200 rounded hover:bg-gray-300"
                    hx-get="/dashboard/calendar/month?year=` + days[0].Year + `&month=` + days[0].Month + `"
                    hx-target="#calendar-container"
                    hx-swap="outerHTML">
                ← Previous
            </button>
            <h2 class="text-2xl font-bold">` + days[0].MonthName + ` ` + days[0].Year + `</h2>
            <button class="px-4 py-2 bg-gray-200 rounded hover:bg-gray-300"
                    hx-get="/dashboard/calendar/month?year=` + days[6].Year + `&month=` + days[6].Month + `"
                    hx-target="#calendar-container"
                    hx-swap="outerHTML">
                Next →
            </button>
        </div>
    </div>
    <div class="grid grid-cols-7 gap-1">
        <div class="font-bold text-center">Mon</div>
        <div class="font-bold text-center">Tue</div>
        <div class="font-bold text-center">Wed</div>
        <div class="font-bold text-center">Thu</div>
        <div class="font-bold text-center">Fri</div>
        <div class="font-bold text-center">Sat</div>
        <div class="font-bold text-center">Sun</div>`

`

	for _, day := range days {
		content := ""
		if day.IsToday {
			content += `<div class="calendar-cell border border-gray-200 p-2 min-h-24 bg-blue-100">`
		} else if day.HasContent {
			content += `<div class="calendar-cell border border-gray-200 p-2 min-h-24 bg-green-50">`
		} else {
			content += `<div class="calendar-cell border border-gray-200 p-2 min-h-24">`
		}
		content += `<div class="text-lg font-bold">` + day.Day + `</div>`
		if day.HasContent {
			content += `<div class="text-xs text-gray-600">✓ ` + day.TodoCount + ` tasks</div>`
		}
		content += `</div>`
	}

	w.Write([]byte(content))
}

func renderDailyTemplate(w http.ResponseWriter, data interface{}) {
	html := `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Daily - ` + data.Date + `</title>
    <link rel="stylesheet" href="/static/css/app.css">
    <script src="/static/js/encryption.js"></script>
    <script src="/static/js/key_derivation.js"></script>
    <script src="/static/js/password_cache.js"></script>
    <script src="/static/js/sync.js"></script>
    <script src="https://unpkg.com/htmx.org@1.9.10/dist/htmx.min.js"></script>
</head>
<body class="bg-white">
    <div id="daily-editor" class="h-full">
        <div class="mb-4 flex justify-between items-start">
            <h2 class="text-3xl font-bold">` + data.Date + `</h2>
            <div class="text-sm text-gray-600">
                Daily file: ` + data.ID + `.md
            </div>
        </div>

        <div class="flex gap-2">
            <button class="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700"
                        hx-post="/api/sync/pull"
                        hx-indicator="#sync-spinner">
                Pull Changes
            </button>
            <span id="sync-spinner" class="htmx-indicator hidden text-blue-600">
                Syncing...
            </span>
            <button class="px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700"
                        hx-post="/api/sync/push"
                        hx-trigger="sync-trigger"
                        hx-indicator="#push-spinner">
                Push Local Changes
            </button>
            <span id="push-spinner" class="htmx-indicator hidden text-blue-600">
                Pushing...
            </span>
            <button id="sync-trigger" style="display:none"></button>
            <span class="text-sm text-gray-600">
                Last sync: ` + data.LastSyncAt + `
            </span>
        </div>
    </div>

    <textarea id="content-editor"
              name="content"
              class="w-full h-full min-h-[600px] p-4 border border-gray-300 rounded font-mono text-sm resize-none"
              hx-post="/api/files/update/` + data.ID + `"
              hx-trigger="change"
              hx-indicator="#save-spinner"
              hx-swap="none"
              >` + data.Content + `</textarea>

    <span id="save-spinner" class="htmx-indicator hidden text-gray-600">
        Saving...
    </span>

    <div id="conflict-notification" class="hidden mt-4 p-4 bg-yellow-100 border border-yellow-400 rounded">
    </div>

    <div id="sync-status" class="hidden mt-4 p-4 bg-green-100 border border-green-400 rounded">
    </div>

    <script>
        const passwordCache = window.passwordCache;
        
        document.addEventListener('DOMContentLoaded', function() {
            if (window.syncManager && window.syncManager.pull) {
                window.syncManager.pull().catch(console.error);
            }
        });
        
        document.getElementById('content-editor').addEventListener('change', function(evt) {
            const passwordCache = window.passwordCache;
            const content = evt.target.value;
            
            if (!passwordCache || !passwordCache.hasPassword()) {
                alert('Please enter your password first');
                evt.target.value = '';
                return;
            }
            
            const salt = window.generateSalt();
            const encrypted = window.encryptContent(content, passwordCache.getPassword(), salt);
            
            const formData = new FormData();
            formData.append('content', encrypted.encrypted);
            formData.append('salt', encrypted.iv);
            formData.append('checksum', encrypted.checksum);
            
            fetch('/api/files/update/` + '` + data.ID + `', {
                method: 'POST',
                body: formData
            }).then(response => response.json()).then(result => {
                if (result.status === 'uploaded') {
                    document.getElementById('save-spinner').classList.add('hidden');
                    console.log('File saved successfully');
                } else {
                    alert('Failed to save: ' + (result.error || 'Unknown error'));
                }
            }).catch(err => {
                console.error('Error:', err);
                alert('Error saving file: ' + err.message);
            });
        });
    </script>
</body>
</html>
`
	w.Write([]byte(html))
}

func formatDate(fileID string) string {
	if len(fileID) != 8 {
		return fileID
	}
	return fileID[0:4] + "/" + fileID[4:6] + "/" + fileID[6:8]
}

func countTodos(fileType string) int {
	if fileType == "daily" {
		return 1
	}
	return 0
}

type CalendarDay struct {
	Day         int       `json:"day"`
	Month       int       `json:"month"`
	Year        int       `json:"year"`
	IsToday     bool      `json:"isToday"`
	HasContent  bool      `json:"hasContent"`
	Date        string    `json:"date"`
	TodoCount  int       `json:"todoCount"`
}
