import { isMotionValue } from './is-motion-value.mjs';

/**
 * If the provided value is a MotionValue, this returns the actual value, otherwise just the value itself
 */
function resolveMotionValue(value) {
    return isMotionValue(value) ? value.get() : value;
}

export { resolveMotionValue };
//# sourceMappingURL=resolve-motion-value.mjs.map
