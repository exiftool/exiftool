# @photostructure/tz-lookup

[![npm version](https://img.shields.io/npm/v/@photostructure/tz-lookup.svg)](https://www.npmjs.com/package/@photostructure/tz-lookup)
[![Build status](https://github.com/photostructure/tz-lookup/actions/workflows/build.yml/badge.svg?branch=main)](https://github.com/photostructure/tz-lookup/actions/workflows/build.yml)
[![GitHub issues](https://img.shields.io/github/issues/photostructure/tz-lookup.svg)](https://github.com/photostructure/tz-lookup/issues)

Fast, memory-efficient time zone estimations from latitude and longitude.

## Background

This is a fork of [darkskyapp/tz-lookup](https://github.com/darkskyapp/tz-lookup-oss) which was abandoned in 2020. Ongoing maintenance is supported by [PhotoStructure](https://photostructure.com).

The following updates have been made to this fork:

- The time zone database uses
  [timezone-boundary-builder](https://github.com/evansiroky/timezone-boundary-builder/). Expect a bunch of changes if you're upgrading from the original `tz-lookup`, including new zone names and shapes.

- TypeScript types are now included.

- The test suite now validates the result from this library with the more accurate library, [`geo-tz`](https://github.com/evansiroky/node-geo-tz/), and provides benchmark timing results.

- GitHub Actions now runs the test suite

- Releases are now performed via OIDC, which provides [build provenance](https://docs.github.com/en/actions/security-guides/using-artifact-attestations-to-establish-provenance-for-builds). Scroll to the "Provenance" section at the bottom of https://www.npmjs.com/package/@photostructure/tz-lookup to validate. 

## Caution! This package trades speed and size for accuracy.

**TL;DR: if accuracy is important for your application and you don't need to support browsers, use `geo-tz`.**

The following comparisons were taken in January 2024 with the latest versions of Node.js, this package, and geo-tz.

### Size

This package is 10x smaller than
[geo-tz](https://github.com/evansiroky/node-geo-tz/):
([72kb](https://bundlephobia.com/package/@photostructure/tz-lookup@9.0.0) vs
[892kb](https://bundlephobia.com/package/geo-tz@8.0.1)).

### Speed

This package is roughly 100x faster than `geo-tz`, as well. On an AMD 5950x (a fast desktop CPU from 2023) and Node.js v20:

- this package takes **~.05 milliseconds** per lookup, and
- `geo-tz` takes **~5 milliseconds** per lookup.

### Accuracy

If you take a random point on the earth, roughly 30% of the results from this package won't match the (accurate) result from `geo-tz`.

This drops to roughly 10% if you only pick points that are likely [inhabited](https://github.com/darkskyapp/inhabited).

This error rate drops to roughly 5% if you consider time zones (like `Europe/Vienna` and `Europe/Berlin`) that result in equivalent time zone offset values throughout the year.

Here's a sample of some errors from this page for some random locations from running the test suite. The first mentioned IANA timezone is from this package, and the second (probably more correct) IANA timezone is from `geo-tz`. 

```json
[
  {
    "lat": "24.881",
    "lon": "59.984",
    "error": "expected Asia/Tehran(210) to have the same standard-time offset as Etc/GMT-4(240)"
  },
  {
    "lat": "46.345",
    "lon": "48.766",
    "error": "expected Asia/Atyrau(300) to have the same standard-time offset as Europe/Astrakhan(240)"
  },
  {
    "lat": "59.275",
    "lon": "134.481",
    "error": "expected Asia/Vladivostok(600) to have the same standard-time offset as Asia/Khandyga(540)"
  },
  {
    "lat": "20.645",
    "lon": "100.190",
    "error": "expected Asia/Yangon(390) to have the same standard-time offset as Asia/Jakarta(420)"
  },
  {
    "lat": "38.012",
    "lon": "0.082",
    "error": "expected Europe/Madrid(60) to have the same standard-time offset as Etc/GMT(0)"
  },
  {
    "lat": "-22.364",
    "lon": "-57.449",
    "error": "expected America/Campo_Grande(-240) to have the same standard-time offset as America/Asuncion(-180)"
  },
  {
    "lat": "39.018",
    "lon": "-73.842",
    "error": "expected America/New_York(-240) to have the same daylight-savings-time offset as Etc/GMT+5(-300)"
  },
  {
    "lat": "28.427",
    "lon": "-95.793",
    "error": "expected America/Chicago(-300) to have the same daylight-savings-time offset as Etc/GMT+6(-360)"
  }
]
```


## Usage

To install:

    npm install @photostructure/tz-lookup

Node.JS usage:

```javascript
var tzlookup = require("@photostructure/tz-lookup");
console.log(tzlookup(42.7235, -73.6931)); // prints "America/New_York"
```

Browser usage:

```html
<script src="tz.js"></script>
<script>
  alert(tzlookup(42.7235, -73.6931)); // alerts "America/New_York"
</script>
```

**Please take note of the following:**

- The exported function call will throw an error if the latitude or longitude
  provided are NaN or out of bounds. Otherwise, it will never throw an error
  and will always return an IANA timezone database string. (Barring bugs.)

- The timezones returned by this module are approximate: since the timezone
  database is so large, lossy compression is necessary for a small footprint
  and fast lookups. Expect errors near timezone borders far away from
  populated areas. However, for most use-cases, this module's accuracy should
  be adequate.

  If you find a real-world case where this module's accuracy is inadequate,
  please open an issue (or, better yet, submit a pull request with a failing
  test) and I'll see what I can do to increase the accuracy for you.

## Sources

Timezone data is sourced from Evan Siroky's [timezone-boundary-builder][tbb].

To regenerate the library's database yourself, you will need to install GDAL:

```sh
$ brew install gdal # on Mac OS X
$ sudo apt install gdal-bin # on Ubuntu
```

Then, simply execute `rebuild.sh`. Expect it to take 10-30 minutes, depending
on your network connection and CPU.

[tbb]: https://github.com/evansiroky/timezone-boundary-builder/

## License

To the extent possible by law, The Dark Sky Company, LLC has [waived all
copyright and related or neighboring rights][cc0] to this library.

[cc0]: http://creativecommons.org/publicdomain/zero/1.0/

Any subsequent changes since the fork are also licensed via cc0.
