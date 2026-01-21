import { HTMLProjectionNode } from '../projection/node/HTMLProjectionNode.mjs';
import { HTMLVisualElement } from '../render/html/HTMLVisualElement.mjs';
import { nodeGroup } from '../projection/node/group.mjs';
import { getLayoutId } from './get-layout-elements.mjs';
import { addScaleCorrector } from '../projection/styles/scale-correction.mjs';
import { correctBorderRadius } from '../projection/styles/scale-border-radius.mjs';
import { correctBoxShadow } from '../projection/styles/scale-box-shadow.mjs';

let scaleCorrectorAdded = false;
/**
 * Track active projection nodes per element to handle animation interruption.
 * When a new animation starts on an element that already has an active animation,
 * we need to stop the old animation so the new one can start from the current
 * visual position.
 */
const activeProjectionNodes = new WeakMap();
function ensureScaleCorrectors() {
    if (scaleCorrectorAdded)
        return;
    scaleCorrectorAdded = true;
    addScaleCorrector({
        borderRadius: {
            ...correctBorderRadius,
            applyTo: [
                "borderTopLeftRadius",
                "borderTopRightRadius",
                "borderBottomLeftRadius",
                "borderBottomRightRadius",
            ],
        },
        borderTopLeftRadius: correctBorderRadius,
        borderTopRightRadius: correctBorderRadius,
        borderBottomLeftRadius: correctBorderRadius,
        borderBottomRightRadius: correctBorderRadius,
        boxShadow: correctBoxShadow,
    });
}
/**
 * Get DOM depth of an element
 */
function getDepth(element) {
    let depth = 0;
    let current = element.parentElement;
    while (current) {
        depth++;
        current = current.parentElement;
    }
    return depth;
}
/**
 * Find the closest projection parent for an element
 */
function findProjectionParent(element, nodeCache) {
    let parent = element.parentElement;
    while (parent) {
        const node = nodeCache.get(parent);
        if (node)
            return node;
        parent = parent.parentElement;
    }
    return undefined;
}
/**
 * Create or reuse a projection node for an element
 */
function createProjectionNode(element, parent, options, transition) {
    // Check for existing active node - reuse it to preserve animation state
    const existingNode = activeProjectionNodes.get(element);
    if (existingNode) {
        const visualElement = existingNode.options.visualElement;
        // Update transition options for the new animation
        const nodeTransition = transition
            ? { duration: transition.duration, ease: transition.ease }
            : { duration: 0.3, ease: "easeOut" };
        existingNode.setOptions({
            ...existingNode.options,
            animate: true,
            transition: nodeTransition,
            ...options,
        });
        // Re-mount the node if it was previously unmounted
        // This re-adds it to root.nodes so didUpdate() will process it
        if (!existingNode.instance) {
            existingNode.mount(element);
        }
        return { node: existingNode, visualElement };
    }
    // No existing node - create a new one
    const latestValues = {};
    const visualElement = new HTMLVisualElement({
        visualState: {
            latestValues,
            renderState: {
                transformOrigin: {},
                transform: {},
                style: {},
                vars: {},
            },
        },
        presenceContext: null,
        props: {},
    });
    const node = new HTMLProjectionNode(latestValues, parent);
    // Convert AnimationOptions to transition format for the projection system
    const nodeTransition = transition
        ? { duration: transition.duration, ease: transition.ease }
        : { duration: 0.3, ease: "easeOut" };
    node.setOptions({
        visualElement,
        layout: true,
        animate: true,
        transition: nodeTransition,
        ...options,
    });
    node.mount(element);
    visualElement.projection = node;
    // Track this node as the active one for this element
    activeProjectionNodes.set(element, node);
    return { node, visualElement };
}
/**
 * Build a projection tree from a list of elements
 */
function buildProjectionTree(elements, existingContext, options) {
    ensureScaleCorrectors();
    const nodes = existingContext?.nodes ?? new Map();
    const visualElements = existingContext?.visualElements ?? new Map();
    const group = existingContext?.group ?? nodeGroup();
    const defaultTransition = options?.defaultTransition;
    const sharedTransitions = options?.sharedTransitions;
    // Sort elements by DOM depth (parents before children)
    const sorted = [...elements].sort((a, b) => getDepth(a) - getDepth(b));
    let root = existingContext?.root;
    for (const element of sorted) {
        // Skip if already has a node
        if (nodes.has(element))
            continue;
        const parent = findProjectionParent(element, nodes);
        const layoutId = getLayoutId(element);
        const layoutMode = element.getAttribute("data-layout");
        const nodeOptions = {
            layoutId: layoutId ?? undefined,
            animationType: parseLayoutMode(layoutMode),
        };
        // Use layoutId-specific transition if available, otherwise use default
        const transition = layoutId && sharedTransitions?.get(layoutId)
            ? sharedTransitions.get(layoutId)
            : defaultTransition;
        const { node, visualElement } = createProjectionNode(element, parent, nodeOptions, transition);
        nodes.set(element, node);
        visualElements.set(element, visualElement);
        group.add(node);
        if (!root) {
            root = node.root;
        }
    }
    return {
        nodes,
        visualElements,
        group,
        root: root,
    };
}
/**
 * Parse the data-layout attribute value
 */
function parseLayoutMode(value) {
    if (value === "position")
        return "position";
    if (value === "size")
        return "size";
    if (value === "preserve-aspect")
        return "preserve-aspect";
    return "both";
}
/**
 * Clean up projection nodes for specific elements.
 * If elementsToCleanup is provided, only those elements are cleaned up.
 * If not provided, all nodes are cleaned up.
 *
 * This allows persisting elements to keep their nodes between animations,
 * matching React's behavior where nodes persist for elements that remain in the DOM.
 */
function cleanupProjectionTree(context, elementsToCleanup) {
    const elementsToProcess = elementsToCleanup
        ? [...context.nodes.entries()].filter(([el]) => elementsToCleanup.has(el))
        : [...context.nodes.entries()];
    for (const [element, node] of elementsToProcess) {
        context.group.remove(node);
        node.unmount();
        // Only clear from activeProjectionNodes if this is still the active node.
        // A newer animation might have already taken over.
        if (activeProjectionNodes.get(element) === node) {
            activeProjectionNodes.delete(element);
        }
        context.nodes.delete(element);
        context.visualElements.delete(element);
    }
}

export { buildProjectionTree, cleanupProjectionTree };
//# sourceMappingURL=projection-tree.mjs.map
