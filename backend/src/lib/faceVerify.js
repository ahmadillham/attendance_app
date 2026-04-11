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
 * Verify face match.
 * 
 * @param {number[]} storedDescriptor - 128D face embedding from DB
 * @param {number[]} incomingDescriptor - 128D face embedding from camera capture
 * @param {number} threshold - Minimum cosine similarity to consider a match (default 0.6)
 * @returns {{ matched: boolean, similarity: number }}
 */
function verifyFace(storedDescriptor, incomingDescriptor, threshold = 0.6) {
    const similarity = cosineSimilarity(storedDescriptor, incomingDescriptor);
    return {
        matched: similarity >= threshold,
        similarity: Math.round(similarity * 1000) / 1000, // 3 decimal places
    };
}

module.exports = { cosineSimilarity, verifyFace };
