import { noop } from 'motion-utils';
import { GroupAnimation } from '../animation/GroupAnimation.mjs';
import { getLayoutElements } from './get-layout-elements.mjs';
import { buildProjectionTree, cleanupProjectionTree } from './projection-tree.mjs';
import { resolveElements } from '../utils/resolve-elements.mjs';
import { frame } from '../frameloop/frame.mjs';

class LayoutAnimationBuilder {
    constructor(scope, updateDom, defaultOptions) {
        this.sharedTransitions = new Map();
        this.notifyReady = noop;
        this.executed = false;
        this.scope = scope;
        this.updateDom = updateDom;
        this.defaultOptions = defaultOptions;
        this.readyPromise = new Promise((resolve) => {
            this.notifyReady = resolve;
        });
        // Queue execution on microtask to allow builder methods to be called
        queueMicrotask(() => this.execute());
    }
    shared(id, options) {
        this.sharedTransitions.set(id, options);
        return this;
    }
    then(onfulfilled, onrejected) {
        return this.readyPromise.then(onfulfilled, onrejected);
    }
    async execute() {
        if (this.executed)
            return;
        this.executed = true;
        let context;
        // Phase 1: Pre-mutation - Build projection tree and take snapshots
        const beforeElements = getLayoutElements(this.scope);
        if (beforeElements.length > 0) {
            context = buildProjectionTree(beforeElements, undefined, this.getBuildOptions());
            context.root.startUpdate();
            for (const node of context.nodes.values()) {
                node.isLayoutDirty = false;
                node.willUpdate();
            }
        }
        // Phase 2: Execute DOM update
        this.updateDom();
        // Phase 3: Post-mutation - Compare before/after elements
        const afterElements = getLayoutElements(this.scope);
        const beforeSet = new Set(beforeElements);
        const afterSet = new Set(afterElements);
        const entering = afterElements.filter((el) => !beforeSet.has(el));
        const exiting = beforeElements.filter((el) => !afterSet.has(el));
        // Build projection nodes for entering elements
        if (entering.length > 0) {
            context = buildProjectionTree(entering, context, this.getBuildOptions());
        }
        // No layout elements - return empty animation
        if (!context) {
            this.notifyReady(new GroupAnimation([]));
            return;
        }
        // Handle shared elements
        for (const element of exiting) {
            const node = context.nodes.get(element);
            node?.getStack()?.remove(node);
        }
        for (const element of entering) {
            context.nodes.get(element)?.promote();
        }
        // Phase 4: Animate
        context.root.didUpdate();
        await new Promise((resolve) => frame.postRender(() => resolve()));
        const animations = [];
        for (const node of context.nodes.values()) {
            if (node.currentAnimation) {
                animations.push(node.currentAnimation);
            }
        }
        const groupAnimation = new GroupAnimation(animations);
        groupAnimation.finished.then(() => {
            // Only clean up nodes for elements no longer in the document.
            // Elements still in DOM keep their nodes so subsequent animations
            // can use the stored position snapshots (A→B→A pattern).
            const elementsToCleanup = new Set();
            for (const element of context.nodes.keys()) {
                if (!document.contains(element)) {
                    elementsToCleanup.add(element);
                }
            }
            cleanupProjectionTree(context, elementsToCleanup);
        });
        this.notifyReady(groupAnimation);
    }
    getBuildOptions() {
        return {
            defaultTransition: this.defaultOptions || {
                duration: 0.3,
                ease: "easeOut",
            },
            sharedTransitions: this.sharedTransitions.size > 0
                ? this.sharedTransitions
                : undefined,
        };
    }
}
/**
 * Parse arguments for animateLayout overloads
 */
function parseAnimateLayoutArgs(scopeOrUpdateDom, updateDomOrOptions, options) {
    // animateLayout(updateDom)
    if (typeof scopeOrUpdateDom === "function") {
        return {
            scope: document,
            updateDom: scopeOrUpdateDom,
            defaultOptions: updateDomOrOptions,
        };
    }
    // animateLayout(scope, updateDom, options?)
    const elements = resolveElements(scopeOrUpdateDom);
    const scope = elements[0] || document;
    return {
        scope: scope instanceof Document ? scope : scope,
        updateDom: updateDomOrOptions,
        defaultOptions: options,
    };
}

export { LayoutAnimationBuilder, parseAnimateLayoutArgs };
//# sourceMappingURL=LayoutAnimationBuilder.mjs.map
