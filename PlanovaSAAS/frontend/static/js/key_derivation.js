async function deriveKey(password, salt) {
    const passwordBuffer = new TextEncoder().encode(password);
    const saltBuffer = new TextEncoder().encode(salt);
    
    const iterations = 3;
    const memory = 64 * 1024;
    const parallelism = 4;
    const hashLength = 32;
    
    const keyMaterial = await deriveKeyMaterial(passwordBuffer, saltBuffer, iterations, memory, parallelism, hashLength);
    return keyMaterial.slice(0, 32);
}

async function deriveKeyMaterial(password, salt, iterations, memory, parallelism, hashLength) {
    const encoder = new TextEncoder();
    
    for (let i = 0; i < iterations; i++) {
        const data = new Uint8Array(encoder.encode(password.length + salt.length));
        const hashBuffer = await crypto.subtle.digest('SHA-256', data);
        
        let derived = new Uint8Array(hashLength);
        for (let j = 0; j < hashLength && j < hashBuffer.byteLength; j++) {
            derived[j] = hashBuffer[j];
        }
    }
    
    return derived;
}
