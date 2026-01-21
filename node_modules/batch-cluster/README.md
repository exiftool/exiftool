![PhotoStructure batch-cluster logo](https://raw.githubusercontent.com/photostructure/batch-cluster.js/main/doc/logo.svg)

**Efficient, concurrent work via batch-mode command-line tools from within Node.js.**

[![npm version](https://img.shields.io/npm/v/batch-cluster.svg)](https://www.npmjs.com/package/batch-cluster)
[![Build status](https://github.com/photostructure/batch-cluster.js/actions/workflows/build.yml/badge.svg?branch=main)](https://github.com/photostructure/batch-cluster.js/actions/workflows/build.yml)
[![GitHub issues](https://img.shields.io/github/issues/photostructure/batch-cluster.js.svg)](https://github.com/photostructure/batch-cluster.js/issues)
[![CodeQL](https://github.com/photostructure/batch-cluster.js/actions/workflows/codeql-analysis.yml/badge.svg)](https://github.com/photostructure/batch-cluster.js/actions/workflows/codeql-analysis.yml)
[![Known Vulnerabilities](https://snyk.io/test/github/photostructure/batch-cluster.js/badge.svg?targetFile=package.json)](https://snyk.io/test/github/photostructure/batch-cluster.js?targetFile=package.json)

Many command line tools, like
[ExifTool](https://sno.phy.queensu.ca/~phil/exiftool/),
[PowerShell](https://github.com/powershell/powershell), and
[GraphicsMagick](http://www.graphicsmagick.org/), support running in a "batch
mode" that accept a series of discrete commands provided through stdin and
results through stdout. As these tools can be fairly large, spinning them up can
be expensive (especially on Windows).

This module allows you to run a series of commands, or `Task`s, processed by a
cluster of these processes.

This module manages both a queue of pending tasks, feeding processes pending
tasks when they are idle, as well as monitoring the child processes for errors
and crashes. Batch processes are also recycled after processing N tasks or
running for N seconds, in an effort to minimize the impact of any potential
memory leaks.

As of version 4, retry logic for tasks is a separate concern from this module.

This package powers [exiftool-vendored](https://photostructure.github.io/exiftool-vendored.js/),
whose source you can examine as an example consumer.

## Installation

```bash
$ npm install --save batch-cluster
```

## Changelog

See [CHANGELOG.md](https://github.com/photostructure/batch-cluster.js/blob/main/CHANGELOG.md).

## Usage

The child process must use `stdin` and `stdout` for control/response.
BatchCluster will ensure a given process is only given one task at a time.

1.  Create a singleton instance of
    [BatchCluster](https://photostructure.github.io/batch-cluster.js/classes/BatchCluster.html).

    Note the [constructor
    options](https://photostructure.github.io/batch-cluster.js/classes/BatchCluster.html#constructor)
    takes a union type of
    - [ChildProcessFactory](https://photostructure.github.io/batch-cluster.js/interfaces/ChildProcessFactory.html)
      and
    - [BatchProcessOptions](https://photostructure.github.io/batch-cluster.js/interfaces/BatchProcessOptions.html),
      both of which have no defaults, and
    - [BatchClusterOptions](https://photostructure.github.io/batch-cluster.js/classes/BatchClusterOptions.html),
      which has defaults that may or may not be relevant to your application.

1.  The [default logger](https://photostructure.github.io/batch-cluster.js/interfaces/Logger.html)
    writes warning and error messages to `console.warn` and `console.error`. You
    can change this to your logger by using
    [setLogger](https://photostructure.github.io/batch-cluster.js/modules.html#setLogger) or by providing a logger to the `BatchCluster` constructor.

1.  Implement the [Parser](https://photostructure.github.io/batch-cluster.js/interfaces/Parser.html)
    class to parse results from your child process.

1.  Construct or extend the
    [Task](https://photostructure.github.io/batch-cluster.js/classes/Task.html)
    class with the desired command and the parser you built in the previous
    step, and submit it to your BatchCluster's
    [enqueueTask](https://photostructure.github.io/batch-cluster.js/classes/BatchCluster.html#enqueueTask)
    method.

See
[src/test.ts](https://github.com/photostructure/batch-cluster.js/blob/main/src/test.ts)
for an example child process. Note that the script is _designed_ to be flaky on
order to test BatchCluster's retry and error handling code.
