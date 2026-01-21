"use client";
import { scrapeHTMLMotionValuesFromProps } from 'motion-dom';
import { makeUseVisualState } from '../../motion/utils/use-visual-state.mjs';
import { createHtmlRenderState } from './utils/create-render-state.mjs';

const useHTMLVisualState = /*@__PURE__*/ makeUseVisualState({
    scrapeMotionValuesFromProps: scrapeHTMLMotionValuesFromProps,
    createRenderState: createHtmlRenderState,
});

export { useHTMLVisualState };
//# sourceMappingURL=use-html-visual-state.mjs.map
