# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is exiftool-vendored.js, a Node.js library that provides cross-platform access to ExifTool for reading and writing metadata in photos and videos. The library includes comprehensive TypeScript type definitions for metadata tags and is used by PhotoStructure and 500+ other projects.

## Key Commands

```bash
# Development
npm install          # Install dependencies
npm run compile      # Compile TypeScript to JavaScript
npm run compile:watch # Watch mode for development
npm run clean        # Clean build artifacts
npm run u           # Update dependencies and install

# Linting & Formatting
npm run lint        # Run ESLint with TypeScript configuration
npm run fmt         # Format all TypeScript and other files with Prettier

# Testing (requires compilation first)
npm test            # Run all tests
npm run compile && npx mocha dist/ExifTool.spec.js  # Run specific test file
npm run compile && npx mocha 'dist/*.spec.js' --grep "pattern"  # Run tests matching pattern

# Documentation
npm run docs        # Generate TypeDoc docs and serve at http://localhost:3000
npm run docs:build  # Build documentation only (without serving)

# Tag Generation
npm run mktags ../path/to/images  # Regenerate src/Tags.ts and data/TagMetadata.json (with frequency, mainstream flags, and groups) from sample images

# Release Management
npm run release     # Run release process (requires proper permissions)
```

**Note**: Documentation is automatically built and deployed to GitHub Pages on every push to main branch via `.github/workflows/docs.yml`.

## Architecture & Key Concepts

**Core Components**: `ExifTool` class (`src/ExifTool.ts`) wraps ExifTool process management using batch-cluster. `Tags` interface (`src/Tags.ts`) contains ~2000 auto-generated metadata fields with popularity ratings. Custom date/time classes (`ExifDate`, `ExifTime`, `ExifDateTime`) handle timezone complexities. Task system includes `ReadTask`, `WriteTask`, `BinaryExtractionTask`, and `RewriteAllTagsTask`. Platform-specific binaries via optional dependencies.

**Process Management**: Uses [batch-cluster](https://photostructure.github.io/batch-cluster.js/) with configurable `maxProcs`, `minDelayBetweenSpawnMillis`, and `streamFlushMillis`. Singleton `exiftool` instance configured conservatively.

**Timezone Handling**: Sophisticated heuristics using explicit timezone metadata, GPS location inference, UTC timestamp deltas, and daylight saving transitions.

**Tag Generation**: `mktags.ts` analyzes sample images to generate TypeScript interfaces with ~2000 most common tags and popularity ratings.

**Testing**: Mocha with Chai assertions, unit/integration tests, test images in `test/` directory including non-English filenames.

## Important Notes

- Always run `npm run compile` before testing
- As of v35, `.end()` is optional for scripts (Node.js exits naturally), but recommended for long-running apps
- Tag interfaces not comprehensive - less common tags may exist in returned objects
- Uses batch processing with automatic process pool management
- TypeScript union type limits require careful tag selection

## TypeScript Hygiene

- Use `if (x != null)` not `if (x)` (problematic with booleans)
- Use `??` not `||` for nullish coalescing (problematic with booleans)
- Strict TypeScript settings enabled
- Always use standard imports at the top of the file. Never use dynamic imports like `await import("node:fs/promises").then(fs => fs.access(path))` - instead import normally: `import { access } from "node:fs/promises"`

**File Patterns**: `src/*.ts` (source), `src/*.spec.ts` (tests), `src/update/*.ts` (scripts), `bin/` (binaries), `dist/` (compiled), `test/` (test images)
