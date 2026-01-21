import express from "express";
import cors from "cors";
import multer from "multer";
import { exiftool } from "exiftool-vendored";
import path from "path";
import fs from "fs";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
const port = 3001;

app.use(cors());
app.use(express.json());

// Setup multer for file uploads
const upload = multer({ dest: "uploads/" });

// Create uploads directory if it doesn't exist
if (!fs.existsSync("uploads")) {
  fs.mkdirSync("uploads");
}

// Endpoint to read metadata
app.post("/api/metadata", upload.single("file"), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: "No file uploaded" });
    }

    const filePath = req.file.path;
    const metadata = await exiftool.read(filePath);

    // Cleanup uploaded file
    fs.unlinkSync(filePath);

    res.json(metadata);
  } catch (error) {
    console.error("ExifTool Error:", error);
    res.status(500).json({ error: error.message });
  }
});

// Endpoint to get ExifTool version
app.get("/api/version", async (req, res) => {
  try {
    const version = await exiftool.version();
    res.json({ version });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.listen(port, () => {
  console.log(`ExifTool Backend running at http://localhost:${port}`);
});

// Process cleanup on exit
process.on("SIGINT", async () => {
  await exiftool.end();
  process.exit();
});
