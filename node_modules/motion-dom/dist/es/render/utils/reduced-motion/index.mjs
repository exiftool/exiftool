import { hasReducedMotionListener, prefersReducedMotion } from './state.mjs';

const isBrowser = typeof window !== "undefined";
function initPrefersReducedMotion() {
    hasReducedMotionListener.current = true;
    if (!isBrowser)
        return;
    if (window.matchMedia) {
        const motionMediaQuery = window.matchMedia("(prefers-reduced-motion)");
        const setReducedMotionPreferences = () => (prefersReducedMotion.current = motionMediaQuery.matches);
        motionMediaQuery.addEventListener("change", setReducedMotionPreferences);
        setReducedMotionPreferences();
    }
    else {
        prefersReducedMotion.current = false;
    }
}

export { hasReducedMotionListener, initPrefersReducedMotion, prefersReducedMotion };
//# sourceMappingURL=index.mjs.map
