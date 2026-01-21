"use client";
import { scrapeSVGMotionValuesFromProps } from 'motion-dom';
import { makeUseVisualState } from '../../motion/utils/use-visual-state.mjs';
import { createSvgRenderState } from './utils/create-render-state.mjs';

const useSVGVisualState = /*@__PURE__*/ makeUseVisualState({
    scrapeMotionValuesFromProps: scrapeSVGMotionValuesFromProps,
    createRenderState: createSvgRenderState,
});

export { useSVGVisualState };
//# sourceMappingURL=use-svg-visual-state.mjs.map
