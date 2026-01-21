# Releasing new versions of `exiftool-vendored`

As of May 2025, the Windows
[exiftool-vendored.exe](https://github.com/photostructure/exiftool-vendored.exe)
and POSIX
[exiftool-vendored.pl](https://github.com/photostructure/exiftool-vendored.pl)
vendored versions of ExifTool are updated and released automatically.

## Automated Dependency Updates

A GitHub Actions workflow automatically checks for dependency updates (including ExifTool packages) periodically and creates pull requests when updates are available. The workflow:

- Updates all dependencies using `npm-check-updates`
- Creates a pull request with signed commits
- Includes a detailed diff of changes
- Allows manual approval and merging
- Can also be triggered manually via the Actions tab

## Release Process

### Prerequisites

Before releasing, ensure you have:

1. Configured [npm Trusted Publishing](https://docs.npmjs.com/trusted-publishers) for this repository on npmjs.com
2. Access to trigger GitHub Actions workflows

### Automatic Release (Recommended)

Releases are now handled through GitHub Actions with OIDC trusted publishing:

1. Ensure all changes are committed and pushed to `main`
2. Update the [CHANGELOG.md](https://github.com/photostructure/exiftool-vendored.js/blob/main/CHANGELOG.md)
3. Go to the [Build & Release workflow](https://github.com/photostructure/exiftool-vendored.js/actions/workflows/build.yml)
4. Click "Run workflow" and select the version type (patch/minor/major)
5. The workflow will:
   - Run the full test matrix (3 OS × 3 Node versions)
   - Only proceed with release if all tests pass
   - Use OIDC for secure, token-free npm publishing
   - Create a GitHub release
6. Copy the relevant CHANGELOG entries into the new GitHub Release. [Here's an example](https://github.com/photostructure/exiftool-vendored.js/releases/tag/30.0.0).

### Manual Development Process

For development and testing:

1. `git clone` this repo
2. `npm install`
3. `npm run mktags ../test-images` # < assumes `../test-images` has the full ExifTool sample image suite
4. `npm run precommit` (look for lint or documentation generation issues)
5. `npm run test`
6. Verify diffs are reasonable, `git commit` and `git push`
7. Follow the Automatic Release steps above
