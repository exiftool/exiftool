import { isControllingVariants, isVariantLabel } from 'motion-dom';

function getCurrentTreeVariants(props, context) {
    if (isControllingVariants(props)) {
        const { initial, animate } = props;
        return {
            initial: initial === false || isVariantLabel(initial)
                ? initial
                : undefined,
            animate: isVariantLabel(animate) ? animate : undefined,
        };
    }
    return props.inherit !== false ? context : {};
}

export { getCurrentTreeVariants };
//# sourceMappingURL=utils.mjs.map
