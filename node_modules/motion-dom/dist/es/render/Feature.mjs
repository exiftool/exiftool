/**
 * Feature base class for extending VisualElement functionality.
 * Features are plugins that can be mounted/unmounted to add behavior
 * like gestures, animations, or layout tracking.
 */
class Feature {
    constructor(node) {
        this.isMounted = false;
        this.node = node;
    }
    update() { }
}

export { Feature };
//# sourceMappingURL=Feature.mjs.map
