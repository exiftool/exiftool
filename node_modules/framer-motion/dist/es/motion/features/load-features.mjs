import { setFeatureDefinitions } from 'motion-dom';
import { getInitializedFeatureDefinitions } from './definitions.mjs';

function loadFeatures(features) {
    const featureDefinitions = getInitializedFeatureDefinitions();
    for (const key in features) {
        featureDefinitions[key] = {
            ...featureDefinitions[key],
            ...features[key],
        };
    }
    setFeatureDefinitions(featureDefinitions);
}

export { loadFeatures };
//# sourceMappingURL=load-features.mjs.map
