/**
 * Face Descriptor Extraction Utility
 * 
 * Uses @vladmandic/face-api with TensorFlow.js to extract 128D face embeddings
 * from uploaded images. Works in Node.js without a browser.
 * 
 * Models required in ./models/ directory:
 *   - ssd_mobilenetv1_model-weights_manifest.json
 *   - face_landmark_68_model-weights_manifest.json  
 *   - face_recognition_model-weights_manifest.json
 */

const path = require('path');
const fs = require('fs');
const util = require('util');

// Monkey-patch removed Node.js util functions (removed in Node 24)
// This prevents @tensorflow/tfjs-node from crashing during face extraction.
if (!util.isNullOrUndefined) {
    util.isNullOrUndefined = function(val) {
        return val === null || val === undefined;
    };
}
if (!util.isArray) {
    util.isArray = Array.isArray;
}

let faceapi;
let tf;
let canvas;
let modelsLoaded = false;

const MODELS_PATH = path.join(__dirname, '../../models');

/**
 * Initialize face-api.js with TensorFlow.js backend and load models.
 * Called once at server startup. Subsequent calls are no-ops.
 */
async function initFaceApi() {
    if (modelsLoaded) return;

    try {
        // Dynamic imports to handle missing dependencies gracefully
        tf = require('@tensorflow/tfjs-node');
        faceapi = require('@vladmandic/face-api');
        canvas = require('canvas');

        // Monkey-patch face-api to use node-canvas instead of browser DOM
        const { Canvas, Image, ImageData } = canvas;
        faceapi.env.monkeyPatch({ Canvas, Image, ImageData });

        // Verify models directory exists
        if (!fs.existsSync(MODELS_PATH)) {
            console.warn(`⚠️  Models directory not found: ${MODELS_PATH}`);
            console.warn('   Download models from: https://github.com/vladmandic/face-api/tree/master/model');
            console.warn('   Face recognition will be UNAVAILABLE (records flagged as unverified).');
            return;
        }

        // Load the three required models
        await faceapi.nets.ssdMobilenetv1.loadFromDisk(MODELS_PATH);
        await faceapi.nets.faceLandmark68Net.loadFromDisk(MODELS_PATH);
        await faceapi.nets.faceRecognitionNet.loadFromDisk(MODELS_PATH);

        modelsLoaded = true;
        console.log('✅ Face recognition models loaded successfully.');
    } catch (err) {
        console.warn(`⚠️  Failed to initialize face-api: ${err.message}`);
        console.warn('   Face recognition will be UNAVAILABLE (records flagged as unverified).');
    }
}

/**
 * Extract a 128D face descriptor from an image file.
 * 
 * @param {string} imagePath - Absolute path to the image file
 * @returns {Promise<Float32Array|null>} 128D descriptor or null if no face detected
 */
async function extractDescriptor(imagePath) {
    if (!modelsLoaded) {
        console.warn('⚠️  Face models not loaded. Returning null (bypass mode).');
        return null;
    }

    let tensor;
    try {
        // Read file bytes
        const buffer = fs.readFileSync(imagePath);
        
        // Decode image directly to a 3D tensor (bypasses node-canvas native crash issues)
        tensor = tf.node.decodeImage(buffer, 3);

        // Detect single face → landmarks → descriptor
        const detection = await faceapi
            .detectSingleFace(tensor)
            .withFaceLandmarks()
            .withFaceDescriptor();

        if (!detection) {
            console.log('ℹ️  No face detected in image.');
            return null;
        }

        // detection.descriptor is a Float32Array of length 128
        return Array.from(detection.descriptor);
    } catch (err) {
        console.error(`❌ Face descriptor extraction failed: ${err.message}`);
        return null;
    } finally {
        if (tensor) {
            tensor.dispose();
        }
    }
}

/**
 * Extract 68-point face landmarks from an image file.
 * Used for liveness detection — comparing landmark positions between
 * multiple frames to verify that the face physically moved.
 * 
 * @param {string} imagePath - Absolute path to the image file
 * @returns {Promise<Array<{x: number, y: number}>|null>} 68 landmarks or null if no face detected
 */
async function extractLandmarks(imagePath) {
    if (!modelsLoaded) {
        console.warn('⚠️  Face models not loaded. Cannot extract landmarks.');
        return null;
    }

    let tensor;
    try {
        const buffer = fs.readFileSync(imagePath);
        tensor = tf.node.decodeImage(buffer, 3);

        const detection = await faceapi
            .detectSingleFace(tensor)
            .withFaceLandmarks();

        if (!detection) {
            console.log('ℹ️  No face detected in image (landmarks).');
            return null;
        }

        // Return array of {x, y} points (68 landmarks)
        return detection.landmarks.positions.map(pt => ({ x: pt.x, y: pt.y }));
    } catch (err) {
        console.error(`❌ Landmark extraction failed: ${err.message}`);
        return null;
    } finally {
        if (tensor) {
            tensor.dispose();
        }
    }
}

/**
 * Check if face recognition is available (models loaded).
 */
function isAvailable() {
    return modelsLoaded;
}

module.exports = { initFaceApi, extractDescriptor, extractLandmarks, isAvailable };
