# Changelog

## Versioning

See [Semver](http://semver.org/).

### The `MAJOR` or `API` version is incremented for

- 💔 Non-backwards-compatible API changes

### The `MINOR` or `UPDATE` version is incremented for

- ✨ Backwards-compatible features

### The `PATCH` version is incremented for

- 🐞 Backwards-compatible bug fixes

- 📦 Minor packaging changes
-

## [v17.1.0](https://github.com/photostructure/batch-cluster.js/releases/tag/v17.1.0)

- ✨ Added `cleanupChildProcsOnExit` option (defaults to `true`) to control whether BatchCluster registers `beforeExit` and `exit` handlers for automatic child process cleanup.

  Set to `false` if you want to manage process cleanup yourself, or if these handlers interfere with your application's exit behavior.

- 🐞 Fixed the `exit` handler to synchronously kill child processes. The previous implementation called an async method, which doesn't work in `exit` handlers (only synchronous operations are allowed).

## [v17.0.0](https://github.com/photostructure/batch-cluster.js/releases/tag/v17.0.0)

- 💔 **BREAKING**: Added `unrefStreams` option (defaults to `true`) that unreferences child process stdio streams.

  Previously, even though `proc.unref()` was called on child processes, the stdio streams (stdin, stdout, stderr) kept the parent Node.js process alive, requiring explicit `.end()` calls.

  With `unrefStreams: true` (the new default), scripts can now exit naturally without calling `.end()`. Child processes are cleaned up automatically when the parent exits.

  To restore the previous behavior where the parent process stays alive until `.end()` is called:

  ```typescript
  new BatchCluster({ unrefStreams: false, ... });
  ```

  Fixes [exiftool-vendored#319](https://github.com/photostructure/exiftool-vendored.js/discussions/319).

## [v16.0.0](https://github.com/photostructure/batch-cluster.js/releases/tag/v16.0.0)

- 💔 **BREAKING**: Removed `maxReasonableProcessFailuresPerMinute` option and fatal shutdown on spawn failures.

  Spawn failures now log warnings and retry (rate-limited by `minDelayBetweenSpawnMillis`) instead of calling `endCluster()`. This fixes [exiftool-vendored#312](https://github.com/photostructure/exiftool-vendored.js/issues/312) where task timeouts were incorrectly triggering cluster shutdown.

  Also removed: `startErrorRatePerMinute` from stats, `endCluster` callback from `BatchClusterEventCoordinator`.

- 💔 **BREAKING**: `fatalError` event was removed (as it is never broadcast anymore--see above!)

- 💔 **BREAKING**: Changed the default value of `taskTimeoutMillis` from 10 seconds to 0 (disabled).

  There is no universally safe default for task timeouts--the appropriate value depends entirely on your application's workload. A 10-second default could cause legitimate long-running tasks (like, hypothetically, extraction of embedded metadata in videos) to fail unnecessarily.

  If you rely on task timeouts, explicitly set `taskTimeoutMillis` to a value appropriate for your use case (2-10x longer than expected task duration under typical load).

- 💔 **BREAKING**: Removed unused `Rate` class

- 💔 TypeScript compilation now targets ES2022 with ESNext.Disposable. This _shouldn't_ impact anyone, as we already require Node.js v20+.

- 📦 Added Node.js v25 to the test matrix

- 🐞 Fixed: `stdin.write()` errors now properly end the process instead of leaving a broken process in the pool

## [v15.0.1](https://github.com/photostructure/batch-cluster.js/releases/tag/v15.0.1)

"This time, with feeling"

- 📦 v15.0.0 automated the release to use OIDC 👍, but the `compile` prerequisite was missed 🤦, so v15.0.0 has _no code in it_ 🪹. v15.0.1 is _better_! It _has code_!

## [v15.0.0](https://github.com/photostructure/batch-cluster.js/releases/tag/v15.0.0)

- 💔 Deleted the standalone `pids()` function and associated code (including the ProcpsChecker). This function was exported but only used internally by tests. This fixes the [issue #58](https://github.com/photostructure/batch-cluster.js/issues/58) (by deleting the unused code! _the best kind of bugfix_). Thanks for the report, [Zaczero](https://github.com/Zaczero)!

- 💔 Dropped official support for [Node v23, which is EOL](https://nodejs.org/en/about/previous-releases).

- 📦 Simplified `prettier` config to accept all defaults -- this added semicolons to every file.

## [v14.0.0](https://github.com/photostructure/batch-cluster.js/releases/tag/v14.0.0)

- 💔 Dropped official support for Node v14, v16, and v18. Minimum Node.js version is now v20.

- ✨ Added startup validation for procps availability: `BatchCluster` now throws `ProcpsMissingError` during construction if the required `ps` command (or `tasklist` on Windows) is not available. This provides clear, actionable error messages instead of cryptic runtime failures. Resolves [#13](https://github.com/photostructure/batch-cluster.js/issues/13) and [#39](https://github.com/photostructure/batch-cluster.js/issues/39).

- 📦 Significant internal refactoring to improve maintainability:
  - Extracted process management logic into dedicated classes (`ProcessPoolManager`, `TaskQueueManager`, `ProcessHealthMonitor`, `StreamHandler`, `ProcessTerminator`)
  - Implemented strategy pattern for health checking logic
  - Improved type safety by replacing `any` with `unknown` throughout the codebase
  - Enhanced error handling and process lifecycle management

## [v13.0.0](https://github.com/photostructure/batch-cluster.js/releases/tag/v13.0.0)

- 💔 Dropped official support for [Node v16, which is EOL](https://nodejs.org/en/blog/announcements/nodejs16-eol/).

- 💔 Several methods, including BatchCluster#pids() were changed from async to sync (as they were needlessly async).

- 📦 A number of timeout options can now be validly 0 to disable timeouts:
  - `spawnTimeoutMillis`
  - `taskTimeoutMillis`

- 📦 Added eslint `@typescript-eslint/await-thenable` rule and delinted.

- 📦 Updated development dependencies and rebuilt docs

## [v12.1.0](https://github.com/photostructure/batch-cluster.js/releases/tag/v12.1.0)

- 🐞 `pidExists` now handles `EPERM` properly (previous implementation would
  mischaracterize pids as being dead due to insufficient permissions)

- 📦 Updated development dependencies and rebuilt docs

## [v12.0.0](https://github.com/photostructure/batch-cluster.js/releases/tag/v12.0.0)

- 💔/✨ `pidExists` and `killPid` are no longer `async`, as process management
  is now performed via `node:process.kill()`, instead of forking `ps` or `tasklist`.

- 📦 Updated development dependencies and rebuilt docs

## [v11.0.0](https://github.com/photostructure/batch-cluster.js/releases/tag/v11.0.0)

- 💔 Drop official support for Node 12: [EOL was 2022-04-30](https://github.com/nodejs/release#end-of-life-releases)

## [v10.4.3](https://github.com/photostructure/batch-cluster.js/releases/tag/v10.4.3)

- 🐞 Fix support for zero value of `maxProcAgeMillis`

- 📦 Updated development dependencies and rebuilt docs

## [v10.4.2](https://github.com/photostructure/batch-cluster.js/releases/tag/v10.4.2)

- 🐞 Fix [`unref` is not a function](https://github.com/photostructure/batch-cluster.js/issues/16)

- 📦 Updated development dependencies and rebuilt docs

## [v10.4.1](https://github.com/photostructure/batch-cluster.js/releases/tag/v10.4.1)

- 📦 Improved concurrent event `Rate` measurement.

## [v10.4.0](https://github.com/photostructure/batch-cluster.js/releases/tag/v10.4.0)

- ✨ If `healthCheckCommand` is set and any task fails, that child process will
  have a health check run before being put back into rotation.

- 📦 Updated development dependencies and rebuilt docs

## [v10.3.2](https://github.com/photostructure/batch-cluster.js/releases/tag/v10.3.2)

- 🐞 `BatchCluster#maybeSpawnProcs` in prior versions could spawn too many
  processes, especially if process startup was slow. Heuristics for when to
  spawn new processes now take into account pending task length and processes
  busy due to initial setup.

- 📦 `BatchCluster.vacuumProcs` returns a promise that is only fulfilled after
  all reaped child processes have completed `BatchProcess.#end`.

- 📦 `BatchProcess.whyNotHealthy` can now return `startError`.

- 📦 `childEnd` is now emitted only after the child process exits

- 📦 `BatchCluster.#onIdle` is debounced during the same event loop

- 📦 Added startup and shutdown spec assertions

- 📦 Updated development dependencies and rebuilt docs

## [v10.3.1](https://github.com/photostructure/batch-cluster.js/releases/tag/v10.3.1)

- 📦 Add `Rate.msSinceLastEvent`

- 📦 Adjusted `streamFlushMillis` to remove `onTaskData` errors in CI.

## [v10.3.0](https://github.com/photostructure/batch-cluster.js/releases/tag/v10.3.0)

- ✨ Exported `Rate`. You might like it.

- ✨ When child processes emit to `stdout` or `stderr` with no current task,
  prior versions would emit an `internalError`. These are now given their own
  new `noTaskData` events. Consumers may want to bump up `streamFlushMillis` if
  they see this in production.

- 🐞/📦 Increased defaults for `streamFlushMillis`, added tests to verify `noTaskData` events don't happen in CI.

- 📦 Normalized node imports

## v10.2.0

- ✨/📦 Set `minDelayBetweenSpawnMillis = 0` to fork child processes as soon as
  they are needed (rather than waiting between `spawn` calls)

- ✨/📦 Set `maxReasonableProcessFailuresPerMinute = 0` to disable process start
  error rate detection.

- ✨/📦 New `fatalError` event emitted when
  `maxReasonableProcessFailuresPerMinute` is exceeded and the instance shuts
  itself down.

- 📦 New simpler `Rate` implementation with better time decay handling

- 📦 Several jsdoc improvements, including exporting `WhyNotHeathy` and
  `WhyNotReady`

## v10.1.1

- 🐞 Fixed [issue
  #15](https://github.com/photostructure/batch-cluster.js/issues/15) by
  restoring the call to `#onIdleLater` when tasks settle.

- 🐞 Fixed issue with `setMaxProcs` which resulted in all idle processes being
  reaped

- 📦 The `idle` event was removed. _You weren't using it, though, so I'm not
  bumping major._

- 📦 Process shutdown is handled more gracefully with new `thenOrTimeout`
  (rather than the prior `Promise.race` call which resulted in a dangling
  timeout)

- 📦 Updated development dependencies and rebuilt docs

## v10.1.0

- 📦 `.end()` and `.closeChildProcesses()` closes all child processes in parallel

## v10.0.1

- 📦 Export `BatchProcess` interface

## v10.0.0

- ✨ Process state improvements

- 💔 Renamed event s/childExit/childEnd/
- 💔 `childEnd` and `childStart` events receive BatchProcess instances now
- 💔 Renamed healthy state s/dead/ended/
- 📦 Made BatchProcess.whyNotHealthy persistent
- 📦 Added several more WhyNotHealthy values
- 📦 Perf: filterInPlace and count use for loops rather than closures
- 📦 Added spec to verify `.end` rejects long-running pending tasks
- 📦 Updated development dependencies and rebuilt docs

## v9.1.0

- 🐞/📦 `BatchProcess` exposes a promise for the completion of the startup task,
  which `BatchCluster` now uses to immediately run `#onIdle` and pop off any
  pending work.

- 📦 Updated development dependencies and rebuild docs

## v9.0.1

- 📦 Don't emit `taskResolved` on startup tasks.

## v9.0.0

- 💔 The `BatchProcessObserver` signature was deleted, as `BatchClusterEmitter` is
  now typesafe. Consumers should not have used this signature directly, but in
  case anyone did, I bumped the major version.

- ✨ Added `BatchCluster.off` to unregister event listeners provided to `BatchCluster.on`.

- 📦 Private fields and methods now use [the `#` private
  prefix](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Classes/Private_class_fields)
  rather than the TypeScript `private` modifier.

- 📦 Minor tweaks (fixed several jsdoc errors, simplified some boolean logic,
  small reduction in promise chains, ...)

- 📦 Updated development dependencies and rebuild docs

## v8.1.0

- 📦 Added `BatchCluster.procCount` and `BatchCluster.setMaxProcs`, and new
  `BatchCluster.ChildEndCountType` which includes a new `tooMany` value, which
  is incremented when `setMaxProcs` is set to a smaller value.

- 📦 Updated development dependencies

## v8.0.1

- 🐞/📦 BatchProcess now end on spurious stderr/stdout, and reject tasks if ending.

- 📦 Relaxed default for `streamFlushMillis` to deflake CI

## v8.0.0

- 💔/📦 RegExp pass/fail strings are escaped (which could conceivably be a breaking change, hence the major version bump)

- 📦 Refactored stdout/stderr merging code and added more tests

- 📦 Added new "taskResolved" event

- 📦 Rebuild docs

- 📦 Updated development dependencies

## v7.2.1

- 📦 Relax typing for optional `BatchProcessOptions` fields

## v7.2.0

- 📦 Upgrade all dev dependencies. Pulling in new TypeScript 4.4 required [redoing all node imports](https://github.com/microsoft/TypeScript/issues/46027#issuecomment-926019016).

## v7.1.0

- ✨ Added `on("healthCheckError", err, proc)` event

- 🐞 Fixed process start lag (due to startup tasks not emitting an `.onIdle`)

- 🐞 Reworked when health checks were run, and add tests to validate failing health checks recycle children

- 📦 Rebuild docs

## v7.0.0

- 💔 Several fields were renamed to make things more consistent:
  - `BatchCluster.pendingTasks` was renamed to `BatchCluster.pendingTaskCount`.
  - A new `BatchCluster.pendingTasks` method now matches `BatchCluster.currentTasks`, which both return `Task[]`.
  - `BatchCluster.busyProcs` was renamed to `busyProcCount`.
  - `BatchCluster.spawnedProcs` was renamed to `spawnedProcCount`.

- ✨ Added support for "health checks" that run periodically on child processes.
  Both `healthCheckCommand` and `healthCheckIntervalMillis` must be set to
  enable this feature.

- ✨ New `pidCheckIntervalMillis` to verify internal child process state is kept
  in sync with the process table. Defaults to every 2 minutes. Will no-op if idle.

- ✨ New `BatchCluster.childEndCounts` to report why child processes were recycled (currently "dead" | "ending" | "closed" | "worn" | "idle" | "broken" | "old" | "timeout" )

- 📦 Cleaned up scheduling: the prior implementation generated a bunch of
  `Promise`s per idle period, which was rough on the GC. Use of `Mutex` is now
  relegated to tests.

- 📦 `tsconfig` now emits `ES2018` output and doesn't have `downlevelIteration`,
  which reduces the size of the generated javascript, but requires contemporary
  versions of Node.js.

- 📦 `BatchClusterOptions` doesn't mark fields as `readonly` anymore

- 📦 `Task` has a default type of `any` now.

## v6.2.1

- 📦 Added `BatchCluster.currentTasks`

## v6.2.0

- 📦 Updated development dependencies, which required handling undefined process ids.

## v6.1.0

- ✨ Added `BatchCluster.closeChildProcesses()` (ends child processes but doesn't `.end()` the BatchCluster instance)
- 📦 Updated development dependencies

## v6.0.2

- 📦 Include sourcemaps
- 📦 Updated development dependencies

## v6.0.1

- 📦 Updated development dependencies
- 📦 Renamed `main` branch
- 📦 Hopefully fixed all typedoc URL changes

## v6.0.0

No new features in v6: just a breaking change so we can fix an old name
collision that caused linting errors.

- 💔 Prior versions name-collided on `Logger`: both as an `interface` and as a
  pseudonamespace for logger factories. This made `eslint` grumpy, and if anyone
  actually used this bare-bones logger, it could have caused confusion.

  `Logger` now references _only the `interface`._

  The builder functions are now named `Log`.

- 📦 Updated development dependencies

## v5.11.3

- 📦 Updated development dependencies (primarily TypeScript 4.1)
- 📦 `Deferred.resolve` now requires an argument (as per the new Promise spec).
  As this is just a typing change (and `Deferred` is an internal
  implementation), I'm not bumping the major version.

## v5.11.2

- 📦 Updated development dependencies
- 📦 Minor delint/prettier reformat

## v5.11.1

- 📦 Updated development dependencies

## v5.11.0

- ✨ `BatchCluster` can now be created with a `Logger` thunk.
- 📦 De-linted
- 📦 Updated development dependencies
- 📦 Add Node v14 to build matrix

## v5.10.0

- ✨ New `maxIdleMsPerProcess` option: automatically shut down idle child
  processes to reduce system resource consumption. Defaults to `0`, which
  disables this feature (and prevents me from having to increment the major
  version!)
- 📦 Updated development dependencies

## v5.9.5

- 📦 Updated development dependencies
- 📦 Ran prettier (2.0.0 causes many no-op diffs due to changed defaults)

## v5.9.4

- 📦 Updated development dependencies

## v5.9.3

- 🐞 `BatchProcess`'s streams could cause an infinite loop on `.end()` when
  `stdout` was destroyed.
- 📦 Updated development dependencies

## v5.9.2

- 🐞 `BatchProcess.ready` now verifies the child process still exists
- 📦 Replace tslint with eslint
- 📦 Updated development dependencies

## v5.9.1

- 🐞 Errors after a process has shut down are logged and not propagated
- 📦 Updated development dependencies

## v5.9.0

- 🐞 Moved all async throws into observables (to prevent "This error originated
  either by throwing inside of an async function without a catch block, or by
  rejecting a promise which was not handled with .catch(). The promise rejected
  with the reason...")
- 📦 Updated development dependencies

## v5.8.0

- 🐞 Fixed issue where immediately closing a process before a pending task
  completed resulted in `Error: onExit(exit) called end()`
- 📦 Updated development dependencies

## v5.7.1

- 📦 `BatchCluster.end()` should return a `Deferred<void>`

## v5.7.0

- 🐞 Fixed issue where `onStartError` and `onTaskError` didn't get emitted.
- 📦 Updated development dependencies, rebuilt docs.
- 🐞 Deflaked CI tests with longer timeouts and less aggressive `shutdown()`
- 📦 Had to delete the macOS Travis tests. Travis has been terribly flaky, with
  unreproduceable spec failures.

## v5.6.8

- 📦 Updated development dependencies (new TypeScript)

## v5.6.7

- 📦 Updated development dependencies

## v5.6.6

- 📦 Updated development dependencies

## v5.6.5

- 📦 wrapped `stdin.write()` with try/catch that rejects the current task and
  closes the current process.
- 📦 wrapped `stdin.end()` with try/catch (as `.writable` isn't reliable)

## v5.6.4

- 📦 Updated development dependencies

## v5.6.3

- 📦 Moved to the PhotoStructure org. Updated URLs in docs.

## v5.6.2

- 📦 Updated development dependencies
- 📦 Removed trace and debug log calls in `BatchProcess` (which incurred GC
  overhead even when disabled)

## v5.6.1

- 📦 Expose `BatchCluster.options`. Note that the object is frozen at
  construction.

## v5.6.0

- 🐞/✨ `BatchProcess.end()` didn't correctly implement `gracefully` (which
  resulted in spurious `end(): called while not idle` errors), and allowed for
  multiple calls to destroy and disconnect from the child process, which may or
  may not have been ill-advised.

## v5.5.0

- ✨ Added `BatchCluster.isIdle`. Updated development dependencies. Deflaked CI by embiggening
- ✨ Added `BatchClusterOptions.cleanupChildProcs`, in case you want to handle
  process cleanup yourself.
- 📦 Updated development dependencies. Deflaked CI by embiggening timeouts.
- Happy 🥧 day.

## v5.4.0

- ✨ "wear-leveling" for processes. Previously, only the first-spawned child
  process would service most task requests, but that caused issues with (very)
  long-running tasks where the other child processes would be spooled off ram,
  and could time out when requested later.
- 🐞 `maxProcs` is respected again. In prior builds, if tasks were enqueued all
  at once, prior dispatch code would only spin 1 concurrent task at a time.
- 🐞 Multiple calls to `BatchProcess.end` would result in different promise
  resolution targets: the second call to `.end()` would resolve before the
  first. This was fixed.
- ✨
  [BatchProcessOptions](https://batch-cluster.js.org/classes/batchclusteroptions.html)'s
  `minDelayBetweenSpawnMillis` was added, to help relieve undue system load on
  startup. It defaults to 1.5 seconds and can be disabled by setting it to 0.

## v5.3.1

- 📦 Removed `Deferred`'s warn log messages.

## v5.3.0

- 🐞 `.pass` and `.fail` regex now support multiple line outputs per task.

## v5.2.0

- 🐞 [BatchProcessOptions](https://batch-cluster.js.org/classes/batchclusteroptions.html)`.pass`
  and `.fail` had poorly specified and implemented failure semantics. Prior
  implementations would capture a "failed" string, but not tell the task that
  the service returned a failure status.

  Task [Parser](https://batch-cluster.js.org/interfaces/parser.html)s already
  accept stdout and stderr, and are the "final word" in resolving or rejecting
  [Task](https://batch-cluster.js.org/classes/task.html)s.

  `v5.2.0` provides a boolean to Parser's callable indicating if the wrapped
  service returned pass or fail, and the Parser may return a Promise now, as
  well.

  There's a new `SimpleParser` implementation you can use that fails if `stderr`
  is non-blank or a stream matched the `.fail` pattern.

- 🐞 initial `BatchProcess` validation uses the new `SimpleParser` to verify the
  initial `versionCommand`.

- ✨ child process pids are delivered to event listeners on spawn and close. See
  [BatchClusterEmitter](https://batch-cluster.js.org/classes/batchclusteremitter.html).

- 🐞 fix "Error: end() called when not idle" by debouncing stdout and stderr
  readers. Note that this adds latency to every task. See
  [BatchProcessOptions](https://batch-cluster.js.org/classes/batchclusteroptions.html)'s
  `streamFlushMillis` option, which defaults to 10 milliseconds.

- 🐞 RegExp for pass and fail tokens handle newline edge cases now.

- 📦 re-added tslint and delinted code.

## v5.1.0

- ✨ `ChildProcessFactory` supports thunks that return either a `ChildProcess` or
  `Promise<ChildProcess>`
- 📦 Update deps

## v5.0.1

- 📦 Update deps
- 📦 re-run prettier

## v5.0.0

- 💔 The `rejectTaskOnStderr` API, which was added in v4.1.0 and applied to all
  tasks for a given `BatchCluster` instance, proved to be a poor decision, and
  has been removed. The `Parser` API, which is task-specific, now receives
  **both** stdin and stderr streams. Parsers then have the necessary context to
  decide what to do on a per task or per task-type basis.
- 🐞 In previous versions, batch processes were recycled if any task had any
  type of error. This version allows pids to live even if they emit data to
  stderr.

## v4.3.0

- ✨ If your tasks return interim progress and you want to capture that data
  as it happens, BatchCluster now emits `taskData` events with the data and the
  current task (which may be undefined) as soon as the stream data is emitted.
- 📦 Pulled in latest dependency versions

## v4.2.0

- 📦 In the interests of less noise, the default logger is now the `NoLogger`.
  Consumers may use the `ConsoleLogger` or another `Logger` implementation as
  they see fit.

## v4.1.0

- ✨ Support for demoting task errors from `stderr` emissions:
  `BatchProcess.rejectTaskOnStderr` is a per-task, per-error predicate which
  allows for a given error to be handled without always rejecting the task. This
  can be handy if the script you're wrapping (like ExifTool) writes non-fatal
  warnings to stderr.
- ✨ `BatchProcessOptions.pass` and `BatchProcessOptions.fail` can be RegExp
  instances now, if you have more exotic parsing needs.

## v4.0.0

- 💔 Using Node 8+ to determine if a process is running with `kill(pid, 0)`
  turns out to be unreliable (as it returns true even after the process exits).
  I tried to pull in the best-maintained "process-exists" external dependency,
  but that pulled in 15 more modules (this used to be a zero-deps module), and
  it was extremely unperformant on Windows.

  The TL;DR: is that `running(pid)` now returns a `Promise<boolean>`, which had
  far-reaching signature changes to accomodate the new asynchronicity, hence the
  major version bump.

- 💔 In an effort to reduce this library's complexity, I'm removing retry
  functionality. All parameters associated to retries are now gone.

- ✨ Internal state validation is now exposed by BatchCluster, and is used by
  tests to ensure no internal errors happen during integration tests. Previously
  these errors were simply logged.

## v3.2.0

- 📦 New `Logger` methods, `withLevels`, `withTimestamps`, and `filterLevels`
  were shoved into a new `Logger` namespace.

## v3.1.0

- ✨ Added simple timestamp and levels logger prefixer for tests
- 🐞 Errors rethrown via BatchProcess now strip extraneous `Error:` prefixes
- 🐞 For a couple internal errors (versionCommend startup errors and internal
  state inconsistencies on `onExit` that aren't fatal), we now log `.error`
  rather than throw Error() or ignore.

## v3.0.0

- ✨/💔 **`Task` promises are only rejected with `Error` instances now.** Note
  that also means that `BatchProcessObserver` types are more strict. It could be
  argued that this isn't an API breaking change as it only makes rejection
  values more strict, but people may need to change their error handling, so I'm
  bumping the major version to highlight that. Resolves
  [#3](https://github.com/mceachen/batch-cluster.js/issues/3). Thanks for the
  issue, [Nils Knappmeier](https://github.com/nknapp)!

## v2.2.0

- 🐞 Windows taskkill `/PID` option seemed to work downcased, but the docs say
  to use uppercase, so I've updated it.
- 📦 Upgrade all deps including TypeScript to 2.9

(v2.1.2 is the same contents, but `np` had a crashbug during publish)

## v2.1.1

- 📦 More robust `end` for `BatchProcess`, which may prevent very long-lived
  consumers from sporadically leaking child processes on Mac and linux.
- 📦 Added Node 10 to the build matrix.

## v2.1.0

- 📦 Introduced `Logger.trace` and moved logging related to per-task items down
  to `trace`, as heavy load and large request or response payloads could
  overwhelm loggers. If you really want to see on-the-wire requests and results,
  enable `trace` in your debugger implementation. By default, the
  `ConsoleLogger` omits log messages with this level.

## v2.0.0

- 💔 Replaced `BatchClusterObserver` with a simple EventEmitter API on
  `BatchCluster` to be more idiomatic with node's API
- 💔 v1.11.0 added "process reuse" after errors, but that turned out to be
  problematic in recovery, so that change was reverted (and with it, the
  `maxTaskErrorsPerProcess` parameter was removed)
- ✨ `Rate` is simpler and more accurate now.

## v1.11.0

- ✨ Added new `BatchClusterObserver` for error and lifecycle monitoring
- 📦 Added a number of additional logging calls

## v1.10.0

- 🐞 Explicitly use `timers.setInterval`. May address [this
  issue](https://stackoverflow.com/questions/48961238/electron-setinterval-implementation-difference-between-chrome-and-node).
  Thanks for the PR, [Tim Fish](https://github.com/timfish)!

## v1.9.1

- 📦 Changed `BatchProcess.end()` to use `until()` rather than `Promise.race`,
  and always use `kill(pid, forced)` after waiting the shutdown grace period
  to prevent child process leaks.

## v1.9.0

- ✨ New `Logger.setLogger()` for debug, info, warning, and errors. `debug` and
  `info` defaults to Node's
  [debuglog](https://nodejs.org/api/util.html#util_util_debuglog_section),
  `warn` and `error` default to `console.warn` and `console.error`,
  respectively.
- 📦 docs generated by [typedoc](http://typedoc.org/)
- 📦 Upgraded dependencies (including TypeScript 2.7, which has more strict
  verifications)
- 📦 Removed tslint, as `tsc` provides good lint coverage now
- 📦 The code is now [prettier](https://github.com/prettier/prettier)
- 🐞 `delay` now allows
  [unref](https://nodejs.org/api/timers.html#timers_timeout_unref)ing the
  timer, which, in certain circumstances, could prevent node processes from
  exiting gracefully until their timeouts expired

## v1.8.0

- ✨ onIdle now runs as many tasks as it can, rather than just one. This should
  provide higher throughput.
- 🐞 Removed stderr emit on race condition between onIdle and execTask. The
  error condition was already handled appropriately--no need to console.error.

## v1.7.0

- 📦 Exported `kill()` and `running()` from `BatchProcess`

## v1.6.1

- 📦 De-flaked some tests on mac, and added Node 8 to the build matrix.

## v1.6.0

- ✨ Processes are forcefully shut down with `taskkill` on windows and `kill -9`
  on other unix-like platforms if they don't terminate after sending the
  `exitCommand`, closing `stdin`, and sending the proc a `SIGTERM`. Added a test
  harness to exercise.
- 📦 Upgrade to TypeScript 2.6.1
- 🐞 `mocha` tests don't require the `--exit` hack anymore 🎉

## v1.5.0

- ✨ `.running()` works correctly for PIDs with different owners now.
- 📦 `yarn upgrade --latest`

## v1.4.2

- 📦 Ran code through `prettier` and delinted
- 📦 Massaged test assertions to pass through slower CI systems

## v1.4.1

- 📦 Replaced an errant `console.log` with a call to `log`.

## v1.4.0

- 🐞 Discovered `maxProcs` wasn't always utilized by `onIdle`, which meant in
  certain circumstances, only 1 child process would be servicing pending
  requests. Added breaking tests and fixed impl.

## v1.3.0

- 📦 Added tests to verify that the `kill(0)` calls to verify the child
  processes are still running work across different node version and OSes
- 📦 Removed unused methods in `BatchProcess` (whose API should not be accessed
  directly by consumers, so the major version remains at 1)
- 📦 Switched to yarn and upgraded dependencies

## v1.2.0

- ✨ Added a configurable cleanup signal to ensure child processes shut down on
  `.end()`
- 📦 Moved child process management from `BatchCluster` to `BatchProcess`
- ✨ More test coverage around batch process concurrency, reuse, flaky task
  retries, and proper process shutdown

## v1.1.0

- ✨ `BatchCluster` now has a force-shutdown `exit` handler to accompany the
  graceful-shutdown `beforeExit` handler. For reference, from the
  [Node docs](https://nodejs.org/api/process.html#process_event_beforeexit):

> The 'beforeExit' event is not emitted for conditions causing explicit
> termination, such as calling process.exit() or uncaught exceptions.

- ✨ Remove `Rate`'s time decay in the interests of simplicity

## v1.0.0

- ✨ Integration tests now throw deterministically random errors to simulate
  flaky child procs, and ensure retries and disaster recovery work as expected.
- ✨ If the `processFactory` or `versionCommand` fails more often than a given
  rate, `BatchCluster` will shut down and raise exceptions to subsequent
  `enqueueTask` callers, rather than try forever to spin up processes that are
  most likely misconfigured.
- ✨ Given the proliferation of construction options, those options are now
  sanity-checked at construction time, and an error will be raised whose message
  contains all incorrect option values.

## v0.0.2

- ✨ Added support and explicit tests for
  [CR LF, CR, and LF](https://en.wikipedia.org/wiki/Newline) encoded streams
  from spawned processes
- ✨ child processes are ended after `maxProcAgeMillis`, and restarted as needed
- 🐞 `BatchCluster` now practices good listener hygene for `process.beforeExit`

## v0.0.1

- ✨ Extracted implementation and tests from
  [exiftool-vendored](https://github.com/mceachen/exiftool-vendored.js)
