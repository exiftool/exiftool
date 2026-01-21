import { SVGVisualElement, HTMLVisualElement } from 'motion-dom';
import { Fragment } from 'react';
import { isSVGComponent } from './utils/is-svg-component.mjs';

const createDomVisualElement = (Component, options) => {
    /**
     * Use explicit isSVG override if provided, otherwise auto-detect
     */
    const isSVG = options.isSVG ?? isSVGComponent(Component);
    return isSVG
        ? new SVGVisualElement(options)
        : new HTMLVisualElement(options, {
            allowProjection: Component !== Fragment,
        });
};

export { createDomVisualElement };
//# sourceMappingURL=create-visual-element.mjs.map
