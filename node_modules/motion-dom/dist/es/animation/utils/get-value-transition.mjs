function getValueTransition(transition, key) {
    return (transition?.[key] ??
        transition?.["default"] ??
        transition);
}

export { getValueTransition };
//# sourceMappingURL=get-value-transition.mjs.map
