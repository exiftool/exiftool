import { addDomEvent } from '../../events/add-dom-event.mjs';
import { createProjectionNode } from './create-projection-node.mjs';

const DocumentProjectionNode = createProjectionNode({
    attachResizeListener: (ref, notify) => addDomEvent(ref, "resize", notify),
    measureScroll: () => ({
        x: document.documentElement.scrollLeft || document.body?.scrollLeft || 0,
        y: document.documentElement.scrollTop || document.body?.scrollTop || 0,
    }),
    checkIsScrollRoot: () => true,
});

export { DocumentProjectionNode };
//# sourceMappingURL=DocumentProjectionNode.mjs.map
