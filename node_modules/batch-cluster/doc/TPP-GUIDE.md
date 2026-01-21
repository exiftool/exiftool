# Technical Project Plan (TPP) Guide

## Purpose

A TPP transfers expertise, not just instructions. A great TPP lets another engineer complete the work without asking questions—even if the code changed since you wrote it.

**The golden rule**: If an implementer fails because context was missing from your TPP, that's your failure, not theirs.

## Required Reading

Before writing any TPP, read and incorporate:

- **[SIMPLE-DESIGN.md](./SIMPLE-DESIGN.md)**: Kent Beck's Four Rules guide all design decisions
- **[TDD.md](./TDD.md)**: Bug fixes MUST start with a failing test

These are not optional. TPPs that ignore them will be rejected.

## TPP Structure

### Part 1: Define Success (5 minutes max)

Write one clear sentence for each:

```markdown
**Problem**: Tasks hang when child process exits unexpectedly during execution
**Why it matters**: Consumers see Promise never resolving, causing memory leaks
**Solution**: Detect process exit and reject pending task with clear error
**Success test**: `npm t -- --grep "process exit during task"`
**Key constraint**: Must not break graceful shutdown behavior
```

This is your North Star. Implementation details may change; the user need stays constant.

**For bug fixes** (per [TDD.md](./TDD.md)):

```markdown
**Bug**: streamFlushMillis too low causes task data loss on slow systems
**Reproducing test**: `npm t -- --grep "stream flush timing"` (currently fails)
**Root cause**: stdout/stderr not fully flushed before task resolution
**Fix approach**: Increase platform-specific defaults based on CI observations
```

#### When TDD Isn't Possible

Some bugs can't be reproduced in tests:

- Race conditions requiring precise timing between process events
- Platform-specific signal handling (SIGTERM vs SIGKILL behavior)
- Antivirus interference on Windows during process spawn
- OS-level resource exhaustion (file descriptors, memory)

For these, document explicitly:

```markdown
**Bug**: Zombie processes on Linux when parent terminates abnormally
**Why untestable**: Requires killing test harness mid-execution
**Validation approach**:

1. Code review showing cleanup logic matches known-good pattern
2. Manual testing with `kill -9` of parent process
3. `grep` showing fix applied to ALL process termination paths
```

Don't pretend a test covers something it doesn't. Be explicit about what's validated and what isn't.

### Part 2: Share Your Expertise

This section prevents surprises. Skip it for straightforward changes—document only what's non-obvious.

#### A. Find the Patterns

Show what already works similarly:

```bash
# Find existing patterns
grep -r "Deferred" src/*.ts
grep -r "onIdle" src/BatchCluster.ts src/BatchProcess.ts

# Check process lifecycle handling
grep -rn "proc.on" src/BatchProcess.ts
```

Document what you find:

- "Copy pattern from `src/BatchProcess.ts:107-119` for process event handling"
- "Use `Deferred` pattern from `src/Deferred.ts` for promise-based completion"

#### B. Document the Landmines

Share what will break and why:

```bash
# Find dependencies on current implementation
grep -r "BatchProcess" src/*.ts  # Tests are in src/ as *.spec.ts
npm t 2>&1 | grep -i "timeout"  # Tests that catch timing issues
```

Document the dangers:

- "Windows requires longer `streamFlushMillis`—antivirus can delay streams by 100ms+"
- "Never assume `proc.pid` is defined—check null after spawn"
- "Process events (close/exit/disconnect) can fire in any order—handle all three"
- "Don't block the event loop during process termination—use `setImmediate`"

**Apply SIMPLE-DESIGN.md Rule 2 (Reveals Intention)**: Don't just say "this breaks"—explain why it was designed this way.

#### C. Plan for Change

If architecture changes, how should the implementer adapt?

```markdown
If ProcessPoolManager was refactored:

1. User need unchanged (manage pool of child processes)
2. Find new pool: `grep -r "class.*Pool\|class.*Manager" src/`
3. Core goal: spawn, monitor, and recycle child processes
```

### Part 3: Define Clear Tasks

Each task needs:

- **What success looks like** (with proof command)
- **How to implement** (with specific locations)
- **How to adapt** (if architecture changed)

```markdown
### Task: Fix task timeout not clearing on completion

**Success**: `npm t -- --grep "task timeout"` passes

**Implementation**:

1. Find timeout handling in `src/BatchProcess.ts`
2. Check `#currentTaskTimeout` is cleared in all completion paths
3. Add `clearTimeout` call before task resolution

**If architecture changed**:

- No BatchProcess? Find task execution: `grep -r "execTask\|runTask" src/`
- Timeout renamed? Find timer handling: `grep -r "Timeout\|setTimeout" src/`

**Proof of completion** (follows [SIMPLE-DESIGN.md](./SIMPLE-DESIGN.md) Rule 1):

- [ ] Test passes: `npm t -- --grep "task timeout"`
- [ ] Behavior verified: Task completes without lingering timeout
- [ ] Old code removed: No redundant timeout checks (Rule 4 - fewest elements)
```

## batch-cluster Specific Concerns

### Process Lifecycle Is Non-Negotiable

Every process state transition must be handled:

```typescript
// All process events must be handled
proc.on("error", (err) => this.#onError("proc.error", err));
proc.on("close", () => void this.end(false, "proc.close"));
proc.on("exit", () => void this.end(false, "proc.exit"));
proc.on("disconnect", () => void this.end(false, "proc.disconnect"));
```

### Stream Coordination Is Critical

stdout and stderr must be synchronized:

```typescript
// Parser receives both streams—order matters
export type Parser<T> = (
  stdout: string,
  stderr: string | undefined,
  passed: boolean,
) => T | Promise<T>;

// streamFlushMillis ensures both streams complete before parsing
```

### Platform-Specific Gotchas to Document

When your task involves process management, document these traps:

| Issue                       | Symptom                    | Solution                                            |
| --------------------------- | -------------------------- | --------------------------------------------------- |
| Windows antivirus           | Spawn takes 5+ seconds     | Set generous `spawnTimeoutMillis` (15s default)     |
| Stream flush timing         | Parser sees partial data   | Platform-specific `streamFlushMillis` defaults      |
| Signal handling differences | SIGTERM ignored on Windows | Use process.kill() with platform-appropriate signal |
| File descriptor exhaustion  | EMFILE errors under load   | Limit `maxProcs`, ensure cleanup                    |
| Zombie processes            | PIDs accumulate over time  | PID checking via `pidCheckIntervalMillis`           |

### Platform-Specific Failures

Document when behavior varies:

```markdown
**Windows**: Antivirus can delay spawn by seconds—use generous timeouts
**Windows**: No SIGTERM support—only SIGKILL works reliably
**Linux**: Process groups may need explicit cleanup
**macOS**: VM performance varies in CI—avoid exact timing assertions
**Alpine ARM64**: 10x slower in CI—use `getTestTimeout()` for timing tests
```

## Anti-Patterns to Avoid

### "It Works" Without Proof

Bad: "I tested it and it works"
Good: "Test passes: `npm t -- --grep 'specific test name'`"

### Shelf-ware Code

Implementation exists but nothing uses it. Every feature needs integration proof:

```bash
# Prove production usage
grep -r "newFunction" src/  # Must appear in both src and *.spec.ts files
```

### The 95% Trap

"Just needs cleanup" = 50% more work. Tasks are complete or incomplete—no percentages.

### Bogus Guardrails

Per [SIMPLE-DESIGN.md](./SIMPLE-DESIGN.md) Rule 5: Don't add defensive code for impossible cases. If assumptions are violated, fail visibly.

### Testing the Wrong Thing

Bad: "Added test for process termination" (but test only checks graceful exit, not forced kill)

Good: "Added regression test for graceful shutdown. The forced termination edge case is untestable in CI—validated via code review against `ProcessTerminator.ts:45-60`"

Be precise about what your test actually validates vs. what remains validated only by code review.

## Validation Requirements

### Required Evidence Types

Every checkbox needs proof another engineer can verify:

- **Commands that pass**: `npm t`, `npm run lint`, etc.
- **Code locations**: `src/BatchProcess.ts:234` where implementation exists
- **Integration proof**: `grep` commands showing production usage
- **Platform testing**: Note which platforms were verified

### Completeness Validation

For fixes that apply to multiple locations, the TPP must include a scope check:

```bash
# Example: Find ALL places that handle process events
grep -rn "proc.on\|\.on(\"error\|\.on(\"exit" src/*.ts
```

A fix for one event that misses others is incomplete. Document:

- How many locations need the fix
- Which files contain them
- Validation that ALL were addressed

### Definition of Complete

A task is complete when:

1. System behavior changes (provable with command)
2. Old workaround code removed
3. New capability used in production paths
4. All validation commands pass
5. `npm t` shows no regressions

### Common Over-Selling Patterns

Do NOT mark complete if:

- "Tests pass" but only for new code, not full suite
- "Implementation works" but no integration proof
- "Ready for review" but `npm run lint` fails
- "Feature complete" but old path still active

## Quality Checklist

Before marking your TPP ready:

- [ ] Problem and success fit in one paragraph
- [ ] Included commands that find relevant code
- [ ] Documented at least one "learned the hard way" lesson
- [ ] Each task has verifiable success command
- [ ] Explained how to adapt if code was refactored
- [ ] Bug fixes start with failing test ([TDD.md](./TDD.md))—or document why TDD isn't possible
- [ ] Code follows Four Rules ([SIMPLE-DESIGN.md](./SIMPLE-DESIGN.md))
- [ ] Platform-specific behavior documented
- [ ] If fix applies to multiple locations, included grep to find ALL instances
- [ ] Test descriptions clarify what IS and ISN'T covered

## The Ultimate Test

Hand this TPP to someone unfamiliar with the codebase. If they can implement the solution without asking questions—even if the code was refactored—you've written an excellent TPP.

## TPP Template

Copy this structure for new TPPs--but omit sections that aren't relevant or helpful.

```markdown
# TPP: [Specific Project Name]

## Goal Definition

- **What Success Looks Like**: [1 sentence]
- **Core Problem**: [1 sentence]
- **Key Constraints**: [1 sentence—include platform considerations]
- **Success Validation**: [1 sentence—include test command]

## Context Research

### Existing Patterns

[What similar code exists? Where?]

### Landmines

[What breaks easily? Platform gotchas? Timing issues?]

### Process Lifecycle Considerations

[How does this interact with spawn/termination/recycling?]

## Tasks

### Don't blindly follow this section!

**It is your responsibility to complete (or at least make progress towards) this TPP's goal.**

These tasks were what seemed to be the best course of action at planning time.

As additional research and implementation details are completed, reconsider these task breakdowns and overall solution. If a new path can better follow ./SIMPLE-DESIGN.md, ask to revise the task breakdown and present the pros and cons of each approach.

### Task 1: [Name]

**Success**: `[test command]`

**Implementation**:

1. [Step with file:line]
2. [Step]

**If architecture changed**:

- [How to find new location]

**What this test validates** (be precise):

- [ ] [What the test DOES cover]
- [ ] [What remains validated only by code review]

**Completion checklist**:

- [ ] Test passes: `npm t -- --grep "..."`
- [ ] Integration shown: `grep -r "..." src/`
- [ ] Old code removed
- [ ] ALL similar locations fixed (if applicable): `grep -rn "pattern" src/`

### Task 2: ...

## Validation

- [ ] All tests pass: `npm t`
- [ ] Linting passes: `npm run lint`
- [ ] Works on target platforms (note which were tested)
```

## File Naming

Place TPPs in `doc/todo/${priority}-${desc}.md` during work, move to `doc/done/${date}-${priority}-${desc}.md` when complete:

```
doc/todo/P01-fix-task-timeout.md       # Priority 01, in progress
doc/done/20250115-P01-fix-timeout.md   # Completed with date prefix
```

Priority: P00 (critical) through P99 (nice-to-have).
