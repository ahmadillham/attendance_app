const express = require("express");
const router = express.Router();
const prisma = require("../lib/prisma");
const authMiddleware = require("../middlewares/authMiddleware");
const upload = require("../middlewares/uploadMiddleware");
const { extractDescriptor, isAvailable } = require("../lib/faceDescriptor");

// POST /api/face/register — Register a face descriptor from uploaded photo
router.post(
  "/register",
  authMiddleware,
  upload.single("faceImage"),
  async (req, res) => {
    try {
      const studentId = req.user.id;

      if (!req.file) {
        return res
          .status(400)
          .json({ message: "Foto wajah wajib dilampirkan." });
      }

      if (!isAvailable()) {
        return res.status(503).json({
          message:
            "Layanan face recognition tidak tersedia. Model ML belum dimuat di server.",
        });
      }

      // Extract 128D face descriptor from uploaded image
      const descriptor = await extractDescriptor(req.file.path);
      if (!descriptor) {
        return res.status(400).json({
          message:
            "Wajah tidak terdeteksi dalam foto. Pastikan:\n- Wajah menghadap kamera\n- Pencahayaan cukup\n- Hanya satu wajah dalam frame",
        });
      }

      // Save descriptor to database
      await prisma.student.update({
        where: { id: studentId },
        data: { faceDescriptor: descriptor },
      });

      res.json({
        message: "Wajah berhasil didaftarkan!",
        descriptorLength: descriptor.length,
      });
    } catch (err) {
      res.status(500).json({ message: err.message });
    }
  },
);

// GET /api/face/status — Check if face is registered
router.get("/status", authMiddleware, async (req, res) => {
  try {
    const student = await prisma.student.findUnique({
      where: { id: req.user.id },
      select: { faceDescriptor: true },
    });

    res.json({
      registered: !!student?.faceDescriptor,
      modelAvailable: isAvailable(),
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

module.exports = router;
