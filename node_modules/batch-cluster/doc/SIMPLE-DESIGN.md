# Simple Design Principles

Kent Beck's Four Rules of Simple Design, plus a fifth rule for child process management. Lower-numbered rules take precedence when they conflict.

## Quick Reference

1. **Passes the tests** — Proven correct through automated tests
2. **Reveals intention** — Names and structure express purpose
3. **No duplication** — Logic exists in exactly one place
4. **Fewest elements** — No unused or speculative code
5. **Fail fast** — Errors propagate visibly, never hidden by defaults

---

## Rule 1: Passes the Tests

Working code beats everything else. This rule is first because testing isn't an afterthought—it's how we prove correctness and gain confidence to refactor.

**Example**: Before optimizing task queuing or process pool management, comprehensive tests must prove correctness across all child process lifecycle states and error conditions.

**Pitfall**: Don't skip tests for "simple" changes. Child process management has platform-specific edge cases (Windows antivirus delays, Linux signal handling, macOS sandbox restrictions) that only surface under specific conditions.

## Rule 2: Reveals Intention

Programs are written for people to read. Clear code helps future maintainers grasp what you intended and why.

**Example**: Methods like `execTask()` and `whyNotHealthy()` describe what they do. Generic names like `run()` or `check()` obscure the process management domain.

**Pitfall**: Don't hide complexity behind vague abstractions. If a method manages process lifecycle, name it accordingly.

## Rule 3: No Duplication

Perhaps the most powerfully subtle rule. Eliminating redundancy—not just copy-paste code, but duplicated knowledge and concepts—naturally drives out good design through the refactoring process.

**Example**: `StreamHandler` exists because stdout and stderr handling looked similar but had subtle timing differences that caused bugs when duplicated in `BatchProcess`.

**Pitfall**: Don't create premature abstractions. Temporary duplication is acceptable while understanding emerges, especially for platform-specific behavior that may later diverge.

## Rule 4: Fewest Elements

Remove anything that doesn't serve Rules 1-3. This counters the temptation to add architectural complexity "for future flexibility"—which usually makes systems harder to modify, not easier.

**Example**: The library deliberately omits built-in retry logic. Don't build frameworks for speculative future needs.

**Pitfall**: Don't over-apply this rule. Process lifecycle management, cross-platform signal handling, and stream synchronization have inherent complexity that can't be simplified away.

## Rule 5: Fail Fast (Project-Specific)

When assumptions your code relies upon appear broken, fail early and visibly:

- Propagate errors to callers instead of catching and warning
- If data should always exist, assume it does—unnecessary guardrails mislead maintainers
- Never use defaults as error recovery

**Example**: If `proc.pid` is null after spawn, throw immediately. A null PID means something is fundamentally broken—no fallback will help.

```typescript
// Good: fail immediately
if (proc.pid == null) {
  throw new Error("spawn failed: no pid");
}

// Bad: mask the problem
if (proc.pid == null) {
  this.logger.warn("no pid, continuing anyway...");
  return; // Now the real failure surfaces somewhere else, harder to debug
}
```

---

## When Rules Conflict

Rules 2 and 3 feed off each other—good names often reveal hidden duplication, and eliminating duplication often suggests better names. Their ordering rarely matters in practice.

When they do conflict (mainly in test code), Beck says "empathy wins over some strictly technical metric." Clarity for the reader takes precedence.

**Common pattern**: Temporarily duplicate code to keep tests passing, then refactor to eliminate duplication while improving names.

## How These Rules Apply Here

- **Process Reliability**: Rule 1 ensures child processes spawn, run, and terminate correctly across all platforms
- **Stream Handling**: Rule 2 makes stdin/stdout/stderr coordination and the pass/fail token protocol understandable
- **Shared Utilities**: Rule 3 consolidates timeout logic, rate limiting, and health checks
- **Minimal Scope**: Rule 4 keeps us focused on process pooling without speculative features
- **Fail Fast**: Rule 5 catches process failures early rather than masking them

---

_Based on [Martin Fowler's summary](https://martinfowler.com/bliki/BeckDesignRules.html) of Kent Beck's rules from Extreme Programming._
