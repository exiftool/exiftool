# exiftool-vendored.exe

Provides the win32 distribution of [ExifTool](http://www.sno.phy.queensu.ca/~phil/exiftool/) to [node](https://nodejs.org/en/).

[![npm version](https://img.shields.io/npm/v/exiftool-vendored.exe.svg)](https://www.npmjs.com/package/exiftool-vendored.exe)
[![Build & Release](https://github.com/photostructure/exiftool-vendored.exe/actions/workflows/build.yml/badge.svg?branch=main)](https://github.com/photostructure/exiftool-vendored.exe/actions/workflows/build.yml)

## Usage

**See
[exiftool-vendored](https://github.com/photostructure/exiftool-vendored.js) for
performant, type-safe access to this binary.**

## Thanks to Phil Harvey and Oliver Betz!

Phil Harvey has been [working tirelessly on ExifTool since 2003](https://exiftool.org/ancient_history.html).

This module uses the new (as of version 12.88) official Windows installation, which depends on [Oliver Betz's portable Perl
launcher](https://oliverbetz.de/pages/Artikel/Portable-Perl-Applications) and Strawberry Perl. [Read more
here.](https://oliverbetz.de/pages/Artikel/ExifTool-for-Windows)

## Versioning

This package exposes the version of ExifTool it vendors, and adds a patch number, if necessary, to follow SemVer.
