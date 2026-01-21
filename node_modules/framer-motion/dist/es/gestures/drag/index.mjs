import { Feature } from 'motion-dom';
import { noop } from 'motion-utils';
import { VisualElementDragControls } from './VisualElementDragControls.mjs';

class DragGesture extends Feature {
    constructor(node) {
        super(node);
        this.removeGroupControls = noop;
        this.removeListeners = noop;
        this.controls = new VisualElementDragControls(node);
    }
    mount() {
        // If we've been provided a DragControls for manual control over the drag gesture,
        // subscribe this component to it on mount.
        const { dragControls } = this.node.getProps();
        if (dragControls) {
            this.removeGroupControls = dragControls.subscribe(this.controls);
        }
        this.removeListeners = this.controls.addListeners() || noop;
    }
    update() {
        const { dragControls } = this.node.getProps();
        const { dragControls: prevDragControls } = this.node.prevProps || {};
        if (dragControls !== prevDragControls) {
            this.removeGroupControls();
            if (dragControls) {
                this.removeGroupControls = dragControls.subscribe(this.controls);
            }
        }
    }
    unmount() {
        this.removeGroupControls();
        this.removeListeners();
        /**
         * Only clean up the pan session if one exists. We use endPanSession()
         * instead of cancel() because cancel() also modifies projection animation
         * state and drag locks, which could interfere with nested drag scenarios.
         */
        this.controls.endPanSession();
    }
}

export { DragGesture };
//# sourceMappingURL=index.mjs.map
