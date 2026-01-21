import { isMotionValue } from '../../../value/utils/is-motion-value.mjs';
import { isForcedMotionValue } from '../../utils/is-forced-motion-value.mjs';

function scrapeMotionValuesFromProps(props, prevProps, visualElement) {
    const style = props.style;
    const prevStyle = prevProps?.style;
    const newValues = {};
    if (!style)
        return newValues;
    for (const key in style) {
        if (isMotionValue(style[key]) ||
            (prevStyle && isMotionValue(prevStyle[key])) ||
            isForcedMotionValue(key, props) ||
            visualElement?.getValue(key)?.liveStyle !== undefined) {
            newValues[key] = style[key];
        }
    }
    return newValues;
}

export { scrapeMotionValuesFromProps };
//# sourceMappingURL=scrape-motion-values.mjs.map
