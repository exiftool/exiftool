# Test-Driven Development and Bug Fixing

## Mandatory Bug-Fixing Workflow

When a bug or defect is discovered, you **MUST** follow this exact sequence:

### 1. Create a Breaking Test

Write a test that reproduces the issue:

- Clearly isolate the problematic behavior
- Use minimal test data that triggers the bug
- Give it a descriptive name explaining what should work

### 2. Validate the Test Fails

Run the test to confirm it fails for the exact reason you expect:

- Must fail due to the bug, not test setup issues
- Verify failure mode matches the reported issue (and isn't exposing yet another bug, or making an invalid assertion)

### 3. Address the Bug

Fix the underlying issue:

- Consider cross-platform implications (Windows, macOS, Linux)
- Document any platform-specific behavior differences

### 4. Validate the Test Passes

Confirm the fix works:

- Test now passes completely
- Run full test suite (`npm t`) to ensure no regressions

## Test Design Principles

- **Isolation**: One test per issue, minimal test data
- **Clarity**: Descriptive names, comments explaining the issue
- **Reproducibility**: Consistent, deterministic test data
- **Platform awareness**: Consider timing differences across OS/hardware

## Testing Considerations for batch-cluster

When fixing bugs:

1. **Avoid mocks and stubs**: [test.ts](../src/test.ts) simulates a batch-mode CLI tool with configurable failure rates and behaviors. See [\_chai.spec.ts](../src/_chai.spec.ts) for test helpers.
2. **Account for timing**: CI environments may be slower. See existing tests for timeout and `isCI` patterns.
3. **Test process lifecycle**: Verify behavior across spawn, execution, and termination phases
4. **Check stream handling**: Ensure stdout/stderr coordination works with various `streamFlushMillis` values
5. **Validate against consumers**: [exiftool-vendored](https://github.com/photostructure/exiftool-vendored.js) is the primary consumer—consider its usage patterns
