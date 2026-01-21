import { transformProps } from './keys-transform.mjs';
import { scaleCorrectors } from '../../projection/styles/scale-correction.mjs';
export { addScaleCorrector } from '../../projection/styles/scale-correction.mjs';

function isForcedMotionValue(key, { layout, layoutId }) {
    return (transformProps.has(key) ||
        key.startsWith("origin") ||
        ((layout || layoutId !== undefined) &&
            (!!scaleCorrectors[key] || key === "opacity")));
}

export { isForcedMotionValue, scaleCorrectors };
//# sourceMappingURL=is-forced-motion-value.mjs.map
