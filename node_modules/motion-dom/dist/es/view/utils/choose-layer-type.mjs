function chooseLayerType(valueName) {
    if (valueName === "layout")
        return "group";
    if (valueName === "enter" || valueName === "new")
        return "new";
    if (valueName === "exit" || valueName === "old")
        return "old";
    return "group";
}

export { chooseLayerType };
//# sourceMappingURL=choose-layer-type.mjs.map
