const LAYOUT_SELECTOR = "[data-layout], [data-layout-id]";
function getLayoutElements(scope) {
    const elements = Array.from(scope.querySelectorAll(LAYOUT_SELECTOR));
    // Include scope itself if it's an Element (not Document) and has layout attributes
    if (scope instanceof Element && hasLayout(scope)) {
        elements.unshift(scope);
    }
    return elements;
}
function getLayoutId(element) {
    return element.getAttribute("data-layout-id");
}
function hasLayout(element) {
    return (element.hasAttribute("data-layout") ||
        element.hasAttribute("data-layout-id"));
}

export { getLayoutElements, getLayoutId };
//# sourceMappingURL=get-layout-elements.mjs.map
