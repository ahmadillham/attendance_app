/**
 * Download face-api.js models from GitHub.
 * Run: node scripts/download-face-models.js
 */

const https = require('https');
const fs = require('fs');
const path = require('path');

const MODELS_DIR = path.join(__dirname, '../models');
const BASE_URL = 'https://raw.githubusercontent.com/vladmandic/face-api/master/model';

const MODEL_FILES = [
    // SSD MobileNet v1 (face detection)
    'ssd_mobilenetv1_model-weights_manifest.json',
    'ssd_mobilenetv1_model-shard1',
    'ssd_mobilenetv1_model-shard2',
    // Face Landmark 68 (facial landmarks)
    'face_landmark_68_model-weights_manifest.json',
    'face_landmark_68_model-shard1',
    // Face Recognition (128D descriptor)
    'face_recognition_model-weights_manifest.json',
    'face_recognition_model-shard1',
    'face_recognition_model-shard2',
];

function downloadFile(url, dest) {
    return new Promise((resolve, reject) => {
        const file = fs.createWriteStream(dest);
        https.get(url, (response) => {
            if (response.statusCode === 301 || response.statusCode === 302) {
                // Follow redirect
                https.get(response.headers.location, (redirected) => {
                    redirected.pipe(file);
                    file.on('finish', () => { file.close(); resolve(); });
                }).on('error', reject);
            } else {
                response.pipe(file);
                file.on('finish', () => { file.close(); resolve(); });
            }
        }).on('error', (err) => {
            fs.unlink(dest, () => {}); 
            reject(err);
        });
    });
}

async function main() {
    // Create models directory
    if (!fs.existsSync(MODELS_DIR)) {
        fs.mkdirSync(MODELS_DIR, { recursive: true });
        console.log(`📁 Created directory: ${MODELS_DIR}`);
    }

    console.log('📥 Downloading face-api.js models...\n');

    for (const file of MODEL_FILES) {
        const url = `${BASE_URL}/${file}`;
        const dest = path.join(MODELS_DIR, file);

        if (fs.existsSync(dest)) {
            console.log(`  ✓ ${file} (already exists)`);
            continue;
        }

        process.stdout.write(`  ↓ ${file}...`);
        try {
            await downloadFile(url, dest);
            console.log(' ✅');
        } catch (err) {
            console.log(` ❌ ${err.message}`);
        }
    }

    console.log('\n✅ Done! Models saved to:', MODELS_DIR);
    console.log('   Restart the server to load models.');
}

main().catch(console.error);
