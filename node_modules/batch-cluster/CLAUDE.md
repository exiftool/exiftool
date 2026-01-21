# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Development Commands

### Build & Development

- `npm install` - Install dependencies
- `npm run compile` - Compile TypeScript to JavaScript (outputs to dist/)
- `npm run watch` - Watch mode for TypeScript compilation
- `npm run clean` - Clean build artifacts

### Testing & Quality

- `npm test` - Run all tests (includes linting and compilation)
- `npm run lint` - Run ESLint on TypeScript source files
- `npm run fmt` - Format code with Prettier
- `mocha dist/**/*.spec.js` - Run specific test files after compilation
- `npx mocha --require ts-node/register src/Object.spec.ts` - Run individual tests like this

### Documentation

- `npm run docs` - Generate and serve TypeDoc documentation

## Architecture Overview

This library manages clusters of child processes to efficiently handle batch operations through stdin/stdout communication. Key architectural concepts:

### Core Components

1. **BatchCluster** (`src/BatchCluster.ts`) - Main entry point that manages a pool of child processes
   - Handles process lifecycle, task queuing, and load balancing
   - Monitors process health and automatically recycles processes
   - Emits events for monitoring and debugging

2. **BatchProcess** (`src/BatchProcess.ts`) - Wrapper around individual child processes
   - Manages communication with a single child process
   - Tracks process state, health, and task processing
   - Handles process recycling based on task count or runtime

3. **Task** (`src/Task.ts`) - Represents a unit of work to be processed
   - Contains the command to send to child process
   - Includes parser for processing responses
   - Manages timeouts and completion promises

### Key Patterns

- **Parser Interface** - Consumers must implement parsers to handle child process output
- **Deferred Pattern** - Used extensively for promise-based task completion
- **Rate Monitoring** - Tracks error rates to prevent runaway failures
- **Process Recycling** - Automatic process replacement after N tasks or N seconds

### Testing Approach

The test suite uses a custom test script (`src/test.ts`) that simulates a batch-mode command-line tool with configurable failure rates. Tests can control:

- `failrate` - Probability of task failure
- `rngseed` - Seed for deterministic randomness
- `ignoreExit` - Whether to ignore termination signals

## TypeScript Configuration

- Strict mode enabled with all strict checks
- Targets ES2019, CommonJS modules
- Outputs to `dist/` with source maps and declarations
- No implicit any, strict null checks, no unchecked indexed access

## Code Style Guidelines

- **Null checks**: Always use explicit `x == null` or `x != null` checks. Do not use falsy/truthy checks for nullish values.
  - Good: `if (value != null)`, `if (value == null)`
  - Bad: `if (value)`, `if (!value)`
