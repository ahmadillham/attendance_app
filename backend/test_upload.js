const fs = require('fs');
const path = require('path');

// Buat gambar dummy
const dummyFile = path.join(__dirname, 'dummy.jpg');
fs.writeFileSync(dummyFile, 'dummy image content');

const FormData = require('form-data');
const fetch = require('node-fetch'); // Atau native fetch jika Node >= 18

async function testUpload() {
    const form = new FormData();
    form.append('reason', 'sick');
    form.append('description', 'Test upload from node!');
    form.append('dateFrom', new Date().toISOString());
    form.append('dateTo', new Date().toISOString());
    form.append('document', fs.createReadStream(dummyFile));

    try {
        console.log("Mocking login to get token...");
        // 1. Dapatkan token (login sbg 241101052 / Password123)
        const loginRes = await (await import('node-fetch')).default('http://localhost:3000/api/auth/login', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ nim: '241101052', password: 'Password123' })
        });
        const loginData = await loginRes.json();
        const token = loginData.token;
        if (!token) throw new Error("No token received");

        console.log("Token received, sending multipart request...");
        // 2. Kirim perizinan
        const uploadRes = await (await import('node-fetch')).default('http://localhost:3000/api/leave-requests', {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${token}`
            },
            body: form
        });
        const uploadData = await uploadRes.json();
        console.log("Upload result:", uploadRes.status, uploadData);
    } catch (err) {
        console.error("Test failed:", err);
    }
}

testUpload();
