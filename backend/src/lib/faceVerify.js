/**
 * Face Verification Utility
 * 
 * Compares a face descriptor (128D float array) against the stored descriptor
 * in the database using cosine similarity.
 * 
 * In production, the `incomingDescriptor` would come from a face-recognition
 * library (e.g. face-api.js, Python dlib/OpenCV via microservice).
 * For now, we compare the stored descriptor against itself as a placeholder,
 * but the comparison logic is real and production-ready.
 */

/**
 * Cosine similarity between two vectors.
 * Returns a value between -1 and 1 (1 = identical).
 */
function cosineSimilarity(a, b) {
    if (!a || !b || a.length !== b.length) return 0;

    let dotProduct = 0;
    let normA = 0;
    let normB = 0;

    for (let i = 0; i < a.length; i++) {
        dotProduct += a[i] * b[i];
        normA += a[i] * a[i];
        normB += b[i] * b[i];
    }

    const denominator = Math.sqrt(normA) * Math.sqrt(normB);
    if (denominator === 0) return 0;

    return dotProduct / denominator;
}

/**
 * Default threshold for cosine similarity matching.
 * Can be overridden via FACE_MATCH_THRESHOLD env variable.
 * 
 * Academic guidance for 128D face embeddings (FaceNet/ArcFace-style):
 *   - 0.60 = very permissive (siblings may pass)
 *   - 0.75 = moderate security (recommended for university context)
 *   - 0.85 = high security (may reject legitimate users in poor lighting)
 */
const DEFAULT_THRESHOLD = 0.75;

function getThreshold() {
    const envVal = parseFloat(process.env.FACE_MATCH_THRESHOLD);
    return !isNaN(envVal) && envVal > 0 && envVal <= 1 ? envVal : DEFAULT_THRESHOLD;
}

/**
 * Verify face match.
 * 
 * @param {number[]} storedDescriptor - 128D face embedding from DB
 * @param {number[]} incomingDescriptor - 128D face embedding from camera capture
 * @param {number} [threshold] - Override threshold (uses env/default if omitted)
 * @returns {{ matched: boolean, similarity: number, threshold: number }}
 */
function verifyFace(storedDescriptor, incomingDescriptor, threshold) {
    const effectiveThreshold = threshold ?? getThreshold();
    const similarity = cosineSimilarity(storedDescriptor, incomingDescriptor);
    const matched = similarity >= effectiveThreshold;
    const roundedSimilarity = Math.round(similarity * 1000) / 1000;

    // Structured log for threshold calibration
    console.log(JSON.stringify({
        event: 'face_verify',
        matched,
        similarity: roundedSimilarity,
        threshold: effectiveThreshold,
        timestamp: new Date().toISOString(),
    }));

    return {
        matched,
        similarity: roundedSimilarity,
        threshold: effectiveThreshold,
    };
}

module.exports = { cosineSimilarity, verifyFace, getThreshold };
