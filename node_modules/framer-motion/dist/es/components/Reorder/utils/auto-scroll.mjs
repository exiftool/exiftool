const threshold = 50;
const maxSpeed = 25;
const overflowStyles = new Set(["auto", "scroll"]);
// Track initial scroll limits per scrollable element (Bug 1 fix)
const initialScrollLimits = new WeakMap();
const activeScrollEdge = new WeakMap();
// Track which group element is currently dragging to clear state on end
let currentGroupElement = null;
function resetAutoScrollState() {
    if (currentGroupElement) {
        const scrollableAncestor = findScrollableAncestor(currentGroupElement, "y");
        if (scrollableAncestor) {
            activeScrollEdge.delete(scrollableAncestor);
            initialScrollLimits.delete(scrollableAncestor);
        }
        // Also try x axis
        const scrollableAncestorX = findScrollableAncestor(currentGroupElement, "x");
        if (scrollableAncestorX && scrollableAncestorX !== scrollableAncestor) {
            activeScrollEdge.delete(scrollableAncestorX);
            initialScrollLimits.delete(scrollableAncestorX);
        }
        currentGroupElement = null;
    }
}
function isScrollableElement(element, axis) {
    const style = getComputedStyle(element);
    const overflow = axis === "x" ? style.overflowX : style.overflowY;
    return overflowStyles.has(overflow);
}
function findScrollableAncestor(element, axis) {
    let current = element?.parentElement;
    while (current) {
        if (isScrollableElement(current, axis)) {
            return current;
        }
        current = current.parentElement;
    }
    return null;
}
function getScrollAmount(pointerPosition, scrollElement, axis) {
    const rect = scrollElement.getBoundingClientRect();
    const start = axis === "x" ? rect.left : rect.top;
    const end = axis === "x" ? rect.right : rect.bottom;
    const distanceFromStart = pointerPosition - start;
    const distanceFromEnd = end - pointerPosition;
    if (distanceFromStart < threshold) {
        const intensity = 1 - distanceFromStart / threshold;
        return { amount: -maxSpeed * intensity * intensity, edge: "start" };
    }
    else if (distanceFromEnd < threshold) {
        const intensity = 1 - distanceFromEnd / threshold;
        return { amount: maxSpeed * intensity * intensity, edge: "end" };
    }
    return { amount: 0, edge: null };
}
function autoScrollIfNeeded(groupElement, pointerPosition, axis, velocity) {
    if (!groupElement)
        return;
    // Track the group element for cleanup
    currentGroupElement = groupElement;
    const scrollableAncestor = findScrollableAncestor(groupElement, axis);
    if (!scrollableAncestor)
        return;
    // Convert pointer position from page coordinates to viewport coordinates.
    // The gesture system uses pageX/pageY but getBoundingClientRect() returns
    // viewport-relative coordinates, so we need to account for page scroll.
    const viewportPointerPosition = pointerPosition - (axis === "x" ? window.scrollX : window.scrollY);
    const { amount: scrollAmount, edge } = getScrollAmount(viewportPointerPosition, scrollableAncestor, axis);
    // If not in any threshold zone, clear all state
    if (edge === null) {
        activeScrollEdge.delete(scrollableAncestor);
        initialScrollLimits.delete(scrollableAncestor);
        return;
    }
    const currentActiveEdge = activeScrollEdge.get(scrollableAncestor);
    // If not currently scrolling this edge, check velocity to see if we should start
    if (currentActiveEdge !== edge) {
        // Only start scrolling if velocity is towards the edge
        const shouldStart = (edge === "start" && velocity < 0) ||
            (edge === "end" && velocity > 0);
        if (!shouldStart)
            return;
        // Activate this edge
        activeScrollEdge.set(scrollableAncestor, edge);
        // Record initial scroll limit (prevents infinite scroll)
        const maxScroll = axis === "x"
            ? scrollableAncestor.scrollWidth -
                scrollableAncestor.clientWidth
            : scrollableAncestor.scrollHeight -
                scrollableAncestor.clientHeight;
        initialScrollLimits.set(scrollableAncestor, maxScroll);
    }
    // Cap scrolling at initial limit (prevents infinite scroll)
    if (scrollAmount > 0) {
        const initialLimit = initialScrollLimits.get(scrollableAncestor);
        const currentScroll = axis === "x"
            ? scrollableAncestor.scrollLeft
            : scrollableAncestor.scrollTop;
        if (currentScroll >= initialLimit)
            return;
    }
    // Apply scroll
    if (axis === "x") {
        scrollableAncestor.scrollLeft += scrollAmount;
    }
    else {
        scrollableAncestor.scrollTop += scrollAmount;
    }
}

export { autoScrollIfNeeded, resetAutoScrollState };
//# sourceMappingURL=auto-scroll.mjs.map
