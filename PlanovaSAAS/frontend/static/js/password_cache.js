class PasswordCache {
    constructor() {
        this.password = null;
        this.timer = null;
        this.cacheTimeout = 5 * 60 * 1000;
        this.storageKey = 'planova_password';
    }

    setPassword(password) {
        this.password = password;
        this.resetTimer();
    }

    getPassword() {
        if (!this.password) {
            throw new Error('Password not cached. Please enter your password.');
        }
        this.resetTimer();
        return this.password;
    }

    clearPassword() {
        this.password = null;
        clearTimeout(this.timer);
        sessionStorage.removeItem(this.storageKey);
    }

    resetTimer() {
        clearTimeout(this.timer);
        this.timer = setTimeout(() => {
            console.log('Password cache expired, clearing...');
            this.clearPassword();
        }, this.cacheTimeout);
    }

    hasPassword() {
        return this.password !== null;
    }
}

const passwordCache = new PasswordCache();
