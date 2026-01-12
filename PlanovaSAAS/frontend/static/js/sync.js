class SyncManager {
    constructor() {
        this.pendingUploads = [];
        this.pendingDownloads = [];
        this.lastSyncAt = localStorage.getItem('lastSyncAt') || null;
        this.deviceId = localStorage.getItem('deviceId') || this.generateDeviceId();
    }

    generateDeviceId() {
        const deviceId = 'device_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
        localStorage.setItem('deviceId', deviceId);
        return deviceId;
    }

    async push(files) {
        this.pendingUploads = files;
        const password = await passwordCache.getPassword();
        
        const syncedFiles = [];
        const conflicts = [];

        for (const file of files) {
            const localVersion = file.serverVersion || 0;
            const remoteVersion = file.remoteServerVersion || 0;

            if (localVersion > remoteVersion) {
                const merged = this.mergeContent(file.content, file.remoteContent);
                syncedFiles.push({
                    id: file.id,
                    content: merged,
                    serverVersion: localVersion + 1
                });
            } else if (remoteVersion > localVersion) {
                syncedFiles.push(file);
            } else {
                syncedFiles.push(file);
            }
        }

        const response = await fetch('/api/sync/push', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer ' + localStorage.getItem('authToken')
            },
            body: JSON.stringify({
                deviceId: this.deviceId,
                files: syncedFiles
            })
        });

        const result = await response.json();

        if (result.status === 'success') {
            this.lastSyncAt = new Date().toISOString();
            localStorage.setItem('lastSyncAt', this.lastSyncAt);
            this.pendingUploads = [];
            this.showSyncStatus('Sync completed successfully');
        } else {
            this.showSyncStatus('Sync failed: ' + result.error);
        }
    }

    async pull() {
        const response = await fetch('/api/sync/pull', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer ' + localStorage.getItem('authToken')
            },
            body: JSON.stringify({
                deviceId: this.deviceId,
                lastSyncAt: this.lastSyncAt
            })
        });

        const result = await response.json();

        if (result.files && result.files.length > 0) {
            for (const file of result.files) {
                if (!localStorage.getItem('file_' + file.id)) {
                    this.pendingDownloads.push(file);
                }
            }
            this.showSyncStatus('Received ' + result.files.length + ' updates from server');
        }

        this.lastSyncAt = result.serverTime;
        localStorage.setItem('lastSyncAt', this.lastSyncAt);
    }

    mergeContent(localContent, remoteContent) {
        const localLines = localContent.split('\n');
        const remoteLines = remoteContent.split('\n');
        
        const merged = new Set(localLines);
        
        for (const line of remoteLines) {
            if (!localLines.includes(line)) {
                merged.add(line);
            }
        }
        
        const result = Array.from(merged).join('\n');
        
        const diffLocal = localLines.filter(l => !remoteLines.includes(l));
        const diffRemote = remoteLines.filter(l => !localLines.includes(l));
        
        console.log('Merge conflict detected:');
        console.log('Only in local:', diffLocal.length, 'lines');
        console.log('Only in remote:', diffRemote.length, 'lines');
        console.log('Total merged:', result.split('\n').length, 'lines');

        return result;
    }

    showSyncStatus(message) {
        const statusEl = document.getElementById('sync-status');
        if (statusEl) {
            statusEl.textContent = message;
            statusEl.classList.remove('hidden');
            setTimeout(() => {
                statusEl.classList.add('hidden');
            }, 5000);
        }
    }

    onContentUpdated() {
        console.log('Content updated, clearing password cache in 5 minutes');
        setTimeout(() => {
            passwordCache.clearPassword();
        }, 5 * 60 * 1000);
    }
}

const syncManager = new SyncManager();
