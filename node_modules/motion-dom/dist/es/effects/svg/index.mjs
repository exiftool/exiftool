import { MotionValue } from '../../value/index.mjs';
import { addAttrValue } from '../attr/index.mjs';
import { addStyleValue } from '../style/index.mjs';
import { createSelectorEffect } from '../utils/create-dom-effect.mjs';
import { createEffect } from '../utils/create-effect.mjs';
import { frame } from '../../frameloop/frame.mjs';

function addSVGPathValue(element, state, key, value) {
    frame.render(() => element.setAttribute("pathLength", "1"));
    if (key === "pathOffset") {
        return state.set(key, value, () => {
            // Use unitless value to avoid Safari zoom bug
            const offset = state.latest[key];
            element.setAttribute("stroke-dashoffset", `${-offset}`);
        });
    }
    else {
        if (!state.get("stroke-dasharray")) {
            state.set("stroke-dasharray", new MotionValue("1 1"), () => {
                const { pathLength = 1, pathSpacing } = state.latest;
                // Use unitless values to avoid Safari zoom bug
                element.setAttribute("stroke-dasharray", `${pathLength} ${pathSpacing ?? 1 - Number(pathLength)}`);
            });
        }
        return state.set(key, value, undefined, state.get("stroke-dasharray"));
    }
}
const addSVGValue = (element, state, key, value) => {
    if (key.startsWith("path")) {
        return addSVGPathValue(element, state, key, value);
    }
    else if (key.startsWith("attr")) {
        return addAttrValue(element, state, convertAttrKey(key), value);
    }
    const handler = key in element.style ? addStyleValue : addAttrValue;
    return handler(element, state, key, value);
};
const svgEffect = /*@__PURE__*/ createSelectorEffect(
/*@__PURE__*/ createEffect(addSVGValue));
function convertAttrKey(key) {
    return key.replace(/^attr([A-Z])/, (_, firstChar) => firstChar.toLowerCase());
}

export { svgEffect };
//# sourceMappingURL=index.mjs.map
