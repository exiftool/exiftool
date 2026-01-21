import { exiftool } from "exiftool-vendored";
import fs from "fs";
import path from "path";

async function scan() {
  const dir = "./t/images";
  const files = fs.readdirSync(dir);
  console.log(`Scanning ${files.length} files in ${dir}...`);

  for (const file of files) {
    const filePath = path.join(dir, file);
    try {
      const metadata = await exiftool.read(filePath);
      if (
        metadata.GPSLatitude ||
        metadata.GPSPosition ||
        metadata.GPSLongitude
      ) {
        console.log(`[FOUND GPS] ${file}`);
        console.log(`  - Latitude: ${metadata.GPSLatitude}`);
        console.log(`  - Longitude: ${metadata.GPSLongitude}`);
        console.log(`  - Position: ${metadata.GPSPosition}`);
      }
    } catch (e) {
      // Skip files that can't be read
    }
  }
  await exiftool.end();
}

scan();
