function isGenerator(type) {
    return typeof type === "function" && "applyToOptions" in type;
}

export { isGenerator };
//# sourceMappingURL=is-generator.mjs.map
