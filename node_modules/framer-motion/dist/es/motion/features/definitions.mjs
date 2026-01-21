import { getFeatureDefinitions, setFeatureDefinitions } from 'motion-dom';

const featureProps = {
    animation: [
        "animate",
        "variants",
        "whileHover",
        "whileTap",
        "exit",
        "whileInView",
        "whileFocus",
        "whileDrag",
    ],
    exit: ["exit"],
    drag: ["drag", "dragControls"],
    focus: ["whileFocus"],
    hover: ["whileHover", "onHoverStart", "onHoverEnd"],
    tap: ["whileTap", "onTap", "onTapStart", "onTapCancel"],
    pan: ["onPan", "onPanStart", "onPanSessionStart", "onPanEnd"],
    inView: ["whileInView", "onViewportEnter", "onViewportLeave"],
    layout: ["layout", "layoutId"],
};
let isInitialized = false;
/**
 * Initialize feature definitions with isEnabled checks.
 * This must be called before any motion components are rendered.
 */
function initFeatureDefinitions() {
    if (isInitialized)
        return;
    const initialFeatureDefinitions = {};
    for (const key in featureProps) {
        initialFeatureDefinitions[key] = {
            isEnabled: (props) => featureProps[key].some((name) => !!props[name]),
        };
    }
    setFeatureDefinitions(initialFeatureDefinitions);
    isInitialized = true;
}
/**
 * Get the current feature definitions, initializing if needed.
 */
function getInitializedFeatureDefinitions() {
    initFeatureDefinitions();
    return getFeatureDefinitions();
}

export { getInitializedFeatureDefinitions, initFeatureDefinitions };
//# sourceMappingURL=definitions.mjs.map
