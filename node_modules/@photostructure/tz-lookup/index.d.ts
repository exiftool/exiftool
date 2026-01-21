/**
 * Look up the timezone for a given latitude and longitude.
 *
 * @throws {Error} if the latitude or longitude are invalid
 */
declare function tz_lookup(latitude: number, longitude: number): string;

export = tz_lookup;
