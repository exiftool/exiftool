import { addDomEvent } from 'motion-dom';
import { addPointerInfo } from './event-info.mjs';

function addPointerEvent(target, eventName, handler, options) {
    return addDomEvent(target, eventName, addPointerInfo(handler), options);
}

export { addPointerEvent };
//# sourceMappingURL=add-pointer-event.mjs.map
