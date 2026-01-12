async function encryptContent(content, password, salt) {
    const encKey = await deriveKey(password, salt);
    
    const encoder = new TextEncoder();
    const data = encoder.encode(content);
    const iv = new TextEncoder().encode(salt);
    
    const key = await crypto.subtle.importKey(
        'raw',
        encKey,
        { name: 'AES-GCM', length: 256 },
        false,
        ['encrypt']
    );
    
    const encrypted = await crypto.subtle.encrypt(
        {
            name: 'AES-GCM',
            length: 256
        },
        key,
        iv,
        data
    );
    
    const combined = new Uint8Array(
        encrypted.iv.byteLength + encrypted.ciphertext.byteLength
    );
    
    combined.set(new Uint8Array(encrypted.iv), 0);
    combined.set(new Uint8Array(encrypted.ciphertext), encrypted.iv.byteLength);
    
    const base64 = arrayBufferToBase64(combined.buffer);
    return {
        encrypted: base64,
        iv: arrayBufferToBase64(encrypted.iv.buffer)
    };
}

async function decryptContent(encryptedContent, password, salt) {
    const encKey = await deriveKey(password, salt);
    
    const key = await crypto.subtle.importKey(
        'raw',
        encKey,
        { name: 'AES-GCM', length: 256 },
        false,
        ['decrypt']
    );
    
    const encrypted = base64ToArrayBuffer(encryptedContent);
    const iv = new Uint8Array(encrypted.slice(0, 24));
    const ciphertext = new Uint8Array(encrypted.slice(24));
    
    const decrypted = await crypto.subtle.decrypt(
        {
            name: 'AES-GCM',
            length: 256
        },
        key,
        iv,
        ciphertext
    );
    
    const decoder = new TextDecoder();
    return decoder.decode(decrypted);
}

function sha256(string) {
    const encoder = new TextEncoder();
    const data = encoder.encode(string);
    return crypto.subtle.digest('SHA-256', data).then(hash => {
        const hashArray = Array.from(new Uint8Array(hash));
        const hashHex = hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
        return hashHex;
    });
}

function generateSalt() {
    const salt = new Uint8Array(16);
    crypto.getRandomValues(salt);
    return arrayBufferToBase64(salt.buffer);
}

function arrayBufferToBase64(buffer) {
    let binary = '';
    const bytes = new Uint8Array(buffer);
    const len = bytes.byteLength;
    for (let i = 0; i < len; i++) {
        binary += String.fromCharCode(bytes[i]);
    }
    return window.btoa(binary);
}

function base64ToArrayBuffer(base64) {
    const binary = window.atob(base64);
    const len = binary.length;
    const bytes = new Uint8Array(len);
    for (let i = 0; i < len; i++) {
        bytes[i] = binary.charCodeAt(i);
    }
    return bytes.buffer;
}
