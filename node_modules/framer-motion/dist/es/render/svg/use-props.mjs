"use client";
import { buildSVGAttrs, isSVGTag } from 'motion-dom';
import { useMemo } from 'react';
import { copyRawValuesOnly } from '../html/use-props.mjs';
import { createSvgRenderState } from './utils/create-render-state.mjs';

function useSVGProps(props, visualState, _isStatic, Component) {
    const visualProps = useMemo(() => {
        const state = createSvgRenderState();
        buildSVGAttrs(state, visualState, isSVGTag(Component), props.transformTemplate, props.style);
        return {
            ...state.attrs,
            style: { ...state.style },
        };
    }, [visualState]);
    if (props.style) {
        const rawStyles = {};
        copyRawValuesOnly(rawStyles, props.style, props);
        visualProps.style = { ...rawStyles, ...visualProps.style };
    }
    return visualProps;
}

export { useSVGProps };
//# sourceMappingURL=use-props.mjs.map
