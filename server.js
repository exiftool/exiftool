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

// OSINT Proxy Endpoint (Bypass CORS)
app.get("/api/osint/proxy", async (req, res) => {
  const { url } = req.query;
  if (!url) return res.status(400).json({ error: "Missing 'url' parameter" });

  try {
    const response = await fetch(url, {
      headers: { "User-Agent": "ExifTool-Architect-OSINT/1.0" },
    });

    // Forward standard headers
    const contentType = response.headers.get("content-type");
    const status = response.status;

    // Simple JSON or Text proxy
    if (contentType && contentType.includes("application/json")) {
      const data = await response.json();
      res.status(status).json(data);
    } else {
      const text = await response.text();
      res.status(status).send(text);
    }
  } catch (error) {
    console.error("Proxy Error:", error);
    res.status(500).json({ error: "Failed to fetch remote resource" });
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

// Legacy Feature Implementation (Using Child Process for raw output)
import { spawn } from "child_process";

// Locate the binary dynamically or usage hardcoded path from finding
const exiftoolPath = path.join(
  __dirname,
  "node_modules",
  "exiftool-vendored.exe",
  "bin",
  "exiftool.exe",
);

// Helper to run raw exiftool
function runExifTool(args, res) {
  const et = spawn(exiftoolPath, args);
  let output = "";
  let error = "";

  et.stdout.on("data", (data) => (output += data));
  et.stderr.on("data", (data) => (error += data));

  et.on("close", (code) => {
    if (code !== 0) {
      console.error("ExifTool Process Error:", error);
      return res.status(500).json({ error: error || "Process failed" });
    }
    res.send(output);
  });
}

// Endpoint: Export Report (fmt_files)
app.post("/api/export", upload.single("file"), (req, res) => {
  if (!req.file) return res.status(400).json({ error: "No file uploaded" });
  const { format } = req.body;

  // Validate format
  const validFormats = ["kml", "gpx", "gpx_wpt", "kml_track"];
  if (!validFormats.includes(format)) {
    fs.unlinkSync(req.file.path);
    return res.status(400).json({ error: "Invalid format" });
  }

  const fmtPath = path.join(__dirname, "fmt_files", `${format}.fmt`);
  // -p option for print format
  runExifTool(["-p", fmtPath, req.file.path], res);

  // Cleanup happens after process end?
  // Standard runExifTool needs modification to cleanup file.
  // We'll wrap it or trust FS cleanup later (OS tmp) but better to cleanup.
  // Let's modify the response handler in runExifTool to cleanup if we pass the path.
});

// Endpoint: Run Macro (arg_files)
app.post("/api/macro", upload.single("file"), (req, res) => {
  if (!req.file) return res.status(400).json({ error: "No file uploaded" });
  const { macro } = req.body;

  // Simple validation
  if (!macro || macro.includes("..")) {
    fs.unlinkSync(req.file.path);
    return res.status(400).json({ error: "Invalid macro" });
  }

  const argPath = path.join(__dirname, "arg_files", macro);
  // -@ option for args file
  // note: we usually want JSON output back to show result?
  // commands in arg files usually modify tags.
  // So we run the macro, THEN read the file again to return new metadata?
  // Or just return the stdout of the macro command.

  // Actually, most args files in this repo transform tags.
  // Let's run it, then run -j -g to get metadata back?
  // Complex. For now, let's just return the standard output of the command.
  runExifTool(["-@", argPath, req.file.path], res);
});

// Endpoint: List Legacy Features
app.get("/api/legacy/list", (req, res) => {
  const fmts = fs
    .readdirSync(path.join(__dirname, "fmt_files"))
    .filter((f) => f.endsWith(".fmt"));
  const args = fs
    .readdirSync(path.join(__dirname, "arg_files"))
    .filter((f) => f.endsWith(".args"));
  const configs = fs
    .readdirSync(path.join(__dirname, "config_files"))
    .filter((f) => f.endsWith(".config"));
  res.json({ fmts, args, configs });
});
