(function (global, factory) {
    typeof exports === 'object' && typeof module !== 'undefined' ? factory(exports, require('motion-utils')) :
    typeof define === 'function' && define.amd ? define(['exports', 'motion-utils'], factory) :
    (global = typeof globalThis !== 'undefined' ? globalThis : global || self, factory(global.MotionDom = {}, global.MotionUtils));
})(this, (function (exports, motionUtils) { 'use strict';

    const stepsOrder = [
        "setup", // Compute
        "read", // Read
        "resolveKeyframes", // Write/Read/Write/Read
        "preUpdate", // Compute
        "update", // Compute
        "preRender", // Compute
        "render", // Write
        "postRender", // Compute
    ];

    const statsBuffer = {
        value: null,
        addProjectionMetrics: null,
    };

    function createRenderStep(runNextFrame, stepName) {
        /**
         * We create and reuse two queues, one to queue jobs for the current frame
         * and one for the next. We reuse to avoid triggering GC after x frames.
         */
        let thisFrame = new Set();
        let nextFrame = new Set();
        /**
         * Track whether we're currently processing jobs in this step. This way
         * we can decide whether to schedule new jobs for this frame or next.
         */
        let isProcessing = false;
        let flushNextFrame = false;
        /**
         * A set of processes which were marked keepAlive when scheduled.
         */
        const toKeepAlive = new WeakSet();
        let latestFrameData = {
            delta: 0.0,
            timestamp: 0.0,
            isProcessing: false,
        };
        let numCalls = 0;
        function triggerCallback(callback) {
            if (toKeepAlive.has(callback)) {
                step.schedule(callback);
                runNextFrame();
            }
            numCalls++;
            callback(latestFrameData);
        }
        const step = {
            /**
             * Schedule a process to run on the next frame.
             */
            schedule: (callback, keepAlive = false, immediate = false) => {
                const addToCurrentFrame = immediate && isProcessing;
                const queue = addToCurrentFrame ? thisFrame : nextFrame;
                if (keepAlive)
                    toKeepAlive.add(callback);
                if (!queue.has(callback))
                    queue.add(callback);
                return callback;
            },
            /**
             * Cancel the provided callback from running on the next frame.
             */
            cancel: (callback) => {
                nextFrame.delete(callback);
                toKeepAlive.delete(callback);
            },
            /**
             * Execute all schedule callbacks.
             */
            process: (frameData) => {
                latestFrameData = frameData;
                /**
                 * If we're already processing we've probably been triggered by a flushSync
                 * inside an existing process. Instead of executing, mark flushNextFrame
                 * as true and ensure we flush the following frame at the end of this one.
                 */
                if (isProcessing) {
                    flushNextFrame = true;
                    return;
                }
                isProcessing = true;
                [thisFrame, nextFrame] = [nextFrame, thisFrame];
                // Execute this frame
                thisFrame.forEach(triggerCallback);
                /**
                 * If we're recording stats then
                 */
                if (stepName && statsBuffer.value) {
                    statsBuffer.value.frameloop[stepName].push(numCalls);
                }
                numCalls = 0;
                // Clear the frame so no callbacks remain. This is to avoid
                // memory leaks should this render step not run for a while.
                thisFrame.clear();
                isProcessing = false;
                if (flushNextFrame) {
                    flushNextFrame = false;
                    step.process(frameData);
                }
            },
        };
        return step;
    }

    const maxElapsed = 40;
    function createRenderBatcher(scheduleNextBatch, allowKeepAlive) {
        let runNextFrame = false;
        let useDefaultElapsed = true;
        const state = {
            delta: 0.0,
            timestamp: 0.0,
            isProcessing: false,
        };
        const flagRunNextFrame = () => (runNextFrame = true);
        const steps = stepsOrder.reduce((acc, key) => {
            acc[key] = createRenderStep(flagRunNextFrame, allowKeepAlive ? key : undefined);
            return acc;
        }, {});
        const { setup, read, resolveKeyframes, preUpdate, update, preRender, render, postRender, } = steps;
        const processBatch = () => {
            const timestamp = motionUtils.MotionGlobalConfig.useManualTiming
                ? state.timestamp
                : performance.now();
            runNextFrame = false;
            if (!motionUtils.MotionGlobalConfig.useManualTiming) {
                state.delta = useDefaultElapsed
                    ? 1000 / 60
                    : Math.max(Math.min(timestamp - state.timestamp, maxElapsed), 1);
            }
            state.timestamp = timestamp;
            state.isProcessing = true;
            // Unrolled render loop for better per-frame performance
            setup.process(state);
            read.process(state);
            resolveKeyframes.process(state);
            preUpdate.process(state);
            update.process(state);
            preRender.process(state);
            render.process(state);
            postRender.process(state);
            state.isProcessing = false;
            if (runNextFrame && allowKeepAlive) {
                useDefaultElapsed = false;
                scheduleNextBatch(processBatch);
            }
        };
        const wake = () => {
            runNextFrame = true;
            useDefaultElapsed = true;
            if (!state.isProcessing) {
                scheduleNextBatch(processBatch);
            }
        };
        const schedule = stepsOrder.reduce((acc, key) => {
            const step = steps[key];
            acc[key] = (process, keepAlive = false, immediate = false) => {
                if (!runNextFrame)
                    wake();
                return step.schedule(process, keepAlive, immediate);
            };
            return acc;
        }, {});
        const cancel = (process) => {
            for (let i = 0; i < stepsOrder.length; i++) {
                steps[stepsOrder[i]].cancel(process);
            }
        };
        return { schedule, cancel, state, steps };
    }

    const { schedule: frame, cancel: cancelFrame, state: frameData, steps: frameSteps, } = /* @__PURE__ */ createRenderBatcher(typeof requestAnimationFrame !== "undefined" ? requestAnimationFrame : motionUtils.noop, true);

    let now;
    function clearTime() {
        now = undefined;
    }
    /**
     * An eventloop-synchronous alternative to performance.now().
     *
     * Ensures that time measurements remain consistent within a synchronous context.
     * Usually calling performance.now() twice within the same synchronous context
     * will return different values which isn't useful for animations when we're usually
     * trying to sync animations to the same frame.
     */
    const time = {
        now: () => {
            if (now === undefined) {
                time.set(frameData.isProcessing || motionUtils.MotionGlobalConfig.useManualTiming
                    ? frameData.timestamp
                    : performance.now());
            }
            return now;
        },
        set: (newTime) => {
            now = newTime;
            queueMicrotask(clearTime);
        },
    };

    const activeAnimations = {
        layout: 0,
        mainThread: 0,
        waapi: 0,
    };

    const checkStringStartsWith = (token) => (key) => typeof key === "string" && key.startsWith(token);
    const isCSSVariableName = 
    /*@__PURE__*/ checkStringStartsWith("--");
    const startsAsVariableToken = 
    /*@__PURE__*/ checkStringStartsWith("var(--");
    const isCSSVariableToken = (value) => {
        const startsWithToken = startsAsVariableToken(value);
        if (!startsWithToken)
            return false;
        // Ensure any comments are stripped from the value as this can harm performance of the regex.
        return singleCssVariableRegex.test(value.split("/*")[0].trim());
    };
    const singleCssVariableRegex = /var\(--(?:[\w-]+\s*|[\w-]+\s*,(?:\s*[^)(\s]|\s*\((?:[^)(]|\([^)(]*\))*\))+\s*)\)$/iu;
    /**
     * Check if a value contains a CSS variable anywhere (e.g. inside calc()).
     * Unlike isCSSVariableToken which checks if the value IS a var() token,
     * this checks if the value CONTAINS var() somewhere in the string.
     */
    function containsCSSVariable(value) {
        if (typeof value !== "string")
            return false;
        // Strip comments to avoid false positives
        return value.split("/*")[0].includes("var(--");
    }

    const number = {
        test: (v) => typeof v === "number",
        parse: parseFloat,
        transform: (v) => v,
    };
    const alpha = {
        ...number,
        transform: (v) => motionUtils.clamp(0, 1, v),
    };
    const scale = {
        ...number,
        default: 1,
    };

    // If this number is a decimal, make it just five decimal places
    // to avoid exponents
    const sanitize = (v) => Math.round(v * 100000) / 100000;

    const floatRegex = /-?(?:\d+(?:\.\d+)?|\.\d+)/gu;

    function isNullish(v) {
        return v == null;
    }

    const singleColorRegex = /^(?:#[\da-f]{3,8}|(?:rgb|hsl)a?\((?:-?[\d.]+%?[,\s]+){2}-?[\d.]+%?\s*(?:[,/]\s*)?(?:\b\d+(?:\.\d+)?|\.\d+)?%?\))$/iu;

    /**
     * Returns true if the provided string is a color, ie rgba(0,0,0,0) or #000,
     * but false if a number or multiple colors
     */
    const isColorString = (type, testProp) => (v) => {
        return Boolean((typeof v === "string" &&
            singleColorRegex.test(v) &&
            v.startsWith(type)) ||
            (testProp &&
                !isNullish(v) &&
                Object.prototype.hasOwnProperty.call(v, testProp)));
    };
    const splitColor = (aName, bName, cName) => (v) => {
        if (typeof v !== "string")
            return v;
        const [a, b, c, alpha] = v.match(floatRegex);
        return {
            [aName]: parseFloat(a),
            [bName]: parseFloat(b),
            [cName]: parseFloat(c),
            alpha: alpha !== undefined ? parseFloat(alpha) : 1,
        };
    };

    const clampRgbUnit = (v) => motionUtils.clamp(0, 255, v);
    const rgbUnit = {
        ...number,
        transform: (v) => Math.round(clampRgbUnit(v)),
    };
    const rgba = {
        test: /*@__PURE__*/ isColorString("rgb", "red"),
        parse: /*@__PURE__*/ splitColor("red", "green", "blue"),
        transform: ({ red, green, blue, alpha: alpha$1 = 1 }) => "rgba(" +
            rgbUnit.transform(red) +
            ", " +
            rgbUnit.transform(green) +
            ", " +
            rgbUnit.transform(blue) +
            ", " +
            sanitize(alpha.transform(alpha$1)) +
            ")",
    };

    function parseHex(v) {
        let r = "";
        let g = "";
        let b = "";
        let a = "";
        // If we have 6 characters, ie #FF0000
        if (v.length > 5) {
            r = v.substring(1, 3);
            g = v.substring(3, 5);
            b = v.substring(5, 7);
            a = v.substring(7, 9);
            // Or we have 3 characters, ie #F00
        }
        else {
            r = v.substring(1, 2);
            g = v.substring(2, 3);
            b = v.substring(3, 4);
            a = v.substring(4, 5);
            r += r;
            g += g;
            b += b;
            a += a;
        }
        return {
            red: parseInt(r, 16),
            green: parseInt(g, 16),
            blue: parseInt(b, 16),
            alpha: a ? parseInt(a, 16) / 255 : 1,
        };
    }
    const hex = {
        test: /*@__PURE__*/ isColorString("#"),
        parse: parseHex,
        transform: rgba.transform,
    };

    /*#__NO_SIDE_EFFECTS__*/
    const createUnitType = (unit) => ({
        test: (v) => typeof v === "string" && v.endsWith(unit) && v.split(" ").length === 1,
        parse: parseFloat,
        transform: (v) => `${v}${unit}`,
    });
    const degrees = /*@__PURE__*/ createUnitType("deg");
    const percent = /*@__PURE__*/ createUnitType("%");
    const px = /*@__PURE__*/ createUnitType("px");
    const vh = /*@__PURE__*/ createUnitType("vh");
    const vw = /*@__PURE__*/ createUnitType("vw");
    const progressPercentage = /*@__PURE__*/ (() => ({
        ...percent,
        parse: (v) => percent.parse(v) / 100,
        transform: (v) => percent.transform(v * 100),
    }))();

    const hsla = {
        test: /*@__PURE__*/ isColorString("hsl", "hue"),
        parse: /*@__PURE__*/ splitColor("hue", "saturation", "lightness"),
        transform: ({ hue, saturation, lightness, alpha: alpha$1 = 1 }) => {
            return ("hsla(" +
                Math.round(hue) +
                ", " +
                percent.transform(sanitize(saturation)) +
                ", " +
                percent.transform(sanitize(lightness)) +
                ", " +
                sanitize(alpha.transform(alpha$1)) +
                ")");
        },
    };

    const color = {
        test: (v) => rgba.test(v) || hex.test(v) || hsla.test(v),
        parse: (v) => {
            if (rgba.test(v)) {
                return rgba.parse(v);
            }
            else if (hsla.test(v)) {
                return hsla.parse(v);
            }
            else {
                return hex.parse(v);
            }
        },
        transform: (v) => {
            return typeof v === "string"
                ? v
                : v.hasOwnProperty("red")
                    ? rgba.transform(v)
                    : hsla.transform(v);
        },
        getAnimatableNone: (v) => {
            const parsed = color.parse(v);
            parsed.alpha = 0;
            return color.transform(parsed);
        },
    };

    const colorRegex = /(?:#[\da-f]{3,8}|(?:rgb|hsl)a?\((?:-?[\d.]+%?[,\s]+){2}-?[\d.]+%?\s*(?:[,/]\s*)?(?:\b\d+(?:\.\d+)?|\.\d+)?%?\))/giu;

    function test(v) {
        return (isNaN(v) &&
            typeof v === "string" &&
            (v.match(floatRegex)?.length || 0) +
                (v.match(colorRegex)?.length || 0) >
                0);
    }
    const NUMBER_TOKEN = "number";
    const COLOR_TOKEN = "color";
    const VAR_TOKEN = "var";
    const VAR_FUNCTION_TOKEN = "var(";
    const SPLIT_TOKEN = "${}";
    // this regex consists of the `singleCssVariableRegex|rgbHSLValueRegex|digitRegex`
    const complexRegex = /var\s*\(\s*--(?:[\w-]+\s*|[\w-]+\s*,(?:\s*[^)(\s]|\s*\((?:[^)(]|\([^)(]*\))*\))+\s*)\)|#[\da-f]{3,8}|(?:rgb|hsl)a?\((?:-?[\d.]+%?[,\s]+){2}-?[\d.]+%?\s*(?:[,/]\s*)?(?:\b\d+(?:\.\d+)?|\.\d+)?%?\)|-?(?:\d+(?:\.\d+)?|\.\d+)/giu;
    function analyseComplexValue(value) {
        const originalValue = value.toString();
        const values = [];
        const indexes = {
            color: [],
            number: [],
            var: [],
        };
        const types = [];
        let i = 0;
        const tokenised = originalValue.replace(complexRegex, (parsedValue) => {
            if (color.test(parsedValue)) {
                indexes.color.push(i);
                types.push(COLOR_TOKEN);
                values.push(color.parse(parsedValue));
            }
            else if (parsedValue.startsWith(VAR_FUNCTION_TOKEN)) {
                indexes.var.push(i);
                types.push(VAR_TOKEN);
                values.push(parsedValue);
            }
            else {
                indexes.number.push(i);
                types.push(NUMBER_TOKEN);
                values.push(parseFloat(parsedValue));
            }
            ++i;
            return SPLIT_TOKEN;
        });
        const split = tokenised.split(SPLIT_TOKEN);
        return { values, split, indexes, types };
    }
    function parseComplexValue(v) {
        return analyseComplexValue(v).values;
    }
    function createTransformer(source) {
        const { split, types } = analyseComplexValue(source);
        const numSections = split.length;
        return (v) => {
            let output = "";
            for (let i = 0; i < numSections; i++) {
                output += split[i];
                if (v[i] !== undefined) {
                    const type = types[i];
                    if (type === NUMBER_TOKEN) {
                        output += sanitize(v[i]);
                    }
                    else if (type === COLOR_TOKEN) {
                        output += color.transform(v[i]);
                    }
                    else {
                        output += v[i];
                    }
                }
            }
            return output;
        };
    }
    const convertNumbersToZero = (v) => typeof v === "number" ? 0 : color.test(v) ? color.getAnimatableNone(v) : v;
    function getAnimatableNone$1(v) {
        const parsed = parseComplexValue(v);
        const transformer = createTransformer(v);
        return transformer(parsed.map(convertNumbersToZero));
    }
    const complex = {
        test,
        parse: parseComplexValue,
        createTransformer,
        getAnimatableNone: getAnimatableNone$1,
    };

    // Adapted from https://gist.github.com/mjackson/5311256
    function hueToRgb(p, q, t) {
        if (t < 0)
            t += 1;
        if (t > 1)
            t -= 1;
        if (t < 1 / 6)
            return p + (q - p) * 6 * t;
        if (t < 1 / 2)
            return q;
        if (t < 2 / 3)
            return p + (q - p) * (2 / 3 - t) * 6;
        return p;
    }
    function hslaToRgba({ hue, saturation, lightness, alpha }) {
        hue /= 360;
        saturation /= 100;
        lightness /= 100;
        let red = 0;
        let green = 0;
        let blue = 0;
        if (!saturation) {
            red = green = blue = lightness;
        }
        else {
            const q = lightness < 0.5
                ? lightness * (1 + saturation)
                : lightness + saturation - lightness * saturation;
            const p = 2 * lightness - q;
            red = hueToRgb(p, q, hue + 1 / 3);
            green = hueToRgb(p, q, hue);
            blue = hueToRgb(p, q, hue - 1 / 3);
        }
        return {
            red: Math.round(red * 255),
            green: Math.round(green * 255),
            blue: Math.round(blue * 255),
            alpha,
        };
    }

    function mixImmediate(a, b) {
        return (p) => (p > 0 ? b : a);
    }

    /*
      Value in range from progress

      Given a lower limit and an upper limit, we return the value within
      that range as expressed by progress (usually a number from 0 to 1)

      So progress = 0.5 would change

      from -------- to

      to

      from ---- to

      E.g. from = 10, to = 20, progress = 0.5 => 15

      @param [number]: Lower limit of range
      @param [number]: Upper limit of range
      @param [number]: The progress between lower and upper limits expressed 0-1
      @return [number]: Value as calculated from progress within range (not limited within range)
    */
    const mixNumber$1 = (from, to, progress) => {
        return from + (to - from) * progress;
    };

    // Linear color space blending
    // Explained https://www.youtube.com/watch?v=LKnqECcg6Gw
    // Demonstrated http://codepen.io/osublake/pen/xGVVaN
    const mixLinearColor = (from, to, v) => {
        const fromExpo = from * from;
        const expo = v * (to * to - fromExpo) + fromExpo;
        return expo < 0 ? 0 : Math.sqrt(expo);
    };
    const colorTypes = [hex, rgba, hsla];
    const getColorType = (v) => colorTypes.find((type) => type.test(v));
    function asRGBA(color) {
        const type = getColorType(color);
        motionUtils.warning(Boolean(type), `'${color}' is not an animatable color. Use the equivalent color code instead.`, "color-not-animatable");
        if (!Boolean(type))
            return false;
        let model = type.parse(color);
        if (type === hsla) {
            // TODO Remove this cast - needed since Motion's stricter typing
            model = hslaToRgba(model);
        }
        return model;
    }
    const mixColor = (from, to) => {
        const fromRGBA = asRGBA(from);
        const toRGBA = asRGBA(to);
        if (!fromRGBA || !toRGBA) {
            return mixImmediate(from, to);
        }
        const blended = { ...fromRGBA };
        return (v) => {
            blended.red = mixLinearColor(fromRGBA.red, toRGBA.red, v);
            blended.green = mixLinearColor(fromRGBA.green, toRGBA.green, v);
            blended.blue = mixLinearColor(fromRGBA.blue, toRGBA.blue, v);
            blended.alpha = mixNumber$1(fromRGBA.alpha, toRGBA.alpha, v);
            return rgba.transform(blended);
        };
    };

    const invisibleValues = new Set(["none", "hidden"]);
    /**
     * Returns a function that, when provided a progress value between 0 and 1,
     * will return the "none" or "hidden" string only when the progress is that of
     * the origin or target.
     */
    function mixVisibility(origin, target) {
        if (invisibleValues.has(origin)) {
            return (p) => (p <= 0 ? origin : target);
        }
        else {
            return (p) => (p >= 1 ? target : origin);
        }
    }

    function mixNumber(a, b) {
        return (p) => mixNumber$1(a, b, p);
    }
    function getMixer(a) {
        if (typeof a === "number") {
            return mixNumber;
        }
        else if (typeof a === "string") {
            return isCSSVariableToken(a)
                ? mixImmediate
                : color.test(a)
                    ? mixColor
                    : mixComplex;
        }
        else if (Array.isArray(a)) {
            return mixArray;
        }
        else if (typeof a === "object") {
            return color.test(a) ? mixColor : mixObject;
        }
        return mixImmediate;
    }
    function mixArray(a, b) {
        const output = [...a];
        const numValues = output.length;
        const blendValue = a.map((v, i) => getMixer(v)(v, b[i]));
        return (p) => {
            for (let i = 0; i < numValues; i++) {
                output[i] = blendValue[i](p);
            }
            return output;
        };
    }
    function mixObject(a, b) {
        const output = { ...a, ...b };
        const blendValue = {};
        for (const key in output) {
            if (a[key] !== undefined && b[key] !== undefined) {
                blendValue[key] = getMixer(a[key])(a[key], b[key]);
            }
        }
        return (v) => {
            for (const key in blendValue) {
                output[key] = blendValue[key](v);
            }
            return output;
        };
    }
    function matchOrder(origin, target) {
        const orderedOrigin = [];
        const pointers = { color: 0, var: 0, number: 0 };
        for (let i = 0; i < target.values.length; i++) {
            const type = target.types[i];
            const originIndex = origin.indexes[type][pointers[type]];
            const originValue = origin.values[originIndex] ?? 0;
            orderedOrigin[i] = originValue;
            pointers[type]++;
        }
        return orderedOrigin;
    }
    const mixComplex = (origin, target) => {
        const template = complex.createTransformer(target);
        const originStats = analyseComplexValue(origin);
        const targetStats = analyseComplexValue(target);
        const canInterpolate = originStats.indexes.var.length === targetStats.indexes.var.length &&
            originStats.indexes.color.length === targetStats.indexes.color.length &&
            originStats.indexes.number.length >= targetStats.indexes.number.length;
        if (canInterpolate) {
            if ((invisibleValues.has(origin) &&
                !targetStats.values.length) ||
                (invisibleValues.has(target) &&
                    !originStats.values.length)) {
                return mixVisibility(origin, target);
            }
            return motionUtils.pipe(mixArray(matchOrder(originStats, targetStats), targetStats.values), template);
        }
        else {
            motionUtils.warning(true, `Complex values '${origin}' and '${target}' too different to mix. Ensure all colors are of the same type, and that each contains the same quantity of number and color values. Falling back to instant transition.`, "complex-values-different");
            return mixImmediate(origin, target);
        }
    };

    function mix(from, to, p) {
        if (typeof from === "number" &&
            typeof to === "number" &&
            typeof p === "number") {
            return mixNumber$1(from, to, p);
        }
        const mixer = getMixer(from);
        return mixer(from, to);
    }

    const frameloopDriver = (update) => {
        const passTimestamp = ({ timestamp }) => update(timestamp);
        return {
            start: (keepAlive = true) => frame.update(passTimestamp, keepAlive),
            stop: () => cancelFrame(passTimestamp),
            /**
             * If we're processing this frame we can use the
             * framelocked timestamp to keep things in sync.
             */
            now: () => (frameData.isProcessing ? frameData.timestamp : time.now()),
        };
    };

    const generateLinearEasing = (easing, duration, // as milliseconds
    resolution = 10 // as milliseconds
    ) => {
        let points = "";
        const numPoints = Math.max(Math.round(duration / resolution), 2);
        for (let i = 0; i < numPoints; i++) {
            points += Math.round(easing(i / (numPoints - 1)) * 10000) / 10000 + ", ";
        }
        return `linear(${points.substring(0, points.length - 2)})`;
    };

    /**
     * Implement a practical max duration for keyframe generation
     * to prevent infinite loops
     */
    const maxGeneratorDuration = 20000;
    function calcGeneratorDuration(generator) {
        let duration = 0;
        const timeStep = 50;
        let state = generator.next(duration);
        while (!state.done && duration < maxGeneratorDuration) {
            duration += timeStep;
            state = generator.next(duration);
        }
        return duration >= maxGeneratorDuration ? Infinity : duration;
    }

    /**
     * Create a progress => progress easing function from a generator.
     */
    function createGeneratorEasing(options, scale = 100, createGenerator) {
        const generator = createGenerator({ ...options, keyframes: [0, scale] });
        const duration = Math.min(calcGeneratorDuration(generator), maxGeneratorDuration);
        return {
            type: "keyframes",
            ease: (progress) => {
                return generator.next(duration * progress).value / scale;
            },
            duration: motionUtils.millisecondsToSeconds(duration),
        };
    }

    const velocitySampleDuration = 5; // ms
    function calcGeneratorVelocity(resolveValue, t, current) {
        const prevT = Math.max(t - velocitySampleDuration, 0);
        return motionUtils.velocityPerSecond(current - resolveValue(prevT), t - prevT);
    }

    const springDefaults = {
        // Default spring physics
        stiffness: 100,
        damping: 10,
        mass: 1.0,
        velocity: 0.0,
        // Default duration/bounce-based options
        duration: 800, // in ms
        bounce: 0.3,
        visualDuration: 0.3, // in seconds
        // Rest thresholds
        restSpeed: {
            granular: 0.01,
            default: 2,
        },
        restDelta: {
            granular: 0.005,
            default: 0.5,
        },
        // Limits
        minDuration: 0.01, // in seconds
        maxDuration: 10.0, // in seconds
        minDamping: 0.05,
        maxDamping: 1,
    };

    const safeMin = 0.001;
    function findSpring({ duration = springDefaults.duration, bounce = springDefaults.bounce, velocity = springDefaults.velocity, mass = springDefaults.mass, }) {
        let envelope;
        let derivative;
        motionUtils.warning(duration <= motionUtils.secondsToMilliseconds(springDefaults.maxDuration), "Spring duration must be 10 seconds or less", "spring-duration-limit");
        let dampingRatio = 1 - bounce;
        /**
         * Restrict dampingRatio and duration to within acceptable ranges.
         */
        dampingRatio = motionUtils.clamp(springDefaults.minDamping, springDefaults.maxDamping, dampingRatio);
        duration = motionUtils.clamp(springDefaults.minDuration, springDefaults.maxDuration, motionUtils.millisecondsToSeconds(duration));
        if (dampingRatio < 1) {
            /**
             * Underdamped spring
             */
            envelope = (undampedFreq) => {
                const exponentialDecay = undampedFreq * dampingRatio;
                const delta = exponentialDecay * duration;
                const a = exponentialDecay - velocity;
                const b = calcAngularFreq(undampedFreq, dampingRatio);
                const c = Math.exp(-delta);
                return safeMin - (a / b) * c;
            };
            derivative = (undampedFreq) => {
                const exponentialDecay = undampedFreq * dampingRatio;
                const delta = exponentialDecay * duration;
                const d = delta * velocity + velocity;
                const e = Math.pow(dampingRatio, 2) * Math.pow(undampedFreq, 2) * duration;
                const f = Math.exp(-delta);
                const g = calcAngularFreq(Math.pow(undampedFreq, 2), dampingRatio);
                const factor = -envelope(undampedFreq) + safeMin > 0 ? -1 : 1;
                return (factor * ((d - e) * f)) / g;
            };
        }
        else {
            /**
             * Critically-damped spring
             */
            envelope = (undampedFreq) => {
                const a = Math.exp(-undampedFreq * duration);
                const b = (undampedFreq - velocity) * duration + 1;
                return -safeMin + a * b;
            };
            derivative = (undampedFreq) => {
                const a = Math.exp(-undampedFreq * duration);
                const b = (velocity - undampedFreq) * (duration * duration);
                return a * b;
            };
        }
        const initialGuess = 5 / duration;
        const undampedFreq = approximateRoot(envelope, derivative, initialGuess);
        duration = motionUtils.secondsToMilliseconds(duration);
        if (isNaN(undampedFreq)) {
            return {
                stiffness: springDefaults.stiffness,
                damping: springDefaults.damping,
                duration,
            };
        }
        else {
            const stiffness = Math.pow(undampedFreq, 2) * mass;
            return {
                stiffness,
                damping: dampingRatio * 2 * Math.sqrt(mass * stiffness),
                duration,
            };
        }
    }
    const rootIterations = 12;
    function approximateRoot(envelope, derivative, initialGuess) {
        let result = initialGuess;
        for (let i = 1; i < rootIterations; i++) {
            result = result - envelope(result) / derivative(result);
        }
        return result;
    }
    function calcAngularFreq(undampedFreq, dampingRatio) {
        return undampedFreq * Math.sqrt(1 - dampingRatio * dampingRatio);
    }

    const durationKeys = ["duration", "bounce"];
    const physicsKeys = ["stiffness", "damping", "mass"];
    function isSpringType(options, keys) {
        return keys.some((key) => options[key] !== undefined);
    }
    function getSpringOptions(options) {
        let springOptions = {
            velocity: springDefaults.velocity,
            stiffness: springDefaults.stiffness,
            damping: springDefaults.damping,
            mass: springDefaults.mass,
            isResolvedFromDuration: false,
            ...options,
        };
        // stiffness/damping/mass overrides duration/bounce
        if (!isSpringType(options, physicsKeys) &&
            isSpringType(options, durationKeys)) {
            if (options.visualDuration) {
                const visualDuration = options.visualDuration;
                const root = (2 * Math.PI) / (visualDuration * 1.2);
                const stiffness = root * root;
                const damping = 2 *
                    motionUtils.clamp(0.05, 1, 1 - (options.bounce || 0)) *
                    Math.sqrt(stiffness);
                springOptions = {
                    ...springOptions,
                    mass: springDefaults.mass,
                    stiffness,
                    damping,
                };
            }
            else {
                const derived = findSpring(options);
                springOptions = {
                    ...springOptions,
                    ...derived,
                    mass: springDefaults.mass,
                };
                springOptions.isResolvedFromDuration = true;
            }
        }
        return springOptions;
    }
    function spring(optionsOrVisualDuration = springDefaults.visualDuration, bounce = springDefaults.bounce) {
        const options = typeof optionsOrVisualDuration !== "object"
            ? {
                visualDuration: optionsOrVisualDuration,
                keyframes: [0, 1],
                bounce,
            }
            : optionsOrVisualDuration;
        let { restSpeed, restDelta } = options;
        const origin = options.keyframes[0];
        const target = options.keyframes[options.keyframes.length - 1];
        /**
         * This is the Iterator-spec return value. We ensure it's mutable rather than using a generator
         * to reduce GC during animation.
         */
        const state = { done: false, value: origin };
        const { stiffness, damping, mass, duration, velocity, isResolvedFromDuration, } = getSpringOptions({
            ...options,
            velocity: -motionUtils.millisecondsToSeconds(options.velocity || 0),
        });
        const initialVelocity = velocity || 0.0;
        const dampingRatio = damping / (2 * Math.sqrt(stiffness * mass));
        const initialDelta = target - origin;
        const undampedAngularFreq = motionUtils.millisecondsToSeconds(Math.sqrt(stiffness / mass));
        /**
         * If we're working on a granular scale, use smaller defaults for determining
         * when the spring is finished.
         *
         * These defaults have been selected emprically based on what strikes a good
         * ratio between feeling good and finishing as soon as changes are imperceptible.
         */
        const isGranularScale = Math.abs(initialDelta) < 5;
        restSpeed || (restSpeed = isGranularScale
            ? springDefaults.restSpeed.granular
            : springDefaults.restSpeed.default);
        restDelta || (restDelta = isGranularScale
            ? springDefaults.restDelta.granular
            : springDefaults.restDelta.default);
        let resolveSpring;
        if (dampingRatio < 1) {
            const angularFreq = calcAngularFreq(undampedAngularFreq, dampingRatio);
            // Underdamped spring
            resolveSpring = (t) => {
                const envelope = Math.exp(-dampingRatio * undampedAngularFreq * t);
                return (target -
                    envelope *
                        (((initialVelocity +
                            dampingRatio * undampedAngularFreq * initialDelta) /
                            angularFreq) *
                            Math.sin(angularFreq * t) +
                            initialDelta * Math.cos(angularFreq * t)));
            };
        }
        else if (dampingRatio === 1) {
            // Critically damped spring
            resolveSpring = (t) => target -
                Math.exp(-undampedAngularFreq * t) *
                    (initialDelta +
                        (initialVelocity + undampedAngularFreq * initialDelta) * t);
        }
        else {
            // Overdamped spring
            const dampedAngularFreq = undampedAngularFreq * Math.sqrt(dampingRatio * dampingRatio - 1);
            resolveSpring = (t) => {
                const envelope = Math.exp(-dampingRatio * undampedAngularFreq * t);
                // When performing sinh or cosh values can hit Infinity so we cap them here
                const freqForT = Math.min(dampedAngularFreq * t, 300);
                return (target -
                    (envelope *
                        ((initialVelocity +
                            dampingRatio * undampedAngularFreq * initialDelta) *
                            Math.sinh(freqForT) +
                            dampedAngularFreq *
                                initialDelta *
                                Math.cosh(freqForT))) /
                        dampedAngularFreq);
            };
        }
        const generator = {
            calculatedDuration: isResolvedFromDuration ? duration || null : null,
            next: (t) => {
                const current = resolveSpring(t);
                if (!isResolvedFromDuration) {
                    let currentVelocity = t === 0 ? initialVelocity : 0.0;
                    /**
                     * We only need to calculate velocity for under-damped springs
                     * as over- and critically-damped springs can't overshoot, so
                     * checking only for displacement is enough.
                     */
                    if (dampingRatio < 1) {
                        currentVelocity =
                            t === 0
                                ? motionUtils.secondsToMilliseconds(initialVelocity)
                                : calcGeneratorVelocity(resolveSpring, t, current);
                    }
                    const isBelowVelocityThreshold = Math.abs(currentVelocity) <= restSpeed;
                    const isBelowDisplacementThreshold = Math.abs(target - current) <= restDelta;
                    state.done =
                        isBelowVelocityThreshold && isBelowDisplacementThreshold;
                }
                else {
                    state.done = t >= duration;
                }
                state.value = state.done ? target : current;
                return state;
            },
            toString: () => {
                const calculatedDuration = Math.min(calcGeneratorDuration(generator), maxGeneratorDuration);
                const easing = generateLinearEasing((progress) => generator.next(calculatedDuration * progress).value, calculatedDuration, 30);
                return calculatedDuration + "ms " + easing;
            },
            toTransition: () => { },
        };
        return generator;
    }
    spring.applyToOptions = (options) => {
        const generatorOptions = createGeneratorEasing(options, 100, spring);
        options.ease = generatorOptions.ease;
        options.duration = motionUtils.secondsToMilliseconds(generatorOptions.duration);
        options.type = "keyframes";
        return options;
    };

    function inertia({ keyframes, velocity = 0.0, power = 0.8, timeConstant = 325, bounceDamping = 10, bounceStiffness = 500, modifyTarget, min, max, restDelta = 0.5, restSpeed, }) {
        const origin = keyframes[0];
        const state = {
            done: false,
            value: origin,
        };
        const isOutOfBounds = (v) => (min !== undefined && v < min) || (max !== undefined && v > max);
        const nearestBoundary = (v) => {
            if (min === undefined)
                return max;
            if (max === undefined)
                return min;
            return Math.abs(min - v) < Math.abs(max - v) ? min : max;
        };
        let amplitude = power * velocity;
        const ideal = origin + amplitude;
        const target = modifyTarget === undefined ? ideal : modifyTarget(ideal);
        /**
         * If the target has changed we need to re-calculate the amplitude, otherwise
         * the animation will start from the wrong position.
         */
        if (target !== ideal)
            amplitude = target - origin;
        const calcDelta = (t) => -amplitude * Math.exp(-t / timeConstant);
        const calcLatest = (t) => target + calcDelta(t);
        const applyFriction = (t) => {
            const delta = calcDelta(t);
            const latest = calcLatest(t);
            state.done = Math.abs(delta) <= restDelta;
            state.value = state.done ? target : latest;
        };
        /**
         * Ideally this would resolve for t in a stateless way, we could
         * do that by always precalculating the animation but as we know
         * this will be done anyway we can assume that spring will
         * be discovered during that.
         */
        let timeReachedBoundary;
        let spring$1;
        const checkCatchBoundary = (t) => {
            if (!isOutOfBounds(state.value))
                return;
            timeReachedBoundary = t;
            spring$1 = spring({
                keyframes: [state.value, nearestBoundary(state.value)],
                velocity: calcGeneratorVelocity(calcLatest, t, state.value), // TODO: This should be passing * 1000
                damping: bounceDamping,
                stiffness: bounceStiffness,
                restDelta,
                restSpeed,
            });
        };
        checkCatchBoundary(0);
        return {
            calculatedDuration: null,
            next: (t) => {
                /**
                 * We need to resolve the friction to figure out if we need a
                 * spring but we don't want to do this twice per frame. So here
                 * we flag if we updated for this frame and later if we did
                 * we can skip doing it again.
                 */
                let hasUpdatedFrame = false;
                if (!spring$1 && timeReachedBoundary === undefined) {
                    hasUpdatedFrame = true;
                    applyFriction(t);
                    checkCatchBoundary(t);
                }
                /**
                 * If we have a spring and the provided t is beyond the moment the friction
                 * animation crossed the min/max boundary, use the spring.
                 */
                if (timeReachedBoundary !== undefined && t >= timeReachedBoundary) {
                    return spring$1.next(t - timeReachedBoundary);
                }
                else {
                    !hasUpdatedFrame && applyFriction(t);
                    return state;
                }
            },
        };
    }

    function createMixers(output, ease, customMixer) {
        const mixers = [];
        const mixerFactory = customMixer || motionUtils.MotionGlobalConfig.mix || mix;
        const numMixers = output.length - 1;
        for (let i = 0; i < numMixers; i++) {
            let mixer = mixerFactory(output[i], output[i + 1]);
            if (ease) {
                const easingFunction = Array.isArray(ease) ? ease[i] || motionUtils.noop : ease;
                mixer = motionUtils.pipe(easingFunction, mixer);
            }
            mixers.push(mixer);
        }
        return mixers;
    }
    /**
     * Create a function that maps from a numerical input array to a generic output array.
     *
     * Accepts:
     *   - Numbers
     *   - Colors (hex, hsl, hsla, rgb, rgba)
     *   - Complex (combinations of one or more numbers or strings)
     *
     * ```jsx
     * const mixColor = interpolate([0, 1], ['#fff', '#000'])
     *
     * mixColor(0.5) // 'rgba(128, 128, 128, 1)'
     * ```
     *
     * TODO Revisit this approach once we've moved to data models for values,
     * probably not needed to pregenerate mixer functions.
     *
     * @public
     */
    function interpolate(input, output, { clamp: isClamp = true, ease, mixer } = {}) {
        const inputLength = input.length;
        motionUtils.invariant(inputLength === output.length, "Both input and output ranges must be the same length", "range-length");
        /**
         * If we're only provided a single input, we can just make a function
         * that returns the output.
         */
        if (inputLength === 1)
            return () => output[0];
        if (inputLength === 2 && output[0] === output[1])
            return () => output[1];
        const isZeroDeltaRange = input[0] === input[1];
        // If input runs highest -> lowest, reverse both arrays
        if (input[0] > input[inputLength - 1]) {
            input = [...input].reverse();
            output = [...output].reverse();
        }
        const mixers = createMixers(output, ease, mixer);
        const numMixers = mixers.length;
        const interpolator = (v) => {
            if (isZeroDeltaRange && v < input[0])
                return output[0];
            let i = 0;
            if (numMixers > 1) {
                for (; i < input.length - 2; i++) {
                    if (v < input[i + 1])
                        break;
                }
            }
            const progressInRange = motionUtils.progress(input[i], input[i + 1], v);
            return mixers[i](progressInRange);
        };
        return isClamp
            ? (v) => interpolator(motionUtils.clamp(input[0], input[inputLength - 1], v))
            : interpolator;
    }

    function fillOffset(offset, remaining) {
        const min = offset[offset.length - 1];
        for (let i = 1; i <= remaining; i++) {
            const offsetProgress = motionUtils.progress(0, remaining, i);
            offset.push(mixNumber$1(min, 1, offsetProgress));
        }
    }

    function defaultOffset(arr) {
        const offset = [0];
        fillOffset(offset, arr.length - 1);
        return offset;
    }

    function convertOffsetToTimes(offset, duration) {
        return offset.map((o) => o * duration);
    }

    function defaultEasing(values, easing) {
        return values.map(() => easing || motionUtils.easeInOut).splice(0, values.length - 1);
    }
    function keyframes({ duration = 300, keyframes: keyframeValues, times, ease = "easeInOut", }) {
        /**
         * Easing functions can be externally defined as strings. Here we convert them
         * into actual functions.
         */
        const easingFunctions = motionUtils.isEasingArray(ease)
            ? ease.map(motionUtils.easingDefinitionToFunction)
            : motionUtils.easingDefinitionToFunction(ease);
        /**
         * This is the Iterator-spec return value. We ensure it's mutable rather than using a generator
         * to reduce GC during animation.
         */
        const state = {
            done: false,
            value: keyframeValues[0],
        };
        /**
         * Create a times array based on the provided 0-1 offsets
         */
        const absoluteTimes = convertOffsetToTimes(
        // Only use the provided offsets if they're the correct length
        // TODO Maybe we should warn here if there's a length mismatch
        times && times.length === keyframeValues.length
            ? times
            : defaultOffset(keyframeValues), duration);
        const mapTimeToKeyframe = interpolate(absoluteTimes, keyframeValues, {
            ease: Array.isArray(easingFunctions)
                ? easingFunctions
                : defaultEasing(keyframeValues, easingFunctions),
        });
        return {
            calculatedDuration: duration,
            next: (t) => {
                state.value = mapTimeToKeyframe(t);
                state.done = t >= duration;
                return state;
            },
        };
    }

    const isNotNull$1 = (value) => value !== null;
    function getFinalKeyframe$1(keyframes, { repeat, repeatType = "loop" }, finalKeyframe, speed = 1) {
        const resolvedKeyframes = keyframes.filter(isNotNull$1);
        const useFirstKeyframe = speed < 0 || (repeat && repeatType !== "loop" && repeat % 2 === 1);
        const index = useFirstKeyframe ? 0 : resolvedKeyframes.length - 1;
        return !index || finalKeyframe === undefined
            ? resolvedKeyframes[index]
            : finalKeyframe;
    }

    const transitionTypeMap = {
        decay: inertia,
        inertia,
        tween: keyframes,
        keyframes: keyframes,
        spring,
    };
    function replaceTransitionType(transition) {
        if (typeof transition.type === "string") {
            transition.type = transitionTypeMap[transition.type];
        }
    }

    class WithPromise {
        constructor() {
            this.updateFinished();
        }
        get finished() {
            return this._finished;
        }
        updateFinished() {
            this._finished = new Promise((resolve) => {
                this.resolve = resolve;
            });
        }
        notifyFinished() {
            this.resolve();
        }
        /**
         * Allows the animation to be awaited.
         *
         * @deprecated Use `finished` instead.
         */
        then(onResolve, onReject) {
            return this.finished.then(onResolve, onReject);
        }
    }

    const percentToProgress = (percent) => percent / 100;
    class JSAnimation extends WithPromise {
        constructor(options) {
            super();
            this.state = "idle";
            this.startTime = null;
            this.isStopped = false;
            /**
             * The current time of the animation.
             */
            this.currentTime = 0;
            /**
             * The time at which the animation was paused.
             */
            this.holdTime = null;
            /**
             * Playback speed as a factor. 0 would be stopped, -1 reverse and 2 double speed.
             */
            this.playbackSpeed = 1;
            /**
             * This method is bound to the instance to fix a pattern where
             * animation.stop is returned as a reference from a useEffect.
             */
            this.stop = () => {
                const { motionValue } = this.options;
                if (motionValue && motionValue.updatedAt !== time.now()) {
                    this.tick(time.now());
                }
                this.isStopped = true;
                if (this.state === "idle")
                    return;
                this.teardown();
                this.options.onStop?.();
            };
            activeAnimations.mainThread++;
            this.options = options;
            this.initAnimation();
            this.play();
            if (options.autoplay === false)
                this.pause();
        }
        initAnimation() {
            const { options } = this;
            replaceTransitionType(options);
            const { type = keyframes, repeat = 0, repeatDelay = 0, repeatType, velocity = 0, } = options;
            let { keyframes: keyframes$1 } = options;
            const generatorFactory = type || keyframes;
            if (generatorFactory !== keyframes) {
                motionUtils.invariant(keyframes$1.length <= 2, `Only two keyframes currently supported with spring and inertia animations. Trying to animate ${keyframes$1}`, "spring-two-frames");
            }
            if (generatorFactory !== keyframes &&
                typeof keyframes$1[0] !== "number") {
                this.mixKeyframes = motionUtils.pipe(percentToProgress, mix(keyframes$1[0], keyframes$1[1]));
                keyframes$1 = [0, 100];
            }
            const generator = generatorFactory({ ...options, keyframes: keyframes$1 });
            /**
             * If we have a mirror repeat type we need to create a second generator that outputs the
             * mirrored (not reversed) animation and later ping pong between the two generators.
             */
            if (repeatType === "mirror") {
                this.mirroredGenerator = generatorFactory({
                    ...options,
                    keyframes: [...keyframes$1].reverse(),
                    velocity: -velocity,
                });
            }
            /**
             * If duration is undefined and we have repeat options,
             * we need to calculate a duration from the generator.
             *
             * We set it to the generator itself to cache the duration.
             * Any timeline resolver will need to have already precalculated
             * the duration by this step.
             */
            if (generator.calculatedDuration === null) {
                generator.calculatedDuration = calcGeneratorDuration(generator);
            }
            const { calculatedDuration } = generator;
            this.calculatedDuration = calculatedDuration;
            this.resolvedDuration = calculatedDuration + repeatDelay;
            this.totalDuration = this.resolvedDuration * (repeat + 1) - repeatDelay;
            this.generator = generator;
        }
        updateTime(timestamp) {
            const animationTime = Math.round(timestamp - this.startTime) * this.playbackSpeed;
            // Update currentTime
            if (this.holdTime !== null) {
                this.currentTime = this.holdTime;
            }
            else {
                // Rounding the time because floating point arithmetic is not always accurate, e.g. 3000.367 - 1000.367 =
                // 2000.0000000000002. This is a problem when we are comparing the currentTime with the duration, for
                // example.
                this.currentTime = animationTime;
            }
        }
        tick(timestamp, sample = false) {
            const { generator, totalDuration, mixKeyframes, mirroredGenerator, resolvedDuration, calculatedDuration, } = this;
            if (this.startTime === null)
                return generator.next(0);
            const { delay = 0, keyframes, repeat, repeatType, repeatDelay, type, onUpdate, finalKeyframe, } = this.options;
            /**
             * requestAnimationFrame timestamps can come through as lower than
             * the startTime as set by performance.now(). Here we prevent this,
             * though in the future it could be possible to make setting startTime
             * a pending operation that gets resolved here.
             */
            if (this.speed > 0) {
                this.startTime = Math.min(this.startTime, timestamp);
            }
            else if (this.speed < 0) {
                this.startTime = Math.min(timestamp - totalDuration / this.speed, this.startTime);
            }
            if (sample) {
                this.currentTime = timestamp;
            }
            else {
                this.updateTime(timestamp);
            }
            // Rebase on delay
            const timeWithoutDelay = this.currentTime - delay * (this.playbackSpeed >= 0 ? 1 : -1);
            const isInDelayPhase = this.playbackSpeed >= 0
                ? timeWithoutDelay < 0
                : timeWithoutDelay > totalDuration;
            this.currentTime = Math.max(timeWithoutDelay, 0);
            // If this animation has finished, set the current time  to the total duration.
            if (this.state === "finished" && this.holdTime === null) {
                this.currentTime = totalDuration;
            }
            let elapsed = this.currentTime;
            let frameGenerator = generator;
            if (repeat) {
                /**
                 * Get the current progress (0-1) of the animation. If t is >
                 * than duration we'll get values like 2.5 (midway through the
                 * third iteration)
                 */
                const progress = Math.min(this.currentTime, totalDuration) / resolvedDuration;
                /**
                 * Get the current iteration (0 indexed). For instance the floor of
                 * 2.5 is 2.
                 */
                let currentIteration = Math.floor(progress);
                /**
                 * Get the current progress of the iteration by taking the remainder
                 * so 2.5 is 0.5 through iteration 2
                 */
                let iterationProgress = progress % 1.0;
                /**
                 * If iteration progress is 1 we count that as the end
                 * of the previous iteration.
                 */
                if (!iterationProgress && progress >= 1) {
                    iterationProgress = 1;
                }
                iterationProgress === 1 && currentIteration--;
                currentIteration = Math.min(currentIteration, repeat + 1);
                /**
                 * Reverse progress if we're not running in "normal" direction
                 */
                const isOddIteration = Boolean(currentIteration % 2);
                if (isOddIteration) {
                    if (repeatType === "reverse") {
                        iterationProgress = 1 - iterationProgress;
                        if (repeatDelay) {
                            iterationProgress -= repeatDelay / resolvedDuration;
                        }
                    }
                    else if (repeatType === "mirror") {
                        frameGenerator = mirroredGenerator;
                    }
                }
                elapsed = motionUtils.clamp(0, 1, iterationProgress) * resolvedDuration;
            }
            /**
             * If we're in negative time, set state as the initial keyframe.
             * This prevents delay: x, duration: 0 animations from finishing
             * instantly.
             */
            const state = isInDelayPhase
                ? { done: false, value: keyframes[0] }
                : frameGenerator.next(elapsed);
            if (mixKeyframes) {
                state.value = mixKeyframes(state.value);
            }
            let { done } = state;
            if (!isInDelayPhase && calculatedDuration !== null) {
                done =
                    this.playbackSpeed >= 0
                        ? this.currentTime >= totalDuration
                        : this.currentTime <= 0;
            }
            const isAnimationFinished = this.holdTime === null &&
                (this.state === "finished" || (this.state === "running" && done));
            // TODO: The exception for inertia could be cleaner here
            if (isAnimationFinished && type !== inertia) {
                state.value = getFinalKeyframe$1(keyframes, this.options, finalKeyframe, this.speed);
            }
            if (onUpdate) {
                onUpdate(state.value);
            }
            if (isAnimationFinished) {
                this.finish();
            }
            return state;
        }
        /**
         * Allows the returned animation to be awaited or promise-chained. Currently
         * resolves when the animation finishes at all but in a future update could/should
         * reject if its cancels.
         */
        then(resolve, reject) {
            return this.finished.then(resolve, reject);
        }
        get duration() {
            return motionUtils.millisecondsToSeconds(this.calculatedDuration);
        }
        get iterationDuration() {
            const { delay = 0 } = this.options || {};
            return this.duration + motionUtils.millisecondsToSeconds(delay);
        }
        get time() {
            return motionUtils.millisecondsToSeconds(this.currentTime);
        }
        set time(newTime) {
            newTime = motionUtils.secondsToMilliseconds(newTime);
            this.currentTime = newTime;
            if (this.startTime === null ||
                this.holdTime !== null ||
                this.playbackSpeed === 0) {
                this.holdTime = newTime;
            }
            else if (this.driver) {
                this.startTime = this.driver.now() - newTime / this.playbackSpeed;
            }
            this.driver?.start(false);
        }
        get speed() {
            return this.playbackSpeed;
        }
        set speed(newSpeed) {
            this.updateTime(time.now());
            const hasChanged = this.playbackSpeed !== newSpeed;
            this.playbackSpeed = newSpeed;
            if (hasChanged) {
                this.time = motionUtils.millisecondsToSeconds(this.currentTime);
            }
        }
        play() {
            if (this.isStopped)
                return;
            const { driver = frameloopDriver, startTime } = this.options;
            if (!this.driver) {
                this.driver = driver((timestamp) => this.tick(timestamp));
            }
            this.options.onPlay?.();
            const now = this.driver.now();
            if (this.state === "finished") {
                this.updateFinished();
                this.startTime = now;
            }
            else if (this.holdTime !== null) {
                this.startTime = now - this.holdTime;
            }
            else if (!this.startTime) {
                this.startTime = startTime ?? now;
            }
            if (this.state === "finished" && this.speed < 0) {
                this.startTime += this.calculatedDuration;
            }
            this.holdTime = null;
            /**
             * Set playState to running only after we've used it in
             * the previous logic.
             */
            this.state = "running";
            this.driver.start();
        }
        pause() {
            this.state = "paused";
            this.updateTime(time.now());
            this.holdTime = this.currentTime;
        }
        complete() {
            if (this.state !== "running") {
                this.play();
            }
            this.state = "finished";
            this.holdTime = null;
        }
        finish() {
            this.notifyFinished();
            this.teardown();
            this.state = "finished";
            this.options.onComplete?.();
        }
        cancel() {
            this.holdTime = null;
            this.startTime = 0;
            this.tick(0);
            this.teardown();
            this.options.onCancel?.();
        }
        teardown() {
            this.state = "idle";
            this.stopDriver();
            this.startTime = this.holdTime = null;
            activeAnimations.mainThread--;
        }
        stopDriver() {
            if (!this.driver)
                return;
            this.driver.stop();
            this.driver = undefined;
        }
        sample(sampleTime) {
            this.startTime = 0;
            return this.tick(sampleTime, true);
        }
        attachTimeline(timeline) {
            if (this.options.allowFlatten) {
                this.options.type = "keyframes";
                this.options.ease = "linear";
                this.initAnimation();
            }
            this.driver?.stop();
            return timeline.observe(this);
        }
    }
    // Legacy function support
    function animateValue(options) {
        return new JSAnimation(options);
    }

    function fillWildcards(keyframes) {
        for (let i = 1; i < keyframes.length; i++) {
            keyframes[i] ?? (keyframes[i] = keyframes[i - 1]);
        }
    }

    const radToDeg = (rad) => (rad * 180) / Math.PI;
    const rotate = (v) => {
        const angle = radToDeg(Math.atan2(v[1], v[0]));
        return rebaseAngle(angle);
    };
    const matrix2dParsers = {
        x: 4,
        y: 5,
        translateX: 4,
        translateY: 5,
        scaleX: 0,
        scaleY: 3,
        scale: (v) => (Math.abs(v[0]) + Math.abs(v[3])) / 2,
        rotate,
        rotateZ: rotate,
        skewX: (v) => radToDeg(Math.atan(v[1])),
        skewY: (v) => radToDeg(Math.atan(v[2])),
        skew: (v) => (Math.abs(v[1]) + Math.abs(v[2])) / 2,
    };
    const rebaseAngle = (angle) => {
        angle = angle % 360;
        if (angle < 0)
            angle += 360;
        return angle;
    };
    const rotateZ = rotate;
    const scaleX = (v) => Math.sqrt(v[0] * v[0] + v[1] * v[1]);
    const scaleY = (v) => Math.sqrt(v[4] * v[4] + v[5] * v[5]);
    const matrix3dParsers = {
        x: 12,
        y: 13,
        z: 14,
        translateX: 12,
        translateY: 13,
        translateZ: 14,
        scaleX,
        scaleY,
        scale: (v) => (scaleX(v) + scaleY(v)) / 2,
        rotateX: (v) => rebaseAngle(radToDeg(Math.atan2(v[6], v[5]))),
        rotateY: (v) => rebaseAngle(radToDeg(Math.atan2(-v[2], v[0]))),
        rotateZ,
        rotate: rotateZ,
        skewX: (v) => radToDeg(Math.atan(v[4])),
        skewY: (v) => radToDeg(Math.atan(v[1])),
        skew: (v) => (Math.abs(v[1]) + Math.abs(v[4])) / 2,
    };
    function defaultTransformValue(name) {
        return name.includes("scale") ? 1 : 0;
    }
    function parseValueFromTransform(transform, name) {
        if (!transform || transform === "none") {
            return defaultTransformValue(name);
        }
        const matrix3dMatch = transform.match(/^matrix3d\(([-\d.e\s,]+)\)$/u);
        let parsers;
        let match;
        if (matrix3dMatch) {
            parsers = matrix3dParsers;
            match = matrix3dMatch;
        }
        else {
            const matrix2dMatch = transform.match(/^matrix\(([-\d.e\s,]+)\)$/u);
            parsers = matrix2dParsers;
            match = matrix2dMatch;
        }
        if (!match) {
            return defaultTransformValue(name);
        }
        const valueParser = parsers[name];
        const values = match[1].split(",").map(convertTransformToNumber);
        return typeof valueParser === "function"
            ? valueParser(values)
            : values[valueParser];
    }
    const readTransformValue = (instance, name) => {
        const { transform = "none" } = getComputedStyle(instance);
        return parseValueFromTransform(transform, name);
    };
    function convertTransformToNumber(value) {
        return parseFloat(value.trim());
    }

    /**
     * Generate a list of every possible transform key.
     */
    const transformPropOrder = [
        "transformPerspective",
        "x",
        "y",
        "z",
        "translateX",
        "translateY",
        "translateZ",
        "scale",
        "scaleX",
        "scaleY",
        "rotate",
        "rotateX",
        "rotateY",
        "rotateZ",
        "skew",
        "skewX",
        "skewY",
    ];
    /**
     * A quick lookup for transform props.
     */
    const transformProps = /*@__PURE__*/ (() => new Set(transformPropOrder))();

    const isNumOrPxType = (v) => v === number || v === px;
    const transformKeys = new Set(["x", "y", "z"]);
    const nonTranslationalTransformKeys = transformPropOrder.filter((key) => !transformKeys.has(key));
    function removeNonTranslationalTransform(visualElement) {
        const removedTransforms = [];
        nonTranslationalTransformKeys.forEach((key) => {
            const value = visualElement.getValue(key);
            if (value !== undefined) {
                removedTransforms.push([key, value.get()]);
                value.set(key.startsWith("scale") ? 1 : 0);
            }
        });
        return removedTransforms;
    }
    const positionalValues = {
        // Dimensions
        width: ({ x }, { paddingLeft = "0", paddingRight = "0" }) => x.max - x.min - parseFloat(paddingLeft) - parseFloat(paddingRight),
        height: ({ y }, { paddingTop = "0", paddingBottom = "0" }) => y.max - y.min - parseFloat(paddingTop) - parseFloat(paddingBottom),
        top: (_bbox, { top }) => parseFloat(top),
        left: (_bbox, { left }) => parseFloat(left),
        bottom: ({ y }, { top }) => parseFloat(top) + (y.max - y.min),
        right: ({ x }, { left }) => parseFloat(left) + (x.max - x.min),
        // Transform
        x: (_bbox, { transform }) => parseValueFromTransform(transform, "x"),
        y: (_bbox, { transform }) => parseValueFromTransform(transform, "y"),
    };
    // Alias translate longform names
    positionalValues.translateX = positionalValues.x;
    positionalValues.translateY = positionalValues.y;

    const toResolve = new Set();
    let isScheduled = false;
    let anyNeedsMeasurement = false;
    let isForced = false;
    function measureAllKeyframes() {
        if (anyNeedsMeasurement) {
            const resolversToMeasure = Array.from(toResolve).filter((resolver) => resolver.needsMeasurement);
            const elementsToMeasure = new Set(resolversToMeasure.map((resolver) => resolver.element));
            const transformsToRestore = new Map();
            /**
             * Write pass
             * If we're measuring elements we want to remove bounding box-changing transforms.
             */
            elementsToMeasure.forEach((element) => {
                const removedTransforms = removeNonTranslationalTransform(element);
                if (!removedTransforms.length)
                    return;
                transformsToRestore.set(element, removedTransforms);
                element.render();
            });
            // Read
            resolversToMeasure.forEach((resolver) => resolver.measureInitialState());
            // Write
            elementsToMeasure.forEach((element) => {
                element.render();
                const restore = transformsToRestore.get(element);
                if (restore) {
                    restore.forEach(([key, value]) => {
                        element.getValue(key)?.set(value);
                    });
                }
            });
            // Read
            resolversToMeasure.forEach((resolver) => resolver.measureEndState());
            // Write
            resolversToMeasure.forEach((resolver) => {
                if (resolver.suspendedScrollY !== undefined) {
                    window.scrollTo(0, resolver.suspendedScrollY);
                }
            });
        }
        anyNeedsMeasurement = false;
        isScheduled = false;
        toResolve.forEach((resolver) => resolver.complete(isForced));
        toResolve.clear();
    }
    function readAllKeyframes() {
        toResolve.forEach((resolver) => {
            resolver.readKeyframes();
            if (resolver.needsMeasurement) {
                anyNeedsMeasurement = true;
            }
        });
    }
    function flushKeyframeResolvers() {
        isForced = true;
        readAllKeyframes();
        measureAllKeyframes();
        isForced = false;
    }
    class KeyframeResolver {
        constructor(unresolvedKeyframes, onComplete, name, motionValue, element, isAsync = false) {
            this.state = "pending";
            /**
             * Track whether this resolver is async. If it is, it'll be added to the
             * resolver queue and flushed in the next frame. Resolvers that aren't going
             * to trigger read/write thrashing don't need to be async.
             */
            this.isAsync = false;
            /**
             * Track whether this resolver needs to perform a measurement
             * to resolve its keyframes.
             */
            this.needsMeasurement = false;
            this.unresolvedKeyframes = [...unresolvedKeyframes];
            this.onComplete = onComplete;
            this.name = name;
            this.motionValue = motionValue;
            this.element = element;
            this.isAsync = isAsync;
        }
        scheduleResolve() {
            this.state = "scheduled";
            if (this.isAsync) {
                toResolve.add(this);
                if (!isScheduled) {
                    isScheduled = true;
                    frame.read(readAllKeyframes);
                    frame.resolveKeyframes(measureAllKeyframes);
                }
            }
            else {
                this.readKeyframes();
                this.complete();
            }
        }
        readKeyframes() {
            const { unresolvedKeyframes, name, element, motionValue } = this;
            // If initial keyframe is null we need to read it from the DOM
            if (unresolvedKeyframes[0] === null) {
                const currentValue = motionValue?.get();
                // TODO: This doesn't work if the final keyframe is a wildcard
                const finalKeyframe = unresolvedKeyframes[unresolvedKeyframes.length - 1];
                if (currentValue !== undefined) {
                    unresolvedKeyframes[0] = currentValue;
                }
                else if (element && name) {
                    const valueAsRead = element.readValue(name, finalKeyframe);
                    if (valueAsRead !== undefined && valueAsRead !== null) {
                        unresolvedKeyframes[0] = valueAsRead;
                    }
                }
                if (unresolvedKeyframes[0] === undefined) {
                    unresolvedKeyframes[0] = finalKeyframe;
                }
                if (motionValue && currentValue === undefined) {
                    motionValue.set(unresolvedKeyframes[0]);
                }
            }
            fillWildcards(unresolvedKeyframes);
        }
        setFinalKeyframe() { }
        measureInitialState() { }
        renderEndStyles() { }
        measureEndState() { }
        complete(isForcedComplete = false) {
            this.state = "complete";
            this.onComplete(this.unresolvedKeyframes, this.finalKeyframe, isForcedComplete);
            toResolve.delete(this);
        }
        cancel() {
            if (this.state === "scheduled") {
                toResolve.delete(this);
                this.state = "pending";
            }
        }
        resume() {
            if (this.state === "pending")
                this.scheduleResolve();
        }
    }

    const isCSSVar = (name) => name.startsWith("--");

    function setStyle(element, name, value) {
        isCSSVar(name)
            ? element.style.setProperty(name, value)
            : (element.style[name] = value);
    }

    const supportsScrollTimeline = /* @__PURE__ */ motionUtils.memo(() => window.ScrollTimeline !== undefined);

    /**
     * Add the ability for test suites to manually set support flags
     * to better test more environments.
     */
    const supportsFlags = {};

    function memoSupports(callback, supportsFlag) {
        const memoized = motionUtils.memo(callback);
        return () => supportsFlags[supportsFlag] ?? memoized();
    }

    const supportsLinearEasing = /*@__PURE__*/ memoSupports(() => {
        try {
            document
                .createElement("div")
                .animate({ opacity: 0 }, { easing: "linear(0, 1)" });
        }
        catch (e) {
            return false;
        }
        return true;
    }, "linearEasing");

    const cubicBezierAsString = ([a, b, c, d]) => `cubic-bezier(${a}, ${b}, ${c}, ${d})`;

    const supportedWaapiEasing = {
        linear: "linear",
        ease: "ease",
        easeIn: "ease-in",
        easeOut: "ease-out",
        easeInOut: "ease-in-out",
        circIn: /*@__PURE__*/ cubicBezierAsString([0, 0.65, 0.55, 1]),
        circOut: /*@__PURE__*/ cubicBezierAsString([0.55, 0, 1, 0.45]),
        backIn: /*@__PURE__*/ cubicBezierAsString([0.31, 0.01, 0.66, -0.59]),
        backOut: /*@__PURE__*/ cubicBezierAsString([0.33, 1.53, 0.69, 0.99]),
    };

    function mapEasingToNativeEasing(easing, duration) {
        if (!easing) {
            return undefined;
        }
        else if (typeof easing === "function") {
            return supportsLinearEasing()
                ? generateLinearEasing(easing, duration)
                : "ease-out";
        }
        else if (motionUtils.isBezierDefinition(easing)) {
            return cubicBezierAsString(easing);
        }
        else if (Array.isArray(easing)) {
            return easing.map((segmentEasing) => mapEasingToNativeEasing(segmentEasing, duration) ||
                supportedWaapiEasing.easeOut);
        }
        else {
            return supportedWaapiEasing[easing];
        }
    }

    function startWaapiAnimation(element, valueName, keyframes, { delay = 0, duration = 300, repeat = 0, repeatType = "loop", ease = "easeOut", times, } = {}, pseudoElement = undefined) {
        const keyframeOptions = {
            [valueName]: keyframes,
        };
        if (times)
            keyframeOptions.offset = times;
        const easing = mapEasingToNativeEasing(ease, duration);
        /**
         * If this is an easing array, apply to keyframes, not animation as a whole
         */
        if (Array.isArray(easing))
            keyframeOptions.easing = easing;
        if (statsBuffer.value) {
            activeAnimations.waapi++;
        }
        const options = {
            delay,
            duration,
            easing: !Array.isArray(easing) ? easing : "linear",
            fill: "both",
            iterations: repeat + 1,
            direction: repeatType === "reverse" ? "alternate" : "normal",
        };
        if (pseudoElement)
            options.pseudoElement = pseudoElement;
        const animation = element.animate(keyframeOptions, options);
        if (statsBuffer.value) {
            animation.finished.finally(() => {
                activeAnimations.waapi--;
            });
        }
        return animation;
    }

    function isGenerator(type) {
        return typeof type === "function" && "applyToOptions" in type;
    }

    function applyGeneratorOptions({ type, ...options }) {
        if (isGenerator(type) && supportsLinearEasing()) {
            return type.applyToOptions(options);
        }
        else {
            options.duration ?? (options.duration = 300);
            options.ease ?? (options.ease = "easeOut");
        }
        return options;
    }

    /**
     * NativeAnimation implements AnimationPlaybackControls for the browser's Web Animations API.
     */
    class NativeAnimation extends WithPromise {
        constructor(options) {
            super();
            this.finishedTime = null;
            this.isStopped = false;
            /**
             * Tracks a manually-set start time that takes precedence over WAAPI's
             * dynamic startTime. This is cleared when play() or time setter is called,
             * allowing WAAPI to take over timing.
             */
            this.manualStartTime = null;
            if (!options)
                return;
            const { element, name, keyframes, pseudoElement, allowFlatten = false, finalKeyframe, onComplete, } = options;
            this.isPseudoElement = Boolean(pseudoElement);
            this.allowFlatten = allowFlatten;
            this.options = options;
            motionUtils.invariant(typeof options.type !== "string", `Mini animate() doesn't support "type" as a string.`, "mini-spring");
            const transition = applyGeneratorOptions(options);
            this.animation = startWaapiAnimation(element, name, keyframes, transition, pseudoElement);
            if (transition.autoplay === false) {
                this.animation.pause();
            }
            this.animation.onfinish = () => {
                this.finishedTime = this.time;
                if (!pseudoElement) {
                    const keyframe = getFinalKeyframe$1(keyframes, this.options, finalKeyframe, this.speed);
                    if (this.updateMotionValue) {
                        this.updateMotionValue(keyframe);
                    }
                    else {
                        /**
                         * If we can, we want to commit the final style as set by the user,
                         * rather than the computed keyframe value supplied by the animation.
                         */
                        setStyle(element, name, keyframe);
                    }
                    this.animation.cancel();
                }
                onComplete?.();
                this.notifyFinished();
            };
        }
        play() {
            if (this.isStopped)
                return;
            this.manualStartTime = null;
            this.animation.play();
            if (this.state === "finished") {
                this.updateFinished();
            }
        }
        pause() {
            this.animation.pause();
        }
        complete() {
            this.animation.finish?.();
        }
        cancel() {
            try {
                this.animation.cancel();
            }
            catch (e) { }
        }
        stop() {
            if (this.isStopped)
                return;
            this.isStopped = true;
            const { state } = this;
            if (state === "idle" || state === "finished") {
                return;
            }
            if (this.updateMotionValue) {
                this.updateMotionValue();
            }
            else {
                this.commitStyles();
            }
            if (!this.isPseudoElement)
                this.cancel();
        }
        /**
         * WAAPI doesn't natively have any interruption capabilities.
         *
         * In this method, we commit styles back to the DOM before cancelling
         * the animation.
         *
         * This is designed to be overridden by NativeAnimationExtended, which
         * will create a renderless JS animation and sample it twice to calculate
         * its current value, "previous" value, and therefore allow
         * Motion to also correctly calculate velocity for any subsequent animation
         * while deferring the commit until the next animation frame.
         */
        commitStyles() {
            if (!this.isPseudoElement) {
                this.animation.commitStyles?.();
            }
        }
        get duration() {
            const duration = this.animation.effect?.getComputedTiming?.().duration || 0;
            return motionUtils.millisecondsToSeconds(Number(duration));
        }
        get iterationDuration() {
            const { delay = 0 } = this.options || {};
            return this.duration + motionUtils.millisecondsToSeconds(delay);
        }
        get time() {
            return motionUtils.millisecondsToSeconds(Number(this.animation.currentTime) || 0);
        }
        set time(newTime) {
            this.manualStartTime = null;
            this.finishedTime = null;
            this.animation.currentTime = motionUtils.secondsToMilliseconds(newTime);
        }
        /**
         * The playback speed of the animation.
         * 1 = normal speed, 2 = double speed, 0.5 = half speed.
         */
        get speed() {
            return this.animation.playbackRate;
        }
        set speed(newSpeed) {
            // Allow backwards playback after finishing
            if (newSpeed < 0)
                this.finishedTime = null;
            this.animation.playbackRate = newSpeed;
        }
        get state() {
            return this.finishedTime !== null
                ? "finished"
                : this.animation.playState;
        }
        get startTime() {
            return this.manualStartTime ?? Number(this.animation.startTime);
        }
        set startTime(newStartTime) {
            this.manualStartTime = this.animation.startTime = newStartTime;
        }
        /**
         * Attaches a timeline to the animation, for instance the `ScrollTimeline`.
         */
        attachTimeline({ timeline, observe }) {
            if (this.allowFlatten) {
                this.animation.effect?.updateTiming({ easing: "linear" });
            }
            this.animation.onfinish = null;
            if (timeline && supportsScrollTimeline()) {
                this.animation.timeline = timeline;
                return motionUtils.noop;
            }
            else {
                return observe(this);
            }
        }
    }

    const unsupportedEasingFunctions = {
        anticipate: motionUtils.anticipate,
        backInOut: motionUtils.backInOut,
        circInOut: motionUtils.circInOut,
    };
    function isUnsupportedEase(key) {
        return key in unsupportedEasingFunctions;
    }
    function replaceStringEasing(transition) {
        if (typeof transition.ease === "string" &&
            isUnsupportedEase(transition.ease)) {
            transition.ease = unsupportedEasingFunctions[transition.ease];
        }
    }

    /**
     * 10ms is chosen here as it strikes a balance between smooth
     * results (more than one keyframe per frame at 60fps) and
     * keyframe quantity.
     */
    const sampleDelta = 10; //ms
    class NativeAnimationExtended extends NativeAnimation {
        constructor(options) {
            /**
             * The base NativeAnimation function only supports a subset
             * of Motion easings, and WAAPI also only supports some
             * easing functions via string/cubic-bezier definitions.
             *
             * This function replaces those unsupported easing functions
             * with a JS easing function. This will later get compiled
             * to a linear() easing function.
             */
            replaceStringEasing(options);
            /**
             * Ensure we replace the transition type with a generator function
             * before passing to WAAPI.
             *
             * TODO: Does this have a better home? It could be shared with
             * JSAnimation.
             */
            replaceTransitionType(options);
            super(options);
            if (options.startTime !== undefined) {
                this.startTime = options.startTime;
            }
            this.options = options;
        }
        /**
         * WAAPI doesn't natively have any interruption capabilities.
         *
         * Rather than read committed styles back out of the DOM, we can
         * create a renderless JS animation and sample it twice to calculate
         * its current value, "previous" value, and therefore allow
         * Motion to calculate velocity for any subsequent animation.
         */
        updateMotionValue(value) {
            const { motionValue, onUpdate, onComplete, element, ...options } = this.options;
            if (!motionValue)
                return;
            if (value !== undefined) {
                motionValue.set(value);
                return;
            }
            const sampleAnimation = new JSAnimation({
                ...options,
                autoplay: false,
            });
            /**
             * Use wall-clock elapsed time for sampling.
             * Under CPU load, WAAPI's currentTime may not reflect actual
             * elapsed time, causing incorrect sampling and visual jumps.
             */
            const sampleTime = Math.max(sampleDelta, time.now() - this.startTime);
            const delta = motionUtils.clamp(0, sampleDelta, sampleTime - sampleDelta);
            motionValue.setWithVelocity(sampleAnimation.sample(Math.max(0, sampleTime - delta)).value, sampleAnimation.sample(sampleTime).value, delta);
            sampleAnimation.stop();
        }
    }

    /**
     * Check if a value is animatable. Examples:
     *
     * ✅: 100, "100px", "#fff"
     * ❌: "block", "url(2.jpg)"
     * @param value
     *
     * @internal
     */
    const isAnimatable = (value, name) => {
        // If the list of keys that might be non-animatable grows, replace with Set
        if (name === "zIndex")
            return false;
        // If it's a number or a keyframes array, we can animate it. We might at some point
        // need to do a deep isAnimatable check of keyframes, or let Popmotion handle this,
        // but for now lets leave it like this for performance reasons
        if (typeof value === "number" || Array.isArray(value))
            return true;
        if (typeof value === "string" && // It's animatable if we have a string
            (complex.test(value) || value === "0") && // And it contains numbers and/or colors
            !value.startsWith("url(") // Unless it starts with "url("
        ) {
            return true;
        }
        return false;
    };

    function hasKeyframesChanged(keyframes) {
        const current = keyframes[0];
        if (keyframes.length === 1)
            return true;
        for (let i = 0; i < keyframes.length; i++) {
            if (keyframes[i] !== current)
                return true;
        }
    }
    function canAnimate(keyframes, name, type, velocity) {
        /**
         * Check if we're able to animate between the start and end keyframes,
         * and throw a warning if we're attempting to animate between one that's
         * animatable and another that isn't.
         */
        const originKeyframe = keyframes[0];
        if (originKeyframe === null) {
            return false;
        }
        /**
         * These aren't traditionally animatable but we do support them.
         * In future we could look into making this more generic or replacing
         * this function with mix() === mixImmediate
         */
        if (name === "display" || name === "visibility")
            return true;
        const targetKeyframe = keyframes[keyframes.length - 1];
        const isOriginAnimatable = isAnimatable(originKeyframe, name);
        const isTargetAnimatable = isAnimatable(targetKeyframe, name);
        motionUtils.warning(isOriginAnimatable === isTargetAnimatable, `You are trying to animate ${name} from "${originKeyframe}" to "${targetKeyframe}". "${isOriginAnimatable ? targetKeyframe : originKeyframe}" is not an animatable value.`, "value-not-animatable");
        // Always skip if any of these are true
        if (!isOriginAnimatable || !isTargetAnimatable) {
            return false;
        }
        return (hasKeyframesChanged(keyframes) ||
            ((type === "spring" || isGenerator(type)) && velocity));
    }

    function makeAnimationInstant(options) {
        options.duration = 0;
        options.type = "keyframes";
    }

    /**
     * A list of values that can be hardware-accelerated.
     */
    const acceleratedValues$1 = new Set([
        "opacity",
        "clipPath",
        "filter",
        "transform",
        // TODO: Could be re-enabled now we have support for linear() easing
        // "background-color"
    ]);
    const supportsWaapi = /*@__PURE__*/ motionUtils.memo(() => Object.hasOwnProperty.call(Element.prototype, "animate"));
    function supportsBrowserAnimation(options) {
        const { motionValue, name, repeatDelay, repeatType, damping, type } = options;
        const subject = motionValue?.owner?.current;
        /**
         * We use this check instead of isHTMLElement() because we explicitly
         * **don't** want elements in different timing contexts (i.e. popups)
         * to be accelerated, as it's not possible to sync these animations
         * properly with those driven from the main window frameloop.
         */
        if (!(subject instanceof HTMLElement)) {
            return false;
        }
        const { onUpdate, transformTemplate } = motionValue.owner.getProps();
        return (supportsWaapi() &&
            name &&
            acceleratedValues$1.has(name) &&
            (name !== "transform" || !transformTemplate) &&
            /**
             * If we're outputting values to onUpdate then we can't use WAAPI as there's
             * no way to read the value from WAAPI every frame.
             */
            !onUpdate &&
            !repeatDelay &&
            repeatType !== "mirror" &&
            damping !== 0 &&
            type !== "inertia");
    }

    /**
     * Maximum time allowed between an animation being created and it being
     * resolved for us to use the latter as the start time.
     *
     * This is to ensure that while we prefer to "start" an animation as soon
     * as it's triggered, we also want to avoid a visual jump if there's a big delay
     * between these two moments.
     */
    const MAX_RESOLVE_DELAY = 40;
    class AsyncMotionValueAnimation extends WithPromise {
        constructor({ autoplay = true, delay = 0, type = "keyframes", repeat = 0, repeatDelay = 0, repeatType = "loop", keyframes, name, motionValue, element, ...options }) {
            super();
            /**
             * Bound to support return animation.stop pattern
             */
            this.stop = () => {
                if (this._animation) {
                    this._animation.stop();
                    this.stopTimeline?.();
                }
                this.keyframeResolver?.cancel();
            };
            this.createdAt = time.now();
            const optionsWithDefaults = {
                autoplay,
                delay,
                type,
                repeat,
                repeatDelay,
                repeatType,
                name,
                motionValue,
                element,
                ...options,
            };
            const KeyframeResolver$1 = element?.KeyframeResolver || KeyframeResolver;
            this.keyframeResolver = new KeyframeResolver$1(keyframes, (resolvedKeyframes, finalKeyframe, forced) => this.onKeyframesResolved(resolvedKeyframes, finalKeyframe, optionsWithDefaults, !forced), name, motionValue, element);
            this.keyframeResolver?.scheduleResolve();
        }
        onKeyframesResolved(keyframes, finalKeyframe, options, sync) {
            this.keyframeResolver = undefined;
            const { name, type, velocity, delay, isHandoff, onUpdate } = options;
            this.resolvedAt = time.now();
            /**
             * If we can't animate this value with the resolved keyframes
             * then we should complete it immediately.
             */
            if (!canAnimate(keyframes, name, type, velocity)) {
                if (motionUtils.MotionGlobalConfig.instantAnimations || !delay) {
                    onUpdate?.(getFinalKeyframe$1(keyframes, options, finalKeyframe));
                }
                keyframes[0] = keyframes[keyframes.length - 1];
                makeAnimationInstant(options);
                options.repeat = 0;
            }
            /**
             * Resolve startTime for the animation.
             *
             * This method uses the createdAt and resolvedAt to calculate the
             * animation startTime. *Ideally*, we would use the createdAt time as t=0
             * as the following frame would then be the first frame of the animation in
             * progress, which would feel snappier.
             *
             * However, if there's a delay (main thread work) between the creation of
             * the animation and the first committed frame, we prefer to use resolvedAt
             * to avoid a sudden jump into the animation.
             */
            const startTime = sync
                ? !this.resolvedAt
                    ? this.createdAt
                    : this.resolvedAt - this.createdAt > MAX_RESOLVE_DELAY
                        ? this.resolvedAt
                        : this.createdAt
                : undefined;
            const resolvedOptions = {
                startTime,
                finalKeyframe,
                ...options,
                keyframes,
            };
            /**
             * Animate via WAAPI if possible. If this is a handoff animation, the optimised animation will be running via
             * WAAPI. Therefore, this animation must be JS to ensure it runs "under" the
             * optimised animation.
             */
            const useWaapi = !isHandoff && supportsBrowserAnimation(resolvedOptions);
            const element = resolvedOptions.motionValue?.owner?.current;
            const animation = useWaapi
                ? new NativeAnimationExtended({
                    ...resolvedOptions,
                    element,
                })
                : new JSAnimation(resolvedOptions);
            animation.finished.then(() => {
                this.notifyFinished();
            }).catch(motionUtils.noop);
            if (this.pendingTimeline) {
                this.stopTimeline = animation.attachTimeline(this.pendingTimeline);
                this.pendingTimeline = undefined;
            }
            this._animation = animation;
        }
        get finished() {
            if (!this._animation) {
                return this._finished;
            }
            else {
                return this.animation.finished;
            }
        }
        then(onResolve, _onReject) {
            return this.finished.finally(onResolve).then(() => { });
        }
        get animation() {
            if (!this._animation) {
                this.keyframeResolver?.resume();
                flushKeyframeResolvers();
            }
            return this._animation;
        }
        get duration() {
            return this.animation.duration;
        }
        get iterationDuration() {
            return this.animation.iterationDuration;
        }
        get time() {
            return this.animation.time;
        }
        set time(newTime) {
            this.animation.time = newTime;
        }
        get speed() {
            return this.animation.speed;
        }
        get state() {
            return this.animation.state;
        }
        set speed(newSpeed) {
            this.animation.speed = newSpeed;
        }
        get startTime() {
            return this.animation.startTime;
        }
        attachTimeline(timeline) {
            if (this._animation) {
                this.stopTimeline = this.animation.attachTimeline(timeline);
            }
            else {
                this.pendingTimeline = timeline;
            }
            return () => this.stop();
        }
        play() {
            this.animation.play();
        }
        pause() {
            this.animation.pause();
        }
        complete() {
            this.animation.complete();
        }
        cancel() {
            if (this._animation) {
                this.animation.cancel();
            }
            this.keyframeResolver?.cancel();
        }
    }

    class GroupAnimation {
        constructor(animations) {
            // Bound to accomadate common `return animation.stop` pattern
            this.stop = () => this.runAll("stop");
            this.animations = animations.filter(Boolean);
        }
        get finished() {
            return Promise.all(this.animations.map((animation) => animation.finished));
        }
        /**
         * TODO: Filter out cancelled or stopped animations before returning
         */
        getAll(propName) {
            return this.animations[0][propName];
        }
        setAll(propName, newValue) {
            for (let i = 0; i < this.animations.length; i++) {
                this.animations[i][propName] = newValue;
            }
        }
        attachTimeline(timeline) {
            const subscriptions = this.animations.map((animation) => animation.attachTimeline(timeline));
            return () => {
                subscriptions.forEach((cancel, i) => {
                    cancel && cancel();
                    this.animations[i].stop();
                });
            };
        }
        get time() {
            return this.getAll("time");
        }
        set time(time) {
            this.setAll("time", time);
        }
        get speed() {
            return this.getAll("speed");
        }
        set speed(speed) {
            this.setAll("speed", speed);
        }
        get state() {
            return this.getAll("state");
        }
        get startTime() {
            return this.getAll("startTime");
        }
        get duration() {
            return getMax(this.animations, "duration");
        }
        get iterationDuration() {
            return getMax(this.animations, "iterationDuration");
        }
        runAll(methodName) {
            this.animations.forEach((controls) => controls[methodName]());
        }
        play() {
            this.runAll("play");
        }
        pause() {
            this.runAll("pause");
        }
        cancel() {
            this.runAll("cancel");
        }
        complete() {
            this.runAll("complete");
        }
    }
    function getMax(animations, propName) {
        let max = 0;
        for (let i = 0; i < animations.length; i++) {
            const value = animations[i][propName];
            if (value !== null && value > max) {
                max = value;
            }
        }
        return max;
    }

    class GroupAnimationWithThen extends GroupAnimation {
        then(onResolve, _onReject) {
            return this.finished.finally(onResolve).then(() => { });
        }
    }

    class NativeAnimationWrapper extends NativeAnimation {
        constructor(animation) {
            super();
            this.animation = animation;
            animation.onfinish = () => {
                this.finishedTime = this.time;
                this.notifyFinished();
            };
        }
    }

    const animationMaps = new WeakMap();
    const animationMapKey = (name, pseudoElement = "") => `${name}:${pseudoElement}`;
    function getAnimationMap(element) {
        const map = animationMaps.get(element) || new Map();
        animationMaps.set(element, map);
        return map;
    }

    function calcChildStagger(children, child, delayChildren, staggerChildren = 0, staggerDirection = 1) {
        const index = Array.from(children)
            .sort((a, b) => a.sortNodePosition(b))
            .indexOf(child);
        const numChildren = children.size;
        const maxStaggerDuration = (numChildren - 1) * staggerChildren;
        const delayIsFunction = typeof delayChildren === "function";
        return delayIsFunction
            ? delayChildren(index, numChildren)
            : staggerDirection === 1
                ? index * staggerChildren
                : maxStaggerDuration - index * staggerChildren;
    }

    /**
     * Parse Framer's special CSS variable format into a CSS token and a fallback.
     *
     * ```
     * `var(--foo, #fff)` => [`--foo`, '#fff']
     * ```
     *
     * @param current
     */
    const splitCSSVariableRegex = 
    // eslint-disable-next-line redos-detector/no-unsafe-regex -- false positive, as it can match a lot of words
    /^var\(--(?:([\w-]+)|([\w-]+), ?([a-zA-Z\d ()%#.,-]+))\)/u;
    function parseCSSVariable(current) {
        const match = splitCSSVariableRegex.exec(current);
        if (!match)
            return [,];
        const [, token1, token2, fallback] = match;
        return [`--${token1 ?? token2}`, fallback];
    }
    const maxDepth = 4;
    function getVariableValue(current, element, depth = 1) {
        motionUtils.invariant(depth <= maxDepth, `Max CSS variable fallback depth detected in property "${current}". This may indicate a circular fallback dependency.`, "max-css-var-depth");
        const [token, fallback] = parseCSSVariable(current);
        // No CSS variable detected
        if (!token)
            return;
        // Attempt to read this CSS variable off the element
        const resolved = window.getComputedStyle(element).getPropertyValue(token);
        if (resolved) {
            const trimmed = resolved.trim();
            return motionUtils.isNumericalString(trimmed) ? parseFloat(trimmed) : trimmed;
        }
        return isCSSVariableToken(fallback)
            ? getVariableValue(fallback, element, depth + 1)
            : fallback;
    }

    const underDampedSpring = {
        type: "spring",
        stiffness: 500,
        damping: 25,
        restSpeed: 10,
    };
    const criticallyDampedSpring = (target) => ({
        type: "spring",
        stiffness: 550,
        damping: target === 0 ? 2 * Math.sqrt(550) : 30,
        restSpeed: 10,
    });
    const keyframesTransition = {
        type: "keyframes",
        duration: 0.8,
    };
    /**
     * Default easing curve is a slightly shallower version of
     * the default browser easing curve.
     */
    const ease = {
        type: "keyframes",
        ease: [0.25, 0.1, 0.35, 1],
        duration: 0.3,
    };
    const getDefaultTransition = (valueKey, { keyframes }) => {
        if (keyframes.length > 2) {
            return keyframesTransition;
        }
        else if (transformProps.has(valueKey)) {
            return valueKey.startsWith("scale")
                ? criticallyDampedSpring(keyframes[1])
                : underDampedSpring;
        }
        return ease;
    };

    const isNotNull = (value) => value !== null;
    function getFinalKeyframe(keyframes, { repeat, repeatType = "loop" }, finalKeyframe) {
        const resolvedKeyframes = keyframes.filter(isNotNull);
        const index = repeat && repeatType !== "loop" && repeat % 2 === 1
            ? 0
            : resolvedKeyframes.length - 1;
        return !index || finalKeyframe === undefined
            ? resolvedKeyframes[index]
            : finalKeyframe;
    }

    function getValueTransition(transition, key) {
        return (transition?.[key] ??
            transition?.["default"] ??
            transition);
    }

    /**
     * Decide whether a transition is defined on a given Transition.
     * This filters out orchestration options and returns true
     * if any options are left.
     */
    function isTransitionDefined({ when, delay: _delay, delayChildren, staggerChildren, staggerDirection, repeat, repeatType, repeatDelay, from, elapsed, ...transition }) {
        return !!Object.keys(transition).length;
    }

    const animateMotionValue = (name, value, target, transition = {}, element, isHandoff) => (onComplete) => {
        const valueTransition = getValueTransition(transition, name) || {};
        /**
         * Most transition values are currently completely overwritten by value-specific
         * transitions. In the future it'd be nicer to blend these transitions. But for now
         * delay actually does inherit from the root transition if not value-specific.
         */
        const delay = valueTransition.delay || transition.delay || 0;
        /**
         * Elapsed isn't a public transition option but can be passed through from
         * optimized appear effects in milliseconds.
         */
        let { elapsed = 0 } = transition;
        elapsed = elapsed - motionUtils.secondsToMilliseconds(delay);
        const options = {
            keyframes: Array.isArray(target) ? target : [null, target],
            ease: "easeOut",
            velocity: value.getVelocity(),
            ...valueTransition,
            delay: -elapsed,
            onUpdate: (v) => {
                value.set(v);
                valueTransition.onUpdate && valueTransition.onUpdate(v);
            },
            onComplete: () => {
                onComplete();
                valueTransition.onComplete && valueTransition.onComplete();
            },
            name,
            motionValue: value,
            element: isHandoff ? undefined : element,
        };
        /**
         * If there's no transition defined for this value, we can generate
         * unique transition settings for this value.
         */
        if (!isTransitionDefined(valueTransition)) {
            Object.assign(options, getDefaultTransition(name, options));
        }
        /**
         * Both WAAPI and our internal animation functions use durations
         * as defined by milliseconds, while our external API defines them
         * as seconds.
         */
        options.duration && (options.duration = motionUtils.secondsToMilliseconds(options.duration));
        options.repeatDelay && (options.repeatDelay = motionUtils.secondsToMilliseconds(options.repeatDelay));
        /**
         * Support deprecated way to set initial value. Prefer keyframe syntax.
         */
        if (options.from !== undefined) {
            options.keyframes[0] = options.from;
        }
        let shouldSkip = false;
        if (options.type === false ||
            (options.duration === 0 && !options.repeatDelay)) {
            makeAnimationInstant(options);
            if (options.delay === 0) {
                shouldSkip = true;
            }
        }
        if (motionUtils.MotionGlobalConfig.instantAnimations ||
            motionUtils.MotionGlobalConfig.skipAnimations) {
            shouldSkip = true;
            makeAnimationInstant(options);
            options.delay = 0;
        }
        /**
         * If the transition type or easing has been explicitly set by the user
         * then we don't want to allow flattening the animation.
         */
        options.allowFlatten = !valueTransition.type && !valueTransition.ease;
        /**
         * If we can or must skip creating the animation, and apply only
         * the final keyframe, do so. We also check once keyframes are resolved but
         * this early check prevents the need to create an animation at all.
         */
        if (shouldSkip && !isHandoff && value.get() !== undefined) {
            const finalKeyframe = getFinalKeyframe(options.keyframes, valueTransition);
            if (finalKeyframe !== undefined) {
                frame.update(() => {
                    options.onUpdate(finalKeyframe);
                    options.onComplete();
                });
                return;
            }
        }
        return valueTransition.isSync
            ? new JSAnimation(options)
            : new AsyncMotionValueAnimation(options);
    };

    function getValueState(visualElement) {
        const state = [{}, {}];
        visualElement?.values.forEach((value, key) => {
            state[0][key] = value.get();
            state[1][key] = value.getVelocity();
        });
        return state;
    }
    function resolveVariantFromProps(props, definition, custom, visualElement) {
        /**
         * If the variant definition is a function, resolve.
         */
        if (typeof definition === "function") {
            const [current, velocity] = getValueState(visualElement);
            definition = definition(custom !== undefined ? custom : props.custom, current, velocity);
        }
        /**
         * If the variant definition is a variant label, or
         * the function returned a variant label, resolve.
         */
        if (typeof definition === "string") {
            definition = props.variants && props.variants[definition];
        }
        /**
         * At this point we've resolved both functions and variant labels,
         * but the resolved variant label might itself have been a function.
         * If so, resolve. This can only have returned a valid target object.
         */
        if (typeof definition === "function") {
            const [current, velocity] = getValueState(visualElement);
            definition = definition(custom !== undefined ? custom : props.custom, current, velocity);
        }
        return definition;
    }

    function resolveVariant(visualElement, definition, custom) {
        const props = visualElement.getProps();
        return resolveVariantFromProps(props, definition, custom !== undefined ? custom : props.custom, visualElement);
    }

    const positionalKeys = new Set([
        "width",
        "height",
        "top",
        "left",
        "right",
        "bottom",
        ...transformPropOrder,
    ]);

    /**
     * Maximum time between the value of two frames, beyond which we
     * assume the velocity has since been 0.
     */
    const MAX_VELOCITY_DELTA = 30;
    const isFloat = (value) => {
        return !isNaN(parseFloat(value));
    };
    const collectMotionValues = {
        current: undefined,
    };
    /**
     * `MotionValue` is used to track the state and velocity of motion values.
     *
     * @public
     */
    class MotionValue {
        /**
         * @param init - The initiating value
         * @param config - Optional configuration options
         *
         * -  `transformer`: A function to transform incoming values with.
         */
        constructor(init, options = {}) {
            /**
             * Tracks whether this value can output a velocity. Currently this is only true
             * if the value is numerical, but we might be able to widen the scope here and support
             * other value types.
             *
             * @internal
             */
            this.canTrackVelocity = null;
            /**
             * An object containing a SubscriptionManager for each active event.
             */
            this.events = {};
            this.updateAndNotify = (v) => {
                const currentTime = time.now();
                /**
                 * If we're updating the value during another frame or eventloop
                 * than the previous frame, then the we set the previous frame value
                 * to current.
                 */
                if (this.updatedAt !== currentTime) {
                    this.setPrevFrameValue();
                }
                this.prev = this.current;
                this.setCurrent(v);
                // Update update subscribers
                if (this.current !== this.prev) {
                    this.events.change?.notify(this.current);
                    if (this.dependents) {
                        for (const dependent of this.dependents) {
                            dependent.dirty();
                        }
                    }
                }
            };
            this.hasAnimated = false;
            this.setCurrent(init);
            this.owner = options.owner;
        }
        setCurrent(current) {
            this.current = current;
            this.updatedAt = time.now();
            if (this.canTrackVelocity === null && current !== undefined) {
                this.canTrackVelocity = isFloat(this.current);
            }
        }
        setPrevFrameValue(prevFrameValue = this.current) {
            this.prevFrameValue = prevFrameValue;
            this.prevUpdatedAt = this.updatedAt;
        }
        /**
         * Adds a function that will be notified when the `MotionValue` is updated.
         *
         * It returns a function that, when called, will cancel the subscription.
         *
         * When calling `onChange` inside a React component, it should be wrapped with the
         * `useEffect` hook. As it returns an unsubscribe function, this should be returned
         * from the `useEffect` function to ensure you don't add duplicate subscribers..
         *
         * ```jsx
         * export const MyComponent = () => {
         *   const x = useMotionValue(0)
         *   const y = useMotionValue(0)
         *   const opacity = useMotionValue(1)
         *
         *   useEffect(() => {
         *     function updateOpacity() {
         *       const maxXY = Math.max(x.get(), y.get())
         *       const newOpacity = transform(maxXY, [0, 100], [1, 0])
         *       opacity.set(newOpacity)
         *     }
         *
         *     const unsubscribeX = x.on("change", updateOpacity)
         *     const unsubscribeY = y.on("change", updateOpacity)
         *
         *     return () => {
         *       unsubscribeX()
         *       unsubscribeY()
         *     }
         *   }, [])
         *
         *   return <motion.div style={{ x }} />
         * }
         * ```
         *
         * @param subscriber - A function that receives the latest value.
         * @returns A function that, when called, will cancel this subscription.
         *
         * @deprecated
         */
        onChange(subscription) {
            {
                motionUtils.warnOnce(false, `value.onChange(callback) is deprecated. Switch to value.on("change", callback).`);
            }
            return this.on("change", subscription);
        }
        on(eventName, callback) {
            if (!this.events[eventName]) {
                this.events[eventName] = new motionUtils.SubscriptionManager();
            }
            const unsubscribe = this.events[eventName].add(callback);
            if (eventName === "change") {
                return () => {
                    unsubscribe();
                    /**
                     * If we have no more change listeners by the start
                     * of the next frame, stop active animations.
                     */
                    frame.read(() => {
                        if (!this.events.change.getSize()) {
                            this.stop();
                        }
                    });
                };
            }
            return unsubscribe;
        }
        clearListeners() {
            for (const eventManagers in this.events) {
                this.events[eventManagers].clear();
            }
        }
        /**
         * Attaches a passive effect to the `MotionValue`.
         */
        attach(passiveEffect, stopPassiveEffect) {
            this.passiveEffect = passiveEffect;
            this.stopPassiveEffect = stopPassiveEffect;
        }
        /**
         * Sets the state of the `MotionValue`.
         *
         * @remarks
         *
         * ```jsx
         * const x = useMotionValue(0)
         * x.set(10)
         * ```
         *
         * @param latest - Latest value to set.
         * @param render - Whether to notify render subscribers. Defaults to `true`
         *
         * @public
         */
        set(v) {
            if (!this.passiveEffect) {
                this.updateAndNotify(v);
            }
            else {
                this.passiveEffect(v, this.updateAndNotify);
            }
        }
        setWithVelocity(prev, current, delta) {
            this.set(current);
            this.prev = undefined;
            this.prevFrameValue = prev;
            this.prevUpdatedAt = this.updatedAt - delta;
        }
        /**
         * Set the state of the `MotionValue`, stopping any active animations,
         * effects, and resets velocity to `0`.
         */
        jump(v, endAnimation = true) {
            this.updateAndNotify(v);
            this.prev = v;
            this.prevUpdatedAt = this.prevFrameValue = undefined;
            endAnimation && this.stop();
            if (this.stopPassiveEffect)
                this.stopPassiveEffect();
        }
        dirty() {
            this.events.change?.notify(this.current);
        }
        addDependent(dependent) {
            if (!this.dependents) {
                this.dependents = new Set();
            }
            this.dependents.add(dependent);
        }
        removeDependent(dependent) {
            if (this.dependents) {
                this.dependents.delete(dependent);
            }
        }
        /**
         * Returns the latest state of `MotionValue`
         *
         * @returns - The latest state of `MotionValue`
         *
         * @public
         */
        get() {
            if (collectMotionValues.current) {
                collectMotionValues.current.push(this);
            }
            return this.current;
        }
        /**
         * @public
         */
        getPrevious() {
            return this.prev;
        }
        /**
         * Returns the latest velocity of `MotionValue`
         *
         * @returns - The latest velocity of `MotionValue`. Returns `0` if the state is non-numerical.
         *
         * @public
         */
        getVelocity() {
            const currentTime = time.now();
            if (!this.canTrackVelocity ||
                this.prevFrameValue === undefined ||
                currentTime - this.updatedAt > MAX_VELOCITY_DELTA) {
                return 0;
            }
            const delta = Math.min(this.updatedAt - this.prevUpdatedAt, MAX_VELOCITY_DELTA);
            // Casts because of parseFloat's poor typing
            return motionUtils.velocityPerSecond(parseFloat(this.current) -
                parseFloat(this.prevFrameValue), delta);
        }
        /**
         * Registers a new animation to control this `MotionValue`. Only one
         * animation can drive a `MotionValue` at one time.
         *
         * ```jsx
         * value.start()
         * ```
         *
         * @param animation - A function that starts the provided animation
         */
        start(startAnimation) {
            this.stop();
            return new Promise((resolve) => {
                this.hasAnimated = true;
                this.animation = startAnimation(resolve);
                if (this.events.animationStart) {
                    this.events.animationStart.notify();
                }
            }).then(() => {
                if (this.events.animationComplete) {
                    this.events.animationComplete.notify();
                }
                this.clearAnimation();
            });
        }
        /**
         * Stop the currently active animation.
         *
         * @public
         */
        stop() {
            if (this.animation) {
                this.animation.stop();
                if (this.events.animationCancel) {
                    this.events.animationCancel.notify();
                }
            }
            this.clearAnimation();
        }
        /**
         * Returns `true` if this value is currently animating.
         *
         * @public
         */
        isAnimating() {
            return !!this.animation;
        }
        clearAnimation() {
            delete this.animation;
        }
        /**
         * Destroy and clean up subscribers to this `MotionValue`.
         *
         * The `MotionValue` hooks like `useMotionValue` and `useTransform` automatically
         * handle the lifecycle of the returned `MotionValue`, so this method is only necessary if you've manually
         * created a `MotionValue` via the `motionValue` function.
         *
         * @public
         */
        destroy() {
            this.dependents?.clear();
            this.events.destroy?.notify();
            this.clearListeners();
            this.stop();
            if (this.stopPassiveEffect) {
                this.stopPassiveEffect();
            }
        }
    }
    function motionValue(init, options) {
        return new MotionValue(init, options);
    }

    const isKeyframesTarget = (v) => {
        return Array.isArray(v);
    };

    /**
     * Set VisualElement's MotionValue, creating a new MotionValue for it if
     * it doesn't exist.
     */
    function setMotionValue(visualElement, key, value) {
        if (visualElement.hasValue(key)) {
            visualElement.getValue(key).set(value);
        }
        else {
            visualElement.addValue(key, motionValue(value));
        }
    }
    function resolveFinalValueInKeyframes(v) {
        // TODO maybe throw if v.length - 1 is placeholder token?
        return isKeyframesTarget(v) ? v[v.length - 1] || 0 : v;
    }
    function setTarget(visualElement, definition) {
        const resolved = resolveVariant(visualElement, definition);
        let { transitionEnd = {}, transition = {}, ...target } = resolved || {};
        target = { ...target, ...transitionEnd };
        for (const key in target) {
            const value = resolveFinalValueInKeyframes(target[key]);
            setMotionValue(visualElement, key, value);
        }
    }

    const isMotionValue = (value) => Boolean(value && value.getVelocity);

    function isWillChangeMotionValue(value) {
        return Boolean(isMotionValue(value) && value.add);
    }

    function addValueToWillChange(visualElement, key) {
        const willChange = visualElement.getValue("willChange");
        /**
         * It could be that a user has set willChange to a regular MotionValue,
         * in which case we can't add the value to it.
         */
        if (isWillChangeMotionValue(willChange)) {
            return willChange.add(key);
        }
        else if (!willChange && motionUtils.MotionGlobalConfig.WillChange) {
            const newWillChange = new motionUtils.MotionGlobalConfig.WillChange("auto");
            visualElement.addValue("willChange", newWillChange);
            newWillChange.add(key);
        }
    }

    function camelToDash(str) {
        return str.replace(/([A-Z])/g, (match) => `-${match.toLowerCase()}`);
    }

    const optimizedAppearDataId = "framerAppearId";
    const optimizedAppearDataAttribute = "data-" + camelToDash(optimizedAppearDataId);

    function getOptimisedAppearId(visualElement) {
        return visualElement.props[optimizedAppearDataAttribute];
    }

    /**
     * Decide whether we should block this animation. Previously, we achieved this
     * just by checking whether the key was listed in protectedKeys, but this
     * posed problems if an animation was triggered by afterChildren and protectedKeys
     * had been set to true in the meantime.
     */
    function shouldBlockAnimation({ protectedKeys, needsAnimating }, key) {
        const shouldBlock = protectedKeys.hasOwnProperty(key) && needsAnimating[key] !== true;
        needsAnimating[key] = false;
        return shouldBlock;
    }
    function animateTarget(visualElement, targetAndTransition, { delay = 0, transitionOverride, type } = {}) {
        let { transition = visualElement.getDefaultTransition(), transitionEnd, ...target } = targetAndTransition;
        if (transitionOverride)
            transition = transitionOverride;
        const animations = [];
        const animationTypeState = type &&
            visualElement.animationState &&
            visualElement.animationState.getState()[type];
        for (const key in target) {
            const value = visualElement.getValue(key, visualElement.latestValues[key] ?? null);
            const valueTarget = target[key];
            if (valueTarget === undefined ||
                (animationTypeState &&
                    shouldBlockAnimation(animationTypeState, key))) {
                continue;
            }
            const valueTransition = {
                delay,
                ...getValueTransition(transition || {}, key),
            };
            /**
             * If the value is already at the defined target, skip the animation.
             */
            const currentValue = value.get();
            if (currentValue !== undefined &&
                !value.isAnimating &&
                !Array.isArray(valueTarget) &&
                valueTarget === currentValue &&
                !valueTransition.velocity) {
                continue;
            }
            /**
             * If this is the first time a value is being animated, check
             * to see if we're handling off from an existing animation.
             */
            let isHandoff = false;
            if (window.MotionHandoffAnimation) {
                const appearId = getOptimisedAppearId(visualElement);
                if (appearId) {
                    const startTime = window.MotionHandoffAnimation(appearId, key, frame);
                    if (startTime !== null) {
                        valueTransition.startTime = startTime;
                        isHandoff = true;
                    }
                }
            }
            addValueToWillChange(visualElement, key);
            value.start(animateMotionValue(key, value, valueTarget, visualElement.shouldReduceMotion && positionalKeys.has(key)
                ? { type: false }
                : valueTransition, visualElement, isHandoff));
            const animation = value.animation;
            if (animation) {
                animations.push(animation);
            }
        }
        if (transitionEnd) {
            Promise.all(animations).then(() => {
                frame.update(() => {
                    transitionEnd && setTarget(visualElement, transitionEnd);
                });
            });
        }
        return animations;
    }

    function animateVariant(visualElement, variant, options = {}) {
        const resolved = resolveVariant(visualElement, variant, options.type === "exit"
            ? visualElement.presenceContext?.custom
            : undefined);
        let { transition = visualElement.getDefaultTransition() || {} } = resolved || {};
        if (options.transitionOverride) {
            transition = options.transitionOverride;
        }
        /**
         * If we have a variant, create a callback that runs it as an animation.
         * Otherwise, we resolve a Promise immediately for a composable no-op.
         */
        const getAnimation = resolved
            ? () => Promise.all(animateTarget(visualElement, resolved, options))
            : () => Promise.resolve();
        /**
         * If we have children, create a callback that runs all their animations.
         * Otherwise, we resolve a Promise immediately for a composable no-op.
         */
        const getChildAnimations = visualElement.variantChildren && visualElement.variantChildren.size
            ? (forwardDelay = 0) => {
                const { delayChildren = 0, staggerChildren, staggerDirection, } = transition;
                return animateChildren(visualElement, variant, forwardDelay, delayChildren, staggerChildren, staggerDirection, options);
            }
            : () => Promise.resolve();
        /**
         * If the transition explicitly defines a "when" option, we need to resolve either
         * this animation or all children animations before playing the other.
         */
        const { when } = transition;
        if (when) {
            const [first, last] = when === "beforeChildren"
                ? [getAnimation, getChildAnimations]
                : [getChildAnimations, getAnimation];
            return first().then(() => last());
        }
        else {
            return Promise.all([getAnimation(), getChildAnimations(options.delay)]);
        }
    }
    function animateChildren(visualElement, variant, delay = 0, delayChildren = 0, staggerChildren = 0, staggerDirection = 1, options) {
        const animations = [];
        for (const child of visualElement.variantChildren) {
            child.notify("AnimationStart", variant);
            animations.push(animateVariant(child, variant, {
                ...options,
                delay: delay +
                    (typeof delayChildren === "function" ? 0 : delayChildren) +
                    calcChildStagger(visualElement.variantChildren, child, delayChildren, staggerChildren, staggerDirection),
            }).then(() => child.notify("AnimationComplete", variant)));
        }
        return Promise.all(animations);
    }

    function animateVisualElement(visualElement, definition, options = {}) {
        visualElement.notify("AnimationStart", definition);
        let animation;
        if (Array.isArray(definition)) {
            const animations = definition.map((variant) => animateVariant(visualElement, variant, options));
            animation = Promise.all(animations);
        }
        else if (typeof definition === "string") {
            animation = animateVariant(visualElement, definition, options);
        }
        else {
            const resolvedDefinition = typeof definition === "function"
                ? resolveVariant(visualElement, definition, options.custom)
                : definition;
            animation = Promise.all(animateTarget(visualElement, resolvedDefinition, options));
        }
        return animation.then(() => {
            visualElement.notify("AnimationComplete", definition);
        });
    }

    /**
     * ValueType for "auto"
     */
    const auto = {
        test: (v) => v === "auto",
        parse: (v) => v,
    };

    /**
     * Tests a provided value against a ValueType
     */
    const testValueType = (v) => (type) => type.test(v);

    /**
     * A list of value types commonly used for dimensions
     */
    const dimensionValueTypes = [number, px, percent, degrees, vw, vh, auto];
    /**
     * Tests a dimensional value against the list of dimension ValueTypes
     */
    const findDimensionValueType = (v) => dimensionValueTypes.find(testValueType(v));

    function isNone(value) {
        if (typeof value === "number") {
            return value === 0;
        }
        else if (value !== null) {
            return value === "none" || value === "0" || motionUtils.isZeroValueString(value);
        }
        else {
            return true;
        }
    }

    /**
     * Properties that should default to 1 or 100%
     */
    const maxDefaults = new Set(["brightness", "contrast", "saturate", "opacity"]);
    function applyDefaultFilter(v) {
        const [name, value] = v.slice(0, -1).split("(");
        if (name === "drop-shadow")
            return v;
        const [number] = value.match(floatRegex) || [];
        if (!number)
            return v;
        const unit = value.replace(number, "");
        let defaultValue = maxDefaults.has(name) ? 1 : 0;
        if (number !== value)
            defaultValue *= 100;
        return name + "(" + defaultValue + unit + ")";
    }
    const functionRegex = /\b([a-z-]*)\(.*?\)/gu;
    const filter = {
        ...complex,
        getAnimatableNone: (v) => {
            const functions = v.match(functionRegex);
            return functions ? functions.map(applyDefaultFilter).join(" ") : v;
        },
    };

    const int = {
        ...number,
        transform: Math.round,
    };

    const transformValueTypes = {
        rotate: degrees,
        rotateX: degrees,
        rotateY: degrees,
        rotateZ: degrees,
        scale,
        scaleX: scale,
        scaleY: scale,
        scaleZ: scale,
        skew: degrees,
        skewX: degrees,
        skewY: degrees,
        distance: px,
        translateX: px,
        translateY: px,
        translateZ: px,
        x: px,
        y: px,
        z: px,
        perspective: px,
        transformPerspective: px,
        opacity: alpha,
        originX: progressPercentage,
        originY: progressPercentage,
        originZ: px,
    };

    const numberValueTypes = {
        // Border props
        borderWidth: px,
        borderTopWidth: px,
        borderRightWidth: px,
        borderBottomWidth: px,
        borderLeftWidth: px,
        borderRadius: px,
        radius: px,
        borderTopLeftRadius: px,
        borderTopRightRadius: px,
        borderBottomRightRadius: px,
        borderBottomLeftRadius: px,
        // Positioning props
        width: px,
        maxWidth: px,
        height: px,
        maxHeight: px,
        top: px,
        right: px,
        bottom: px,
        left: px,
        inset: px,
        insetBlock: px,
        insetBlockStart: px,
        insetBlockEnd: px,
        insetInline: px,
        insetInlineStart: px,
        insetInlineEnd: px,
        // Spacing props
        padding: px,
        paddingTop: px,
        paddingRight: px,
        paddingBottom: px,
        paddingLeft: px,
        paddingBlock: px,
        paddingBlockStart: px,
        paddingBlockEnd: px,
        paddingInline: px,
        paddingInlineStart: px,
        paddingInlineEnd: px,
        margin: px,
        marginTop: px,
        marginRight: px,
        marginBottom: px,
        marginLeft: px,
        marginBlock: px,
        marginBlockStart: px,
        marginBlockEnd: px,
        marginInline: px,
        marginInlineStart: px,
        marginInlineEnd: px,
        // Misc
        backgroundPositionX: px,
        backgroundPositionY: px,
        ...transformValueTypes,
        zIndex: int,
        // SVG
        fillOpacity: alpha,
        strokeOpacity: alpha,
        numOctaves: int,
    };

    /**
     * A map of default value types for common values
     */
    const defaultValueTypes = {
        ...numberValueTypes,
        // Color props
        color,
        backgroundColor: color,
        outlineColor: color,
        fill: color,
        stroke: color,
        // Border props
        borderColor: color,
        borderTopColor: color,
        borderRightColor: color,
        borderBottomColor: color,
        borderLeftColor: color,
        filter,
        WebkitFilter: filter,
    };
    /**
     * Gets the default ValueType for the provided value key
     */
    const getDefaultValueType = (key) => defaultValueTypes[key];

    function getAnimatableNone(key, value) {
        let defaultValueType = getDefaultValueType(key);
        if (defaultValueType !== filter)
            defaultValueType = complex;
        // If value is not recognised as animatable, ie "none", create an animatable version origin based on the target
        return defaultValueType.getAnimatableNone
            ? defaultValueType.getAnimatableNone(value)
            : undefined;
    }

    /**
     * If we encounter keyframes like "none" or "0" and we also have keyframes like
     * "#fff" or "200px 200px" we want to find a keyframe to serve as a template for
     * the "none" keyframes. In this case "#fff" or "200px 200px" - then these get turned into
     * zero equivalents, i.e. "#fff0" or "0px 0px".
     */
    const invalidTemplates = new Set(["auto", "none", "0"]);
    function makeNoneKeyframesAnimatable(unresolvedKeyframes, noneKeyframeIndexes, name) {
        let i = 0;
        let animatableTemplate = undefined;
        while (i < unresolvedKeyframes.length && !animatableTemplate) {
            const keyframe = unresolvedKeyframes[i];
            if (typeof keyframe === "string" &&
                !invalidTemplates.has(keyframe) &&
                analyseComplexValue(keyframe).values.length) {
                animatableTemplate = unresolvedKeyframes[i];
            }
            i++;
        }
        if (animatableTemplate && name) {
            for (const noneIndex of noneKeyframeIndexes) {
                unresolvedKeyframes[noneIndex] = getAnimatableNone(name, animatableTemplate);
            }
        }
    }

    class DOMKeyframesResolver extends KeyframeResolver {
        constructor(unresolvedKeyframes, onComplete, name, motionValue, element) {
            super(unresolvedKeyframes, onComplete, name, motionValue, element, true);
        }
        readKeyframes() {
            const { unresolvedKeyframes, element, name } = this;
            if (!element || !element.current)
                return;
            super.readKeyframes();
            /**
             * If any keyframe is a CSS variable, we need to find its value by sampling the element
             */
            for (let i = 0; i < unresolvedKeyframes.length; i++) {
                let keyframe = unresolvedKeyframes[i];
                if (typeof keyframe === "string") {
                    keyframe = keyframe.trim();
                    if (isCSSVariableToken(keyframe)) {
                        const resolved = getVariableValue(keyframe, element.current);
                        if (resolved !== undefined) {
                            unresolvedKeyframes[i] = resolved;
                        }
                        if (i === unresolvedKeyframes.length - 1) {
                            this.finalKeyframe = keyframe;
                        }
                    }
                }
            }
            /**
             * Resolve "none" values. We do this potentially twice - once before and once after measuring keyframes.
             * This could be seen as inefficient but it's a trade-off to avoid measurements in more situations, which
             * have a far bigger performance impact.
             */
            this.resolveNoneKeyframes();
            /**
             * Check to see if unit type has changed. If so schedule jobs that will
             * temporarily set styles to the destination keyframes.
             * Skip if we have more than two keyframes or this isn't a positional value.
             * TODO: We can throw if there are multiple keyframes and the value type changes.
             */
            if (!positionalKeys.has(name) || unresolvedKeyframes.length !== 2) {
                return;
            }
            const [origin, target] = unresolvedKeyframes;
            const originType = findDimensionValueType(origin);
            const targetType = findDimensionValueType(target);
            /**
             * If one keyframe contains embedded CSS variables (e.g. in calc()) and the other
             * doesn't, we need to measure to convert to pixels. This handles GitHub issue #3410.
             */
            const originHasVar = containsCSSVariable(origin);
            const targetHasVar = containsCSSVariable(target);
            if (originHasVar !== targetHasVar && positionalValues[name]) {
                this.needsMeasurement = true;
                return;
            }
            /**
             * Either we don't recognise these value types or we can animate between them.
             */
            if (originType === targetType)
                return;
            /**
             * If both values are numbers or pixels, we can animate between them by
             * converting them to numbers.
             */
            if (isNumOrPxType(originType) && isNumOrPxType(targetType)) {
                for (let i = 0; i < unresolvedKeyframes.length; i++) {
                    const value = unresolvedKeyframes[i];
                    if (typeof value === "string") {
                        unresolvedKeyframes[i] = parseFloat(value);
                    }
                }
            }
            else if (positionalValues[name]) {
                /**
                 * Else, the only way to resolve this is by measuring the element.
                 */
                this.needsMeasurement = true;
            }
        }
        resolveNoneKeyframes() {
            const { unresolvedKeyframes, name } = this;
            const noneKeyframeIndexes = [];
            for (let i = 0; i < unresolvedKeyframes.length; i++) {
                if (unresolvedKeyframes[i] === null ||
                    isNone(unresolvedKeyframes[i])) {
                    noneKeyframeIndexes.push(i);
                }
            }
            if (noneKeyframeIndexes.length) {
                makeNoneKeyframesAnimatable(unresolvedKeyframes, noneKeyframeIndexes, name);
            }
        }
        measureInitialState() {
            const { element, unresolvedKeyframes, name } = this;
            if (!element || !element.current)
                return;
            if (name === "height") {
                this.suspendedScrollY = window.pageYOffset;
            }
            this.measuredOrigin = positionalValues[name](element.measureViewportBox(), window.getComputedStyle(element.current));
            unresolvedKeyframes[0] = this.measuredOrigin;
            // Set final key frame to measure after next render
            const measureKeyframe = unresolvedKeyframes[unresolvedKeyframes.length - 1];
            if (measureKeyframe !== undefined) {
                element.getValue(name, measureKeyframe).jump(measureKeyframe, false);
            }
        }
        measureEndState() {
            const { element, name, unresolvedKeyframes } = this;
            if (!element || !element.current)
                return;
            const value = element.getValue(name);
            value && value.jump(this.measuredOrigin, false);
            const finalKeyframeIndex = unresolvedKeyframes.length - 1;
            const finalKeyframe = unresolvedKeyframes[finalKeyframeIndex];
            unresolvedKeyframes[finalKeyframeIndex] = positionalValues[name](element.measureViewportBox(), window.getComputedStyle(element.current));
            if (finalKeyframe !== null && this.finalKeyframe === undefined) {
                this.finalKeyframe = finalKeyframe;
            }
            // If we removed transform values, reapply them before the next render
            if (this.removedTransforms?.length) {
                this.removedTransforms.forEach(([unsetTransformName, unsetTransformValue]) => {
                    element
                        .getValue(unsetTransformName)
                        .set(unsetTransformValue);
                });
            }
            this.resolveNoneKeyframes();
        }
    }

    const pxValues = new Set([
        // Border props
        "borderWidth",
        "borderTopWidth",
        "borderRightWidth",
        "borderBottomWidth",
        "borderLeftWidth",
        "borderRadius",
        "radius",
        "borderTopLeftRadius",
        "borderTopRightRadius",
        "borderBottomRightRadius",
        "borderBottomLeftRadius",
        // Positioning props
        "width",
        "maxWidth",
        "height",
        "maxHeight",
        "top",
        "right",
        "bottom",
        "left",
        "inset",
        "insetBlock",
        "insetBlockStart",
        "insetBlockEnd",
        "insetInline",
        "insetInlineStart",
        "insetInlineEnd",
        // Spacing props
        "padding",
        "paddingTop",
        "paddingRight",
        "paddingBottom",
        "paddingLeft",
        "paddingBlock",
        "paddingBlockStart",
        "paddingBlockEnd",
        "paddingInline",
        "paddingInlineStart",
        "paddingInlineEnd",
        "margin",
        "marginTop",
        "marginRight",
        "marginBottom",
        "marginLeft",
        "marginBlock",
        "marginBlockStart",
        "marginBlockEnd",
        "marginInline",
        "marginInlineStart",
        "marginInlineEnd",
        // Misc
        "backgroundPositionX",
        "backgroundPositionY",
    ]);

    function applyPxDefaults(keyframes, name) {
        for (let i = 0; i < keyframes.length; i++) {
            if (typeof keyframes[i] === "number" && pxValues.has(name)) {
                keyframes[i] = keyframes[i] + "px";
            }
        }
    }

    function isWaapiSupportedEasing(easing) {
        return Boolean((typeof easing === "function" && supportsLinearEasing()) ||
            !easing ||
            (typeof easing === "string" &&
                (easing in supportedWaapiEasing || supportsLinearEasing())) ||
            motionUtils.isBezierDefinition(easing) ||
            (Array.isArray(easing) && easing.every(isWaapiSupportedEasing)));
    }

    const supportsPartialKeyframes = /*@__PURE__*/ motionUtils.memo(() => {
        try {
            document.createElement("div").animate({ opacity: [1] });
        }
        catch (e) {
            return false;
        }
        return true;
    });

    /**
     * A list of values that can be hardware-accelerated.
     */
    const acceleratedValues = new Set([
        "opacity",
        "clipPath",
        "filter",
        "transform",
        // TODO: Can be accelerated but currently disabled until https://issues.chromium.org/issues/41491098 is resolved
        // or until we implement support for linear() easing.
        // "background-color"
    ]);

    function resolveElements(elementOrSelector, scope, selectorCache) {
        if (elementOrSelector == null) {
            return [];
        }
        if (elementOrSelector instanceof EventTarget) {
            return [elementOrSelector];
        }
        else if (typeof elementOrSelector === "string") {
            let root = document;
            if (scope) {
                root = scope.current;
            }
            const elements = selectorCache?.[elementOrSelector] ??
                root.querySelectorAll(elementOrSelector);
            return elements ? Array.from(elements) : [];
        }
        return Array.from(elementOrSelector).filter((element) => element != null);
    }

    function createSelectorEffect(subjectEffect) {
        return (subject, values) => {
            const elements = resolveElements(subject);
            const subscriptions = [];
            for (const element of elements) {
                const remove = subjectEffect(element, values);
                subscriptions.push(remove);
            }
            return () => {
                for (const remove of subscriptions)
                    remove();
            };
        };
    }

    /**
     * Provided a value and a ValueType, returns the value as that value type.
     */
    const getValueAsType = (value, type) => {
        return type && typeof value === "number"
            ? type.transform(value)
            : value;
    };

    class MotionValueState {
        constructor() {
            this.latest = {};
            this.values = new Map();
        }
        set(name, value, render, computed, useDefaultValueType = true) {
            const existingValue = this.values.get(name);
            if (existingValue) {
                existingValue.onRemove();
            }
            const onChange = () => {
                const v = value.get();
                if (useDefaultValueType) {
                    this.latest[name] = getValueAsType(v, numberValueTypes[name]);
                }
                else {
                    this.latest[name] = v;
                }
                render && frame.render(render);
            };
            onChange();
            const cancelOnChange = value.on("change", onChange);
            computed && value.addDependent(computed);
            const remove = () => {
                cancelOnChange();
                render && cancelFrame(render);
                this.values.delete(name);
                computed && value.removeDependent(computed);
            };
            this.values.set(name, { value, onRemove: remove });
            return remove;
        }
        get(name) {
            return this.values.get(name)?.value;
        }
        destroy() {
            for (const value of this.values.values()) {
                value.onRemove();
            }
        }
    }

    function createEffect(addValue) {
        const stateCache = new WeakMap();
        const subscriptions = [];
        return (subject, values) => {
            const state = stateCache.get(subject) ?? new MotionValueState();
            stateCache.set(subject, state);
            for (const key in values) {
                const value = values[key];
                const remove = addValue(subject, state, key, value);
                subscriptions.push(remove);
            }
            return () => {
                for (const cancel of subscriptions)
                    cancel();
            };
        };
    }

    function canSetAsProperty(element, name) {
        if (!(name in element))
            return false;
        const descriptor = Object.getOwnPropertyDescriptor(Object.getPrototypeOf(element), name) ||
            Object.getOwnPropertyDescriptor(element, name);
        // Check if it has a setter
        return descriptor && typeof descriptor.set === "function";
    }
    const addAttrValue = (element, state, key, value) => {
        const isProp = canSetAsProperty(element, key);
        const name = isProp
            ? key
            : key.startsWith("data") || key.startsWith("aria")
                ? camelToDash(key)
                : key;
        /**
         * Set attribute directly via property if available
         */
        const render = isProp
            ? () => {
                element[name] = state.latest[key];
            }
            : () => {
                const v = state.latest[key];
                if (v === null || v === undefined) {
                    element.removeAttribute(name);
                }
                else {
                    element.setAttribute(name, String(v));
                }
            };
        return state.set(key, value, render);
    };
    const attrEffect = /*@__PURE__*/ createSelectorEffect(
    /*@__PURE__*/ createEffect(addAttrValue));

    const propEffect = /*@__PURE__*/ createEffect((subject, state, key, value) => {
        return state.set(key, value, () => {
            subject[key] = state.latest[key];
        }, undefined, false);
    });

    /**
     * Checks if an element is an HTML element in a way
     * that works across iframes
     */
    function isHTMLElement(element) {
        return motionUtils.isObject(element) && "offsetHeight" in element;
    }

    const translateAlias$1 = {
        x: "translateX",
        y: "translateY",
        z: "translateZ",
        transformPerspective: "perspective",
    };
    function buildTransform$1(state) {
        let transform = "";
        let transformIsDefault = true;
        /**
         * Loop over all possible transforms in order, adding the ones that
         * are present to the transform string.
         */
        for (let i = 0; i < transformPropOrder.length; i++) {
            const key = transformPropOrder[i];
            const value = state.latest[key];
            if (value === undefined)
                continue;
            let valueIsDefault = true;
            if (typeof value === "number") {
                valueIsDefault = value === (key.startsWith("scale") ? 1 : 0);
            }
            else {
                valueIsDefault = parseFloat(value) === 0;
            }
            if (!valueIsDefault) {
                transformIsDefault = false;
                const transformName = translateAlias$1[key] || key;
                const valueToRender = state.latest[key];
                transform += `${transformName}(${valueToRender}) `;
            }
        }
        return transformIsDefault ? "none" : transform.trim();
    }

    const originProps = new Set(["originX", "originY", "originZ"]);
    const addStyleValue = (element, state, key, value) => {
        let render = undefined;
        let computed = undefined;
        if (transformProps.has(key)) {
            if (!state.get("transform")) {
                // If this is an HTML element, we need to set the transform-box to fill-box
                // to normalise the transform relative to the element's bounding box
                if (!isHTMLElement(element) && !state.get("transformBox")) {
                    addStyleValue(element, state, "transformBox", new MotionValue("fill-box"));
                }
                state.set("transform", new MotionValue("none"), () => {
                    element.style.transform = buildTransform$1(state);
                });
            }
            computed = state.get("transform");
        }
        else if (originProps.has(key)) {
            if (!state.get("transformOrigin")) {
                state.set("transformOrigin", new MotionValue(""), () => {
                    const originX = state.latest.originX ?? "50%";
                    const originY = state.latest.originY ?? "50%";
                    const originZ = state.latest.originZ ?? 0;
                    element.style.transformOrigin = `${originX} ${originY} ${originZ}`;
                });
            }
            computed = state.get("transformOrigin");
        }
        else if (isCSSVar(key)) {
            render = () => {
                element.style.setProperty(key, state.latest[key]);
            };
        }
        else {
            render = () => {
                element.style[key] = state.latest[key];
            };
        }
        return state.set(key, value, render, computed);
    };
    const styleEffect = /*@__PURE__*/ createSelectorEffect(
    /*@__PURE__*/ createEffect(addStyleValue));

    function addSVGPathValue(element, state, key, value) {
        frame.render(() => element.setAttribute("pathLength", "1"));
        if (key === "pathOffset") {
            return state.set(key, value, () => {
                // Use unitless value to avoid Safari zoom bug
                const offset = state.latest[key];
                element.setAttribute("stroke-dashoffset", `${-offset}`);
            });
        }
        else {
            if (!state.get("stroke-dasharray")) {
                state.set("stroke-dasharray", new MotionValue("1 1"), () => {
                    const { pathLength = 1, pathSpacing } = state.latest;
                    // Use unitless values to avoid Safari zoom bug
                    element.setAttribute("stroke-dasharray", `${pathLength} ${pathSpacing ?? 1 - Number(pathLength)}`);
                });
            }
            return state.set(key, value, undefined, state.get("stroke-dasharray"));
        }
    }
    const addSVGValue = (element, state, key, value) => {
        if (key.startsWith("path")) {
            return addSVGPathValue(element, state, key, value);
        }
        else if (key.startsWith("attr")) {
            return addAttrValue(element, state, convertAttrKey(key), value);
        }
        const handler = key in element.style ? addStyleValue : addAttrValue;
        return handler(element, state, key, value);
    };
    const svgEffect = /*@__PURE__*/ createSelectorEffect(
    /*@__PURE__*/ createEffect(addSVGValue));
    function convertAttrKey(key) {
        return key.replace(/^attr([A-Z])/, (_, firstChar) => firstChar.toLowerCase());
    }

    const { schedule: microtask, cancel: cancelMicrotask } = 
    /* @__PURE__ */ createRenderBatcher(queueMicrotask, false);

    const isDragging = {
        x: false,
        y: false,
    };
    function isDragActive() {
        return isDragging.x || isDragging.y;
    }

    function setDragLock(axis) {
        if (axis === "x" || axis === "y") {
            if (isDragging[axis]) {
                return null;
            }
            else {
                isDragging[axis] = true;
                return () => {
                    isDragging[axis] = false;
                };
            }
        }
        else {
            if (isDragging.x || isDragging.y) {
                return null;
            }
            else {
                isDragging.x = isDragging.y = true;
                return () => {
                    isDragging.x = isDragging.y = false;
                };
            }
        }
    }

    function setupGesture(elementOrSelector, options) {
        const elements = resolveElements(elementOrSelector);
        const gestureAbortController = new AbortController();
        const eventOptions = {
            passive: true,
            ...options,
            signal: gestureAbortController.signal,
        };
        const cancel = () => gestureAbortController.abort();
        return [elements, eventOptions, cancel];
    }

    function isValidHover(event) {
        return !(event.pointerType === "touch" || isDragActive());
    }
    /**
     * Create a hover gesture. hover() is different to .addEventListener("pointerenter")
     * in that it has an easier syntax, filters out polyfilled touch events, interoperates
     * with drag gestures, and automatically removes the "pointerennd" event listener when the hover ends.
     *
     * @public
     */
    function hover(elementOrSelector, onHoverStart, options = {}) {
        const [elements, eventOptions, cancel] = setupGesture(elementOrSelector, options);
        const onPointerEnter = (enterEvent) => {
            if (!isValidHover(enterEvent))
                return;
            const { target } = enterEvent;
            const onHoverEnd = onHoverStart(target, enterEvent);
            if (typeof onHoverEnd !== "function" || !target)
                return;
            const onPointerLeave = (leaveEvent) => {
                if (!isValidHover(leaveEvent))
                    return;
                onHoverEnd(leaveEvent);
                target.removeEventListener("pointerleave", onPointerLeave);
            };
            target.addEventListener("pointerleave", onPointerLeave, eventOptions);
        };
        elements.forEach((element) => {
            element.addEventListener("pointerenter", onPointerEnter, eventOptions);
        });
        return cancel;
    }

    /**
     * Recursively traverse up the tree to check whether the provided child node
     * is the parent or a descendant of it.
     *
     * @param parent - Element to find
     * @param child - Element to test against parent
     */
    const isNodeOrChild = (parent, child) => {
        if (!child) {
            return false;
        }
        else if (parent === child) {
            return true;
        }
        else {
            return isNodeOrChild(parent, child.parentElement);
        }
    };

    const isPrimaryPointer = (event) => {
        if (event.pointerType === "mouse") {
            return typeof event.button !== "number" || event.button <= 0;
        }
        else {
            /**
             * isPrimary is true for all mice buttons, whereas every touch point
             * is regarded as its own input. So subsequent concurrent touch points
             * will be false.
             *
             * Specifically match against false here as incomplete versions of
             * PointerEvents in very old browser might have it set as undefined.
             */
            return event.isPrimary !== false;
        }
    };

    const interactiveElements = new Set([
        "BUTTON",
        "INPUT",
        "SELECT",
        "TEXTAREA",
        "A",
    ]);
    /**
     * Checks if an element is an interactive form element that should prevent
     * drag gestures from starting when clicked.
     *
     * This specifically targets form controls, buttons, and links - not just any
     * element with tabIndex, since motion elements with tap handlers automatically
     * get tabIndex=0 for keyboard accessibility.
     */
    function isElementKeyboardAccessible(element) {
        return (interactiveElements.has(element.tagName) ||
            element.isContentEditable === true);
    }

    const isPressing = new WeakSet();

    /**
     * Filter out events that are not "Enter" keys.
     */
    function filterEvents(callback) {
        return (event) => {
            if (event.key !== "Enter")
                return;
            callback(event);
        };
    }
    function firePointerEvent(target, type) {
        target.dispatchEvent(new PointerEvent("pointer" + type, { isPrimary: true, bubbles: true }));
    }
    const enableKeyboardPress = (focusEvent, eventOptions) => {
        const element = focusEvent.currentTarget;
        if (!element)
            return;
        const handleKeydown = filterEvents(() => {
            if (isPressing.has(element))
                return;
            firePointerEvent(element, "down");
            const handleKeyup = filterEvents(() => {
                firePointerEvent(element, "up");
            });
            const handleBlur = () => firePointerEvent(element, "cancel");
            element.addEventListener("keyup", handleKeyup, eventOptions);
            element.addEventListener("blur", handleBlur, eventOptions);
        });
        element.addEventListener("keydown", handleKeydown, eventOptions);
        /**
         * Add an event listener that fires on blur to remove the keydown events.
         */
        element.addEventListener("blur", () => element.removeEventListener("keydown", handleKeydown), eventOptions);
    };

    /**
     * Filter out events that are not primary pointer events, or are triggering
     * while a Motion gesture is active.
     */
    function isValidPressEvent(event) {
        return isPrimaryPointer(event) && !isDragActive();
    }
    /**
     * Create a press gesture.
     *
     * Press is different to `"pointerdown"`, `"pointerup"` in that it
     * automatically filters out secondary pointer events like right
     * click and multitouch.
     *
     * It also adds accessibility support for keyboards, where
     * an element with a press gesture will receive focus and
     *  trigger on Enter `"keydown"` and `"keyup"` events.
     *
     * This is different to a browser's `"click"` event, which does
     * respond to keyboards but only for the `"click"` itself, rather
     * than the press start and end/cancel. The element also needs
     * to be focusable for this to work, whereas a press gesture will
     * make an element focusable by default.
     *
     * @public
     */
    function press(targetOrSelector, onPressStart, options = {}) {
        const [targets, eventOptions, cancelEvents] = setupGesture(targetOrSelector, options);
        const startPress = (startEvent) => {
            const target = startEvent.currentTarget;
            if (!isValidPressEvent(startEvent))
                return;
            isPressing.add(target);
            const onPressEnd = onPressStart(target, startEvent);
            const onPointerEnd = (endEvent, success) => {
                window.removeEventListener("pointerup", onPointerUp);
                window.removeEventListener("pointercancel", onPointerCancel);
                if (isPressing.has(target)) {
                    isPressing.delete(target);
                }
                if (!isValidPressEvent(endEvent)) {
                    return;
                }
                if (typeof onPressEnd === "function") {
                    onPressEnd(endEvent, { success });
                }
            };
            const onPointerUp = (upEvent) => {
                onPointerEnd(upEvent, target === window ||
                    target === document ||
                    options.useGlobalTarget ||
                    isNodeOrChild(target, upEvent.target));
            };
            const onPointerCancel = (cancelEvent) => {
                onPointerEnd(cancelEvent, false);
            };
            window.addEventListener("pointerup", onPointerUp, eventOptions);
            window.addEventListener("pointercancel", onPointerCancel, eventOptions);
        };
        targets.forEach((target) => {
            const pointerDownTarget = options.useGlobalTarget ? window : target;
            pointerDownTarget.addEventListener("pointerdown", startPress, eventOptions);
            if (isHTMLElement(target)) {
                target.addEventListener("focus", (event) => enableKeyboardPress(event, eventOptions));
                if (!isElementKeyboardAccessible(target) &&
                    !target.hasAttribute("tabindex")) {
                    target.tabIndex = 0;
                }
            }
        });
        return cancelEvents;
    }

    function getComputedStyle$2(element, name) {
        const computedStyle = window.getComputedStyle(element);
        return isCSSVar(name)
            ? computedStyle.getPropertyValue(name)
            : computedStyle[name];
    }

    /**
     * Checks if an element is an SVG element in a way
     * that works across iframes
     */
    function isSVGElement(element) {
        return motionUtils.isObject(element) && "ownerSVGElement" in element;
    }

    const resizeHandlers = new WeakMap();
    let observer;
    const getSize = (borderBoxAxis, svgAxis, htmlAxis) => (target, borderBoxSize) => {
        if (borderBoxSize && borderBoxSize[0]) {
            return borderBoxSize[0][(borderBoxAxis + "Size")];
        }
        else if (isSVGElement(target) && "getBBox" in target) {
            return target.getBBox()[svgAxis];
        }
        else {
            return target[htmlAxis];
        }
    };
    const getWidth = /*@__PURE__*/ getSize("inline", "width", "offsetWidth");
    const getHeight = /*@__PURE__*/ getSize("block", "height", "offsetHeight");
    function notifyTarget({ target, borderBoxSize }) {
        resizeHandlers.get(target)?.forEach((handler) => {
            handler(target, {
                get width() {
                    return getWidth(target, borderBoxSize);
                },
                get height() {
                    return getHeight(target, borderBoxSize);
                },
            });
        });
    }
    function notifyAll(entries) {
        entries.forEach(notifyTarget);
    }
    function createResizeObserver() {
        if (typeof ResizeObserver === "undefined")
            return;
        observer = new ResizeObserver(notifyAll);
    }
    function resizeElement(target, handler) {
        if (!observer)
            createResizeObserver();
        const elements = resolveElements(target);
        elements.forEach((element) => {
            let elementHandlers = resizeHandlers.get(element);
            if (!elementHandlers) {
                elementHandlers = new Set();
                resizeHandlers.set(element, elementHandlers);
            }
            elementHandlers.add(handler);
            observer?.observe(element);
        });
        return () => {
            elements.forEach((element) => {
                const elementHandlers = resizeHandlers.get(element);
                elementHandlers?.delete(handler);
                if (!elementHandlers?.size) {
                    observer?.unobserve(element);
                }
            });
        };
    }

    const windowCallbacks = new Set();
    let windowResizeHandler;
    function createWindowResizeHandler() {
        windowResizeHandler = () => {
            const info = {
                get width() {
                    return window.innerWidth;
                },
                get height() {
                    return window.innerHeight;
                },
            };
            windowCallbacks.forEach((callback) => callback(info));
        };
        window.addEventListener("resize", windowResizeHandler);
    }
    function resizeWindow(callback) {
        windowCallbacks.add(callback);
        if (!windowResizeHandler)
            createWindowResizeHandler();
        return () => {
            windowCallbacks.delete(callback);
            if (!windowCallbacks.size &&
                typeof windowResizeHandler === "function") {
                window.removeEventListener("resize", windowResizeHandler);
                windowResizeHandler = undefined;
            }
        };
    }

    function resize(a, b) {
        return typeof a === "function" ? resizeWindow(a) : resizeElement(a, b);
    }

    function observeTimeline(update, timeline) {
        let prevProgress;
        const onFrame = () => {
            const { currentTime } = timeline;
            const percentage = currentTime === null ? 0 : currentTime.value;
            const progress = percentage / 100;
            if (prevProgress !== progress) {
                update(progress);
            }
            prevProgress = progress;
        };
        frame.preUpdate(onFrame, true);
        return () => cancelFrame(onFrame);
    }

    function record() {
        const { value } = statsBuffer;
        if (value === null) {
            cancelFrame(record);
            return;
        }
        value.frameloop.rate.push(frameData.delta);
        value.animations.mainThread.push(activeAnimations.mainThread);
        value.animations.waapi.push(activeAnimations.waapi);
        value.animations.layout.push(activeAnimations.layout);
    }
    function mean(values) {
        return values.reduce((acc, value) => acc + value, 0) / values.length;
    }
    function summarise(values, calcAverage = mean) {
        if (values.length === 0) {
            return {
                min: 0,
                max: 0,
                avg: 0,
            };
        }
        return {
            min: Math.min(...values),
            max: Math.max(...values),
            avg: calcAverage(values),
        };
    }
    const msToFps = (ms) => Math.round(1000 / ms);
    function clearStatsBuffer() {
        statsBuffer.value = null;
        statsBuffer.addProjectionMetrics = null;
    }
    function reportStats() {
        const { value } = statsBuffer;
        if (!value) {
            throw new Error("Stats are not being measured");
        }
        clearStatsBuffer();
        cancelFrame(record);
        const summary = {
            frameloop: {
                setup: summarise(value.frameloop.setup),
                rate: summarise(value.frameloop.rate),
                read: summarise(value.frameloop.read),
                resolveKeyframes: summarise(value.frameloop.resolveKeyframes),
                preUpdate: summarise(value.frameloop.preUpdate),
                update: summarise(value.frameloop.update),
                preRender: summarise(value.frameloop.preRender),
                render: summarise(value.frameloop.render),
                postRender: summarise(value.frameloop.postRender),
            },
            animations: {
                mainThread: summarise(value.animations.mainThread),
                waapi: summarise(value.animations.waapi),
                layout: summarise(value.animations.layout),
            },
            layoutProjection: {
                nodes: summarise(value.layoutProjection.nodes),
                calculatedTargetDeltas: summarise(value.layoutProjection.calculatedTargetDeltas),
                calculatedProjections: summarise(value.layoutProjection.calculatedProjections),
            },
        };
        /**
         * Convert the rate to FPS
         */
        const { rate } = summary.frameloop;
        rate.min = msToFps(rate.min);
        rate.max = msToFps(rate.max);
        rate.avg = msToFps(rate.avg);
        [rate.min, rate.max] = [rate.max, rate.min];
        return summary;
    }
    function recordStats() {
        if (statsBuffer.value) {
            clearStatsBuffer();
            throw new Error("Stats are already being measured");
        }
        const newStatsBuffer = statsBuffer;
        newStatsBuffer.value = {
            frameloop: {
                setup: [],
                rate: [],
                read: [],
                resolveKeyframes: [],
                preUpdate: [],
                update: [],
                preRender: [],
                render: [],
                postRender: [],
            },
            animations: {
                mainThread: [],
                waapi: [],
                layout: [],
            },
            layoutProjection: {
                nodes: [],
                calculatedTargetDeltas: [],
                calculatedProjections: [],
            },
        };
        newStatsBuffer.addProjectionMetrics = (metrics) => {
            const { layoutProjection } = newStatsBuffer.value;
            layoutProjection.nodes.push(metrics.nodes);
            layoutProjection.calculatedTargetDeltas.push(metrics.calculatedTargetDeltas);
            layoutProjection.calculatedProjections.push(metrics.calculatedProjections);
        };
        frame.postRender(record, true);
        return reportStats;
    }

    /**
     * Checks if an element is specifically an SVGSVGElement (the root SVG element)
     * in a way that works across iframes
     */
    function isSVGSVGElement(element) {
        return isSVGElement(element) && element.tagName === "svg";
    }

    function getOriginIndex(from, total) {
        if (from === "first") {
            return 0;
        }
        else {
            const lastIndex = total - 1;
            return from === "last" ? lastIndex : lastIndex / 2;
        }
    }
    function stagger(duration = 0.1, { startDelay = 0, from = 0, ease } = {}) {
        return (i, total) => {
            const fromIndex = typeof from === "number" ? from : getOriginIndex(from, total);
            const distance = Math.abs(fromIndex - i);
            let delay = duration * distance;
            if (ease) {
                const maxDelay = total * duration;
                const easingFunction = motionUtils.easingDefinitionToFunction(ease);
                delay = easingFunction(delay / maxDelay) * maxDelay;
            }
            return startDelay + delay;
        };
    }

    function transform(...args) {
        const useImmediate = !Array.isArray(args[0]);
        const argOffset = useImmediate ? 0 : -1;
        const inputValue = args[0 + argOffset];
        const inputRange = args[1 + argOffset];
        const outputRange = args[2 + argOffset];
        const options = args[3 + argOffset];
        const interpolator = interpolate(inputRange, outputRange, options);
        return useImmediate ? interpolator(inputValue) : interpolator;
    }

    function subscribeValue(inputValues, outputValue, getLatest) {
        const update = () => outputValue.set(getLatest());
        const scheduleUpdate = () => frame.preRender(update, false, true);
        const subscriptions = inputValues.map((v) => v.on("change", scheduleUpdate));
        outputValue.on("destroy", () => {
            subscriptions.forEach((unsubscribe) => unsubscribe());
            cancelFrame(update);
        });
    }

    /**
     * Create a `MotionValue` that transforms the output of other `MotionValue`s by
     * passing their latest values through a transform function.
     *
     * Whenever a `MotionValue` referred to in the provided function is updated,
     * it will be re-evaluated.
     *
     * ```jsx
     * const x = motionValue(0)
     * const y = transformValue(() => x.get() * 2) // double x
     * ```
     *
     * @param transformer - A transform function. This function must be pure with no side-effects or conditional statements.
     * @returns `MotionValue`
     *
     * @public
     */
    function transformValue(transform) {
        const collectedValues = [];
        /**
         * Open session of collectMotionValues. Any MotionValue that calls get()
         * inside transform will be saved into this array.
         */
        collectMotionValues.current = collectedValues;
        const initialValue = transform();
        collectMotionValues.current = undefined;
        const value = motionValue(initialValue);
        subscribeValue(collectedValues, value, transform);
        return value;
    }

    /**
     * Create a `MotionValue` that maps the output of another `MotionValue` by
     * mapping it from one range of values into another.
     *
     * @remarks
     *
     * Given an input range of `[-200, -100, 100, 200]` and an output range of
     * `[0, 1, 1, 0]`, the returned `MotionValue` will:
     *
     * - When provided a value between `-200` and `-100`, will return a value between `0` and  `1`.
     * - When provided a value between `-100` and `100`, will return `1`.
     * - When provided a value between `100` and `200`, will return a value between `1` and  `0`
     *
     * The input range must be a linear series of numbers. The output range
     * can be any value type supported by Motion: numbers, colors, shadows, etc.
     *
     * Every value in the output range must be of the same type and in the same format.
     *
     * ```jsx
     * const x = motionValue(0)
     * const xRange = [-200, -100, 100, 200]
     * const opacityRange = [0, 1, 1, 0]
     * const opacity = mapValue(x, xRange, opacityRange)
     * ```
     *
     * @param inputValue - `MotionValue`
     * @param inputRange - A linear series of numbers (either all increasing or decreasing)
     * @param outputRange - A series of numbers, colors or strings. Must be the same length as `inputRange`.
     * @param options -
     *
     *  - clamp: boolean. Clamp values to within the given range. Defaults to `true`
     *  - ease: EasingFunction[]. Easing functions to use on the interpolations between each value in the input and output ranges. If provided as an array, the array must be one item shorter than the input and output ranges, as the easings apply to the transition between each.
     *
     * @returns `MotionValue`
     *
     * @public
     */
    function mapValue(inputValue, inputRange, outputRange, options) {
        const map = transform(inputRange, outputRange, options);
        return transformValue(() => map(inputValue.get()));
    }

    /**
     * Create a `MotionValue` that animates to its latest value using a spring.
     * Can either be a value or track another `MotionValue`.
     *
     * ```jsx
     * const x = motionValue(0)
     * const y = transformValue(() => x.get() * 2) // double x
     * ```
     *
     * @param transformer - A transform function. This function must be pure with no side-effects or conditional statements.
     * @returns `MotionValue`
     *
     * @public
     */
    function springValue(source, options) {
        const initialValue = isMotionValue(source) ? source.get() : source;
        const value = motionValue(initialValue);
        attachSpring(value, source, options);
        return value;
    }
    function attachSpring(value, source, options) {
        const initialValue = value.get();
        let activeAnimation = null;
        let latestValue = initialValue;
        let latestSetter;
        const unit = typeof initialValue === "string"
            ? initialValue.replace(/[\d.-]/g, "")
            : undefined;
        const stopAnimation = () => {
            if (activeAnimation) {
                activeAnimation.stop();
                activeAnimation = null;
            }
        };
        const startAnimation = () => {
            stopAnimation();
            activeAnimation = new JSAnimation({
                keyframes: [asNumber$1(value.get()), asNumber$1(latestValue)],
                velocity: value.getVelocity(),
                type: "spring",
                restDelta: 0.001,
                restSpeed: 0.01,
                ...options,
                onUpdate: latestSetter,
            });
        };
        value.attach((v, set) => {
            latestValue = v;
            latestSetter = (latest) => set(parseValue(latest, unit));
            frame.postRender(() => {
                startAnimation();
                value['events'].animationStart?.notify();
                activeAnimation?.then(() => {
                    value['events'].animationComplete?.notify();
                });
            });
        }, stopAnimation);
        if (isMotionValue(source)) {
            const removeSourceOnChange = source.on("change", (v) => value.set(parseValue(v, unit)));
            const removeValueOnDestroy = value.on("destroy", removeSourceOnChange);
            return () => {
                removeSourceOnChange();
                removeValueOnDestroy();
            };
        }
        return stopAnimation;
    }
    function parseValue(v, unit) {
        return unit ? v + unit : v;
    }
    function asNumber$1(v) {
        return typeof v === "number" ? v : parseFloat(v);
    }

    /**
     * A list of all ValueTypes
     */
    const valueTypes = [...dimensionValueTypes, color, complex];
    /**
     * Tests a value against the list of ValueTypes
     */
    const findValueType = (v) => valueTypes.find(testValueType(v));

    function chooseLayerType(valueName) {
        if (valueName === "layout")
            return "group";
        if (valueName === "enter" || valueName === "new")
            return "new";
        if (valueName === "exit" || valueName === "old")
            return "old";
        return "group";
    }

    let pendingRules = {};
    let style = null;
    const css = {
        set: (selector, values) => {
            pendingRules[selector] = values;
        },
        commit: () => {
            if (!style) {
                style = document.createElement("style");
                style.id = "motion-view";
            }
            let cssText = "";
            for (const selector in pendingRules) {
                const rule = pendingRules[selector];
                cssText += `${selector} {\n`;
                for (const [property, value] of Object.entries(rule)) {
                    cssText += `  ${property}: ${value};\n`;
                }
                cssText += "}\n";
            }
            style.textContent = cssText;
            document.head.appendChild(style);
            pendingRules = {};
        },
        remove: () => {
            if (style && style.parentElement) {
                style.parentElement.removeChild(style);
            }
        },
    };

    function getViewAnimationLayerInfo(pseudoElement) {
        const match = pseudoElement.match(/::view-transition-(old|new|group|image-pair)\((.*?)\)/);
        if (!match)
            return null;
        return { layer: match[2], type: match[1] };
    }

    function filterViewAnimations(animation) {
        const { effect } = animation;
        if (!effect)
            return false;
        return (effect.target === document.documentElement &&
            effect.pseudoElement?.startsWith("::view-transition"));
    }
    function getViewAnimations() {
        return document.getAnimations().filter(filterViewAnimations);
    }

    function hasTarget(target, targets) {
        return targets.has(target) && Object.keys(targets.get(target)).length > 0;
    }

    const definitionNames = ["layout", "enter", "exit", "new", "old"];
    function startViewAnimation(builder) {
        const { update, targets, options: defaultOptions } = builder;
        if (!document.startViewTransition) {
            return new Promise(async (resolve) => {
                await update();
                resolve(new GroupAnimation([]));
            });
        }
        // TODO: Go over existing targets and ensure they all have ids
        /**
         * If we don't have any animations defined for the root target,
         * remove it from being captured.
         */
        if (!hasTarget("root", targets)) {
            css.set(":root", {
                "view-transition-name": "none",
            });
        }
        /**
         * Set the timing curve to linear for all view transition layers.
         * This gets baked into the keyframes, which can't be changed
         * without breaking the generated animation.
         *
         * This allows us to set easing via updateTiming - which can be changed.
         */
        css.set("::view-transition-group(*), ::view-transition-old(*), ::view-transition-new(*)", { "animation-timing-function": "linear !important" });
        css.commit(); // Write
        const transition = document.startViewTransition(async () => {
            await update();
            // TODO: Go over new targets and ensure they all have ids
        });
        transition.finished.finally(() => {
            css.remove(); // Write
        });
        return new Promise((resolve) => {
            transition.ready.then(() => {
                const generatedViewAnimations = getViewAnimations();
                const animations = [];
                /**
                 * Create animations for each of our explicitly-defined subjects.
                 */
                targets.forEach((definition, target) => {
                    // TODO: If target is not "root", resolve elements
                    // and iterate over each
                    for (const key of definitionNames) {
                        if (!definition[key])
                            continue;
                        const { keyframes, options } = definition[key];
                        for (let [valueName, valueKeyframes] of Object.entries(keyframes)) {
                            if (!valueKeyframes)
                                continue;
                            const valueOptions = {
                                ...getValueTransition(defaultOptions, valueName),
                                ...getValueTransition(options, valueName),
                            };
                            const type = chooseLayerType(key);
                            /**
                             * If this is an opacity animation, and keyframes are not an array,
                             * we need to convert them into an array and set an initial value.
                             */
                            if (valueName === "opacity" &&
                                !Array.isArray(valueKeyframes)) {
                                const initialValue = type === "new" ? 0 : 1;
                                valueKeyframes = [initialValue, valueKeyframes];
                            }
                            /**
                             * Resolve stagger function if provided.
                             */
                            if (typeof valueOptions.delay === "function") {
                                valueOptions.delay = valueOptions.delay(0, 1);
                            }
                            valueOptions.duration && (valueOptions.duration = motionUtils.secondsToMilliseconds(valueOptions.duration));
                            valueOptions.delay && (valueOptions.delay = motionUtils.secondsToMilliseconds(valueOptions.delay));
                            const animation = new NativeAnimation({
                                ...valueOptions,
                                element: document.documentElement,
                                name: valueName,
                                pseudoElement: `::view-transition-${type}(${target})`,
                                keyframes: valueKeyframes,
                            });
                            animations.push(animation);
                        }
                    }
                });
                /**
                 * Handle browser generated animations
                 */
                for (const animation of generatedViewAnimations) {
                    if (animation.playState === "finished")
                        continue;
                    const { effect } = animation;
                    if (!effect || !(effect instanceof KeyframeEffect))
                        continue;
                    const { pseudoElement } = effect;
                    if (!pseudoElement)
                        continue;
                    const name = getViewAnimationLayerInfo(pseudoElement);
                    if (!name)
                        continue;
                    const targetDefinition = targets.get(name.layer);
                    if (!targetDefinition) {
                        /**
                         * If transition name is group then update the timing of the animation
                         * whereas if it's old or new then we could possibly replace it using
                         * the above method.
                         */
                        const transitionName = name.type === "group" ? "layout" : "";
                        let animationTransition = {
                            ...getValueTransition(defaultOptions, transitionName),
                        };
                        animationTransition.duration && (animationTransition.duration = motionUtils.secondsToMilliseconds(animationTransition.duration));
                        animationTransition =
                            applyGeneratorOptions(animationTransition);
                        const easing = mapEasingToNativeEasing(animationTransition.ease, animationTransition.duration);
                        effect.updateTiming({
                            delay: motionUtils.secondsToMilliseconds(animationTransition.delay ?? 0),
                            duration: animationTransition.duration,
                            easing,
                        });
                        animations.push(new NativeAnimationWrapper(animation));
                    }
                    else if (hasOpacity(targetDefinition, "enter") &&
                        hasOpacity(targetDefinition, "exit") &&
                        effect
                            .getKeyframes()
                            .some((keyframe) => keyframe.mixBlendMode)) {
                        animations.push(new NativeAnimationWrapper(animation));
                    }
                    else {
                        animation.cancel();
                    }
                }
                resolve(new GroupAnimation(animations));
            });
        });
    }
    function hasOpacity(target, key) {
        return target?.[key]?.keyframes.opacity;
    }

    let builders = [];
    let current = null;
    function next() {
        current = null;
        const [nextBuilder] = builders;
        if (nextBuilder)
            start(nextBuilder);
    }
    function start(builder) {
        motionUtils.removeItem(builders, builder);
        current = builder;
        startViewAnimation(builder).then((animation) => {
            builder.notifyReady(animation);
            animation.finished.finally(next);
        });
    }
    function processQueue() {
        /**
         * Iterate backwards over the builders array. We can ignore the
         * "wait" animations. If we have an interrupting animation in the
         * queue then we need to batch all preceeding animations into it.
         * Currently this only batches the update functions but will also
         * need to batch the targets.
         */
        for (let i = builders.length - 1; i >= 0; i--) {
            const builder = builders[i];
            const { interrupt } = builder.options;
            if (interrupt === "immediate") {
                const batchedUpdates = builders.slice(0, i + 1).map((b) => b.update);
                const remaining = builders.slice(i + 1);
                builder.update = () => {
                    batchedUpdates.forEach((update) => update());
                };
                // Put the current builder at the front, followed by any "wait" builders
                builders = [builder, ...remaining];
                break;
            }
        }
        if (!current || builders[0]?.options.interrupt === "immediate") {
            next();
        }
    }
    function addToQueue(builder) {
        builders.push(builder);
        microtask.render(processQueue);
    }

    class ViewTransitionBuilder {
        constructor(update, options = {}) {
            this.currentSubject = "root";
            this.targets = new Map();
            this.notifyReady = motionUtils.noop;
            this.readyPromise = new Promise((resolve) => {
                this.notifyReady = resolve;
            });
            this.update = update;
            this.options = {
                interrupt: "wait",
                ...options,
            };
            addToQueue(this);
        }
        get(subject) {
            this.currentSubject = subject;
            return this;
        }
        layout(keyframes, options) {
            this.updateTarget("layout", keyframes, options);
            return this;
        }
        new(keyframes, options) {
            this.updateTarget("new", keyframes, options);
            return this;
        }
        old(keyframes, options) {
            this.updateTarget("old", keyframes, options);
            return this;
        }
        enter(keyframes, options) {
            this.updateTarget("enter", keyframes, options);
            return this;
        }
        exit(keyframes, options) {
            this.updateTarget("exit", keyframes, options);
            return this;
        }
        crossfade(options) {
            this.updateTarget("enter", { opacity: 1 }, options);
            this.updateTarget("exit", { opacity: 0 }, options);
            return this;
        }
        updateTarget(target, keyframes, options = {}) {
            const { currentSubject, targets } = this;
            if (!targets.has(currentSubject)) {
                targets.set(currentSubject, {});
            }
            const targetData = targets.get(currentSubject);
            targetData[target] = { keyframes, options };
        }
        then(resolve, reject) {
            return this.readyPromise.then(resolve, reject);
        }
    }
    function animateView(update, defaultOptions = {}) {
        return new ViewTransitionBuilder(update, defaultOptions);
    }

    const createAxisDelta = () => ({
        translate: 0,
        scale: 1,
        origin: 0,
        originPoint: 0,
    });
    const createDelta = () => ({
        x: createAxisDelta(),
        y: createAxisDelta(),
    });
    const createAxis = () => ({ min: 0, max: 0 });
    const createBox = () => ({
        x: createAxis(),
        y: createAxis(),
    });

    // Does this device prefer reduced motion? Returns `null` server-side.
    const prefersReducedMotion = { current: null };
    const hasReducedMotionListener = { current: false };

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

    const visualElementStore = new WeakMap();

    function isAnimationControls(v) {
        return (v !== null &&
            typeof v === "object" &&
            typeof v.start === "function");
    }

    /**
     * Decides if the supplied variable is variant label
     */
    function isVariantLabel(v) {
        return typeof v === "string" || Array.isArray(v);
    }

    const variantPriorityOrder = [
        "animate",
        "whileInView",
        "whileFocus",
        "whileHover",
        "whileTap",
        "whileDrag",
        "exit",
    ];
    const variantProps = ["initial", ...variantPriorityOrder];

    function isControllingVariants(props) {
        return (isAnimationControls(props.animate) ||
            variantProps.some((name) => isVariantLabel(props[name])));
    }
    function isVariantNode(props) {
        return Boolean(isControllingVariants(props) || props.variants);
    }

    /**
     * Updates motion values from props changes.
     * Uses `any` type for element to avoid circular dependencies with VisualElement.
     */
    function updateMotionValuesFromProps(element, next, prev) {
        for (const key in next) {
            const nextValue = next[key];
            const prevValue = prev[key];
            if (isMotionValue(nextValue)) {
                /**
                 * If this is a motion value found in props or style, we want to add it
                 * to our visual element's motion value map.
                 */
                element.addValue(key, nextValue);
            }
            else if (isMotionValue(prevValue)) {
                /**
                 * If we're swapping from a motion value to a static value,
                 * create a new motion value from that
                 */
                element.addValue(key, motionValue(nextValue, { owner: element }));
            }
            else if (prevValue !== nextValue) {
                /**
                 * If this is a flat value that has changed, update the motion value
                 * or create one if it doesn't exist. We only want to do this if we're
                 * not handling the value with our animation state.
                 */
                if (element.hasValue(key)) {
                    const existingValue = element.getValue(key);
                    if (existingValue.liveStyle === true) {
                        existingValue.jump(nextValue);
                    }
                    else if (!existingValue.hasAnimated) {
                        existingValue.set(nextValue);
                    }
                }
                else {
                    const latestValue = element.getStaticValue(key);
                    element.addValue(key, motionValue(latestValue !== undefined ? latestValue : nextValue, { owner: element }));
                }
            }
        }
        // Handle removed values
        for (const key in prev) {
            if (next[key] === undefined)
                element.removeValue(key);
        }
        return next;
    }

    const propEventHandlers = [
        "AnimationStart",
        "AnimationComplete",
        "Update",
        "BeforeLayoutMeasure",
        "LayoutMeasure",
        "LayoutAnimationStart",
        "LayoutAnimationComplete",
    ];
    /**
     * Static feature definitions - can be injected by framework layer
     */
    let featureDefinitions = {};
    /**
     * Set feature definitions for all VisualElements.
     * This should be called by the framework layer (e.g., framer-motion) during initialization.
     */
    function setFeatureDefinitions(definitions) {
        featureDefinitions = definitions;
    }
    /**
     * Get the current feature definitions
     */
    function getFeatureDefinitions() {
        return featureDefinitions;
    }
    /**
     * A VisualElement is an imperative abstraction around UI elements such as
     * HTMLElement, SVGElement, Three.Object3D etc.
     */
    class VisualElement {
        /**
         * This method takes React props and returns found MotionValues. For example, HTML
         * MotionValues will be found within the style prop, whereas for Three.js within attribute arrays.
         *
         * This isn't an abstract method as it needs calling in the constructor, but it is
         * intended to be one.
         */
        scrapeMotionValuesFromProps(_props, _prevProps, _visualElement) {
            return {};
        }
        constructor({ parent, props, presenceContext, reducedMotionConfig, blockInitialAnimation, visualState, }, options = {}) {
            /**
             * A reference to the current underlying Instance, e.g. a HTMLElement
             * or Three.Mesh etc.
             */
            this.current = null;
            /**
             * A set containing references to this VisualElement's children.
             */
            this.children = new Set();
            /**
             * Determine what role this visual element should take in the variant tree.
             */
            this.isVariantNode = false;
            this.isControllingVariants = false;
            /**
             * Decides whether this VisualElement should animate in reduced motion
             * mode.
             *
             * TODO: This is currently set on every individual VisualElement but feels
             * like it could be set globally.
             */
            this.shouldReduceMotion = null;
            /**
             * A map of all motion values attached to this visual element. Motion
             * values are source of truth for any given animated value. A motion
             * value might be provided externally by the component via props.
             */
            this.values = new Map();
            this.KeyframeResolver = KeyframeResolver;
            /**
             * Cleanup functions for active features (hover/tap/exit etc)
             */
            this.features = {};
            /**
             * A map of every subscription that binds the provided or generated
             * motion values onChange listeners to this visual element.
             */
            this.valueSubscriptions = new Map();
            /**
             * A reference to the previously-provided motion values as returned
             * from scrapeMotionValuesFromProps. We use the keys in here to determine
             * if any motion values need to be removed after props are updated.
             */
            this.prevMotionValues = {};
            /**
             * An object containing a SubscriptionManager for each active event.
             */
            this.events = {};
            /**
             * An object containing an unsubscribe function for each prop event subscription.
             * For example, every "Update" event can have multiple subscribers via
             * VisualElement.on(), but only one of those can be defined via the onUpdate prop.
             */
            this.propEventSubscriptions = {};
            this.notifyUpdate = () => this.notify("Update", this.latestValues);
            this.render = () => {
                if (!this.current)
                    return;
                this.triggerBuild();
                this.renderInstance(this.current, this.renderState, this.props.style, this.projection);
            };
            this.renderScheduledAt = 0.0;
            this.scheduleRender = () => {
                const now = time.now();
                if (this.renderScheduledAt < now) {
                    this.renderScheduledAt = now;
                    frame.render(this.render, false, true);
                }
            };
            const { latestValues, renderState } = visualState;
            this.latestValues = latestValues;
            this.baseTarget = { ...latestValues };
            this.initialValues = props.initial ? { ...latestValues } : {};
            this.renderState = renderState;
            this.parent = parent;
            this.props = props;
            this.presenceContext = presenceContext;
            this.depth = parent ? parent.depth + 1 : 0;
            this.reducedMotionConfig = reducedMotionConfig;
            this.options = options;
            this.blockInitialAnimation = Boolean(blockInitialAnimation);
            this.isControllingVariants = isControllingVariants(props);
            this.isVariantNode = isVariantNode(props);
            if (this.isVariantNode) {
                this.variantChildren = new Set();
            }
            this.manuallyAnimateOnMount = Boolean(parent && parent.current);
            /**
             * Any motion values that are provided to the element when created
             * aren't yet bound to the element, as this would technically be impure.
             * However, we iterate through the motion values and set them to the
             * initial values for this component.
             *
             * TODO: This is impure and we should look at changing this to run on mount.
             * Doing so will break some tests but this isn't necessarily a breaking change,
             * more a reflection of the test.
             */
            const { willChange, ...initialMotionValues } = this.scrapeMotionValuesFromProps(props, {}, this);
            for (const key in initialMotionValues) {
                const value = initialMotionValues[key];
                if (latestValues[key] !== undefined && isMotionValue(value)) {
                    value.set(latestValues[key]);
                }
            }
        }
        mount(instance) {
            this.current = instance;
            visualElementStore.set(instance, this);
            if (this.projection && !this.projection.instance) {
                this.projection.mount(instance);
            }
            if (this.parent && this.isVariantNode && !this.isControllingVariants) {
                this.removeFromVariantTree = this.parent.addVariantChild(this);
            }
            this.values.forEach((value, key) => this.bindToMotionValue(key, value));
            /**
             * Determine reduced motion preference. Only initialize the matchMedia
             * listener if we actually need the dynamic value (i.e., when config
             * is neither "never" nor "always").
             */
            if (this.reducedMotionConfig === "never") {
                this.shouldReduceMotion = false;
            }
            else if (this.reducedMotionConfig === "always") {
                this.shouldReduceMotion = true;
            }
            else {
                if (!hasReducedMotionListener.current) {
                    initPrefersReducedMotion();
                }
                this.shouldReduceMotion = prefersReducedMotion.current;
            }
            {
                motionUtils.warnOnce(this.shouldReduceMotion !== true, "You have Reduced Motion enabled on your device. Animations may not appear as expected.", "reduced-motion-disabled");
            }
            this.parent?.addChild(this);
            this.update(this.props, this.presenceContext);
        }
        unmount() {
            this.projection && this.projection.unmount();
            cancelFrame(this.notifyUpdate);
            cancelFrame(this.render);
            this.valueSubscriptions.forEach((remove) => remove());
            this.valueSubscriptions.clear();
            this.removeFromVariantTree && this.removeFromVariantTree();
            this.parent?.removeChild(this);
            for (const key in this.events) {
                this.events[key].clear();
            }
            for (const key in this.features) {
                const feature = this.features[key];
                if (feature) {
                    feature.unmount();
                    feature.isMounted = false;
                }
            }
            this.current = null;
        }
        addChild(child) {
            this.children.add(child);
            this.enteringChildren ?? (this.enteringChildren = new Set());
            this.enteringChildren.add(child);
        }
        removeChild(child) {
            this.children.delete(child);
            this.enteringChildren && this.enteringChildren.delete(child);
        }
        bindToMotionValue(key, value) {
            if (this.valueSubscriptions.has(key)) {
                this.valueSubscriptions.get(key)();
            }
            const valueIsTransform = transformProps.has(key);
            if (valueIsTransform && this.onBindTransform) {
                this.onBindTransform();
            }
            const removeOnChange = value.on("change", (latestValue) => {
                this.latestValues[key] = latestValue;
                this.props.onUpdate && frame.preRender(this.notifyUpdate);
                if (valueIsTransform && this.projection) {
                    this.projection.isTransformDirty = true;
                }
                this.scheduleRender();
            });
            let removeSyncCheck;
            if (typeof window !== "undefined" && window.MotionCheckAppearSync) {
                removeSyncCheck = window.MotionCheckAppearSync(this, key, value);
            }
            this.valueSubscriptions.set(key, () => {
                removeOnChange();
                if (removeSyncCheck)
                    removeSyncCheck();
                if (value.owner)
                    value.stop();
            });
        }
        sortNodePosition(other) {
            /**
             * If these nodes aren't even of the same type we can't compare their depth.
             */
            if (!this.current ||
                !this.sortInstanceNodePosition ||
                this.type !== other.type) {
                return 0;
            }
            return this.sortInstanceNodePosition(this.current, other.current);
        }
        updateFeatures() {
            let key = "animation";
            for (key in featureDefinitions) {
                const featureDefinition = featureDefinitions[key];
                if (!featureDefinition)
                    continue;
                const { isEnabled, Feature: FeatureConstructor } = featureDefinition;
                /**
                 * If this feature is enabled but not active, make a new instance.
                 */
                if (!this.features[key] &&
                    FeatureConstructor &&
                    isEnabled(this.props)) {
                    this.features[key] = new FeatureConstructor(this);
                }
                /**
                 * If we have a feature, mount or update it.
                 */
                if (this.features[key]) {
                    const feature = this.features[key];
                    if (feature.isMounted) {
                        feature.update();
                    }
                    else {
                        feature.mount();
                        feature.isMounted = true;
                    }
                }
            }
        }
        triggerBuild() {
            this.build(this.renderState, this.latestValues, this.props);
        }
        /**
         * Measure the current viewport box with or without transforms.
         * Only measures axis-aligned boxes, rotate and skew must be manually
         * removed with a re-render to work.
         */
        measureViewportBox() {
            return this.current
                ? this.measureInstanceViewportBox(this.current, this.props)
                : createBox();
        }
        getStaticValue(key) {
            return this.latestValues[key];
        }
        setStaticValue(key, value) {
            this.latestValues[key] = value;
        }
        /**
         * Update the provided props. Ensure any newly-added motion values are
         * added to our map, old ones removed, and listeners updated.
         */
        update(props, presenceContext) {
            if (props.transformTemplate || this.props.transformTemplate) {
                this.scheduleRender();
            }
            this.prevProps = this.props;
            this.props = props;
            this.prevPresenceContext = this.presenceContext;
            this.presenceContext = presenceContext;
            /**
             * Update prop event handlers ie onAnimationStart, onAnimationComplete
             */
            for (let i = 0; i < propEventHandlers.length; i++) {
                const key = propEventHandlers[i];
                if (this.propEventSubscriptions[key]) {
                    this.propEventSubscriptions[key]();
                    delete this.propEventSubscriptions[key];
                }
                const listenerName = ("on" + key);
                const listener = props[listenerName];
                if (listener) {
                    this.propEventSubscriptions[key] = this.on(key, listener);
                }
            }
            this.prevMotionValues = updateMotionValuesFromProps(this, this.scrapeMotionValuesFromProps(props, this.prevProps || {}, this), this.prevMotionValues);
            if (this.handleChildMotionValue) {
                this.handleChildMotionValue();
            }
        }
        getProps() {
            return this.props;
        }
        /**
         * Returns the variant definition with a given name.
         */
        getVariant(name) {
            return this.props.variants ? this.props.variants[name] : undefined;
        }
        /**
         * Returns the defined default transition on this component.
         */
        getDefaultTransition() {
            return this.props.transition;
        }
        getTransformPagePoint() {
            return this.props.transformPagePoint;
        }
        getClosestVariantNode() {
            return this.isVariantNode
                ? this
                : this.parent
                    ? this.parent.getClosestVariantNode()
                    : undefined;
        }
        /**
         * Add a child visual element to our set of children.
         */
        addVariantChild(child) {
            const closestVariantNode = this.getClosestVariantNode();
            if (closestVariantNode) {
                closestVariantNode.variantChildren &&
                    closestVariantNode.variantChildren.add(child);
                return () => closestVariantNode.variantChildren.delete(child);
            }
        }
        /**
         * Add a motion value and bind it to this visual element.
         */
        addValue(key, value) {
            // Remove existing value if it exists
            const existingValue = this.values.get(key);
            if (value !== existingValue) {
                if (existingValue)
                    this.removeValue(key);
                this.bindToMotionValue(key, value);
                this.values.set(key, value);
                this.latestValues[key] = value.get();
            }
        }
        /**
         * Remove a motion value and unbind any active subscriptions.
         */
        removeValue(key) {
            this.values.delete(key);
            const unsubscribe = this.valueSubscriptions.get(key);
            if (unsubscribe) {
                unsubscribe();
                this.valueSubscriptions.delete(key);
            }
            delete this.latestValues[key];
            this.removeValueFromRenderState(key, this.renderState);
        }
        /**
         * Check whether we have a motion value for this key
         */
        hasValue(key) {
            return this.values.has(key);
        }
        getValue(key, defaultValue) {
            if (this.props.values && this.props.values[key]) {
                return this.props.values[key];
            }
            let value = this.values.get(key);
            if (value === undefined && defaultValue !== undefined) {
                value = motionValue(defaultValue === null ? undefined : defaultValue, { owner: this });
                this.addValue(key, value);
            }
            return value;
        }
        /**
         * If we're trying to animate to a previously unencountered value,
         * we need to check for it in our state and as a last resort read it
         * directly from the instance (which might have performance implications).
         */
        readValue(key, target) {
            let value = this.latestValues[key] !== undefined || !this.current
                ? this.latestValues[key]
                : this.getBaseTargetFromProps(this.props, key) ??
                    this.readValueFromInstance(this.current, key, this.options);
            if (value !== undefined && value !== null) {
                if (typeof value === "string" &&
                    (motionUtils.isNumericalString(value) || motionUtils.isZeroValueString(value))) {
                    // If this is a number read as a string, ie "0" or "200", convert it to a number
                    value = parseFloat(value);
                }
                else if (!findValueType(value) && complex.test(target)) {
                    value = getAnimatableNone(key, target);
                }
                this.setBaseTarget(key, isMotionValue(value) ? value.get() : value);
            }
            return isMotionValue(value) ? value.get() : value;
        }
        /**
         * Set the base target to later animate back to. This is currently
         * only hydrated on creation and when we first read a value.
         */
        setBaseTarget(key, value) {
            this.baseTarget[key] = value;
        }
        /**
         * Find the base target for a value thats been removed from all animation
         * props.
         */
        getBaseTarget(key) {
            const { initial } = this.props;
            let valueFromInitial;
            if (typeof initial === "string" || typeof initial === "object") {
                const variant = resolveVariantFromProps(this.props, initial, this.presenceContext?.custom);
                if (variant) {
                    valueFromInitial = variant[key];
                }
            }
            /**
             * If this value still exists in the current initial variant, read that.
             */
            if (initial && valueFromInitial !== undefined) {
                return valueFromInitial;
            }
            /**
             * Alternatively, if this VisualElement config has defined a getBaseTarget
             * so we can read the value from an alternative source, try that.
             */
            const target = this.getBaseTargetFromProps(this.props, key);
            if (target !== undefined && !isMotionValue(target))
                return target;
            /**
             * If the value was initially defined on initial, but it doesn't any more,
             * return undefined. Otherwise return the value as initially read from the DOM.
             */
            return this.initialValues[key] !== undefined &&
                valueFromInitial === undefined
                ? undefined
                : this.baseTarget[key];
        }
        on(eventName, callback) {
            if (!this.events[eventName]) {
                this.events[eventName] = new motionUtils.SubscriptionManager();
            }
            return this.events[eventName].add(callback);
        }
        notify(eventName, ...args) {
            if (this.events[eventName]) {
                this.events[eventName].notify(...args);
            }
        }
        scheduleRenderMicrotask() {
            microtask.render(this.render);
        }
    }

    class DOMVisualElement extends VisualElement {
        constructor() {
            super(...arguments);
            this.KeyframeResolver = DOMKeyframesResolver;
        }
        sortInstanceNodePosition(a, b) {
            /**
             * compareDocumentPosition returns a bitmask, by using the bitwise &
             * we're returning true if 2 in that bitmask is set to true. 2 is set
             * to true if b preceeds a.
             */
            return a.compareDocumentPosition(b) & 2 ? 1 : -1;
        }
        getBaseTargetFromProps(props, key) {
            const style = props.style;
            return style ? style[key] : undefined;
        }
        removeValueFromRenderState(key, { vars, style }) {
            delete vars[key];
            delete style[key];
        }
        handleChildMotionValue() {
            if (this.childSubscription) {
                this.childSubscription();
                delete this.childSubscription;
            }
            const { children } = this.props;
            if (isMotionValue(children)) {
                this.childSubscription = children.on("change", (latest) => {
                    if (this.current) {
                        this.current.textContent = `${latest}`;
                    }
                });
            }
        }
    }

    /**
     * Feature base class for extending VisualElement functionality.
     * Features are plugins that can be mounted/unmounted to add behavior
     * like gestures, animations, or layout tracking.
     */
    class Feature {
        constructor(node) {
            this.isMounted = false;
            this.node = node;
        }
        update() { }
    }

    /**
     * Bounding boxes tend to be defined as top, left, right, bottom. For various operations
     * it's easier to consider each axis individually. This function returns a bounding box
     * as a map of single-axis min/max values.
     */
    function convertBoundingBoxToBox({ top, left, right, bottom, }) {
        return {
            x: { min: left, max: right },
            y: { min: top, max: bottom },
        };
    }
    function convertBoxToBoundingBox({ x, y }) {
        return { top: y.min, right: x.max, bottom: y.max, left: x.min };
    }
    /**
     * Applies a TransformPoint function to a bounding box. TransformPoint is usually a function
     * provided by Framer to allow measured points to be corrected for device scaling. This is used
     * when measuring DOM elements and DOM event points.
     */
    function transformBoxPoints(point, transformPoint) {
        if (!transformPoint)
            return point;
        const topLeft = transformPoint({ x: point.left, y: point.top });
        const bottomRight = transformPoint({ x: point.right, y: point.bottom });
        return {
            top: topLeft.y,
            left: topLeft.x,
            bottom: bottomRight.y,
            right: bottomRight.x,
        };
    }

    function isIdentityScale(scale) {
        return scale === undefined || scale === 1;
    }
    function hasScale({ scale, scaleX, scaleY }) {
        return (!isIdentityScale(scale) ||
            !isIdentityScale(scaleX) ||
            !isIdentityScale(scaleY));
    }
    function hasTransform(values) {
        return (hasScale(values) ||
            has2DTranslate(values) ||
            values.z ||
            values.rotate ||
            values.rotateX ||
            values.rotateY ||
            values.skewX ||
            values.skewY);
    }
    function has2DTranslate(values) {
        return is2DTranslate(values.x) || is2DTranslate(values.y);
    }
    function is2DTranslate(value) {
        return value && value !== "0%";
    }

    /**
     * Scales a point based on a factor and an originPoint
     */
    function scalePoint(point, scale, originPoint) {
        const distanceFromOrigin = point - originPoint;
        const scaled = scale * distanceFromOrigin;
        return originPoint + scaled;
    }
    /**
     * Applies a translate/scale delta to a point
     */
    function applyPointDelta(point, translate, scale, originPoint, boxScale) {
        if (boxScale !== undefined) {
            point = scalePoint(point, boxScale, originPoint);
        }
        return scalePoint(point, scale, originPoint) + translate;
    }
    /**
     * Applies a translate/scale delta to an axis
     */
    function applyAxisDelta(axis, translate = 0, scale = 1, originPoint, boxScale) {
        axis.min = applyPointDelta(axis.min, translate, scale, originPoint, boxScale);
        axis.max = applyPointDelta(axis.max, translate, scale, originPoint, boxScale);
    }
    /**
     * Applies a translate/scale delta to a box
     */
    function applyBoxDelta(box, { x, y }) {
        applyAxisDelta(box.x, x.translate, x.scale, x.originPoint);
        applyAxisDelta(box.y, y.translate, y.scale, y.originPoint);
    }
    const TREE_SCALE_SNAP_MIN = 0.999999999999;
    const TREE_SCALE_SNAP_MAX = 1.0000000000001;
    /**
     * Apply a tree of deltas to a box. We do this to calculate the effect of all the transforms
     * in a tree upon our box before then calculating how to project it into our desired viewport-relative box
     *
     * This is the final nested loop within updateLayoutDelta for future refactoring
     */
    function applyTreeDeltas(box, treeScale, treePath, isSharedTransition = false) {
        const treeLength = treePath.length;
        if (!treeLength)
            return;
        // Reset the treeScale
        treeScale.x = treeScale.y = 1;
        let node;
        let delta;
        for (let i = 0; i < treeLength; i++) {
            node = treePath[i];
            delta = node.projectionDelta;
            /**
             * TODO: Prefer to remove this, but currently we have motion components with
             * display: contents in Framer.
             */
            const { visualElement } = node.options;
            if (visualElement &&
                visualElement.props.style &&
                visualElement.props.style.display === "contents") {
                continue;
            }
            if (isSharedTransition &&
                node.options.layoutScroll &&
                node.scroll &&
                node !== node.root) {
                transformBox(box, {
                    x: -node.scroll.offset.x,
                    y: -node.scroll.offset.y,
                });
            }
            if (delta) {
                // Incoporate each ancestor's scale into a cumulative treeScale for this component
                treeScale.x *= delta.x.scale;
                treeScale.y *= delta.y.scale;
                // Apply each ancestor's calculated delta into this component's recorded layout box
                applyBoxDelta(box, delta);
            }
            if (isSharedTransition && hasTransform(node.latestValues)) {
                transformBox(box, node.latestValues);
            }
        }
        /**
         * Snap tree scale back to 1 if it's within a non-perceivable threshold.
         * This will help reduce useless scales getting rendered.
         */
        if (treeScale.x < TREE_SCALE_SNAP_MAX &&
            treeScale.x > TREE_SCALE_SNAP_MIN) {
            treeScale.x = 1.0;
        }
        if (treeScale.y < TREE_SCALE_SNAP_MAX &&
            treeScale.y > TREE_SCALE_SNAP_MIN) {
            treeScale.y = 1.0;
        }
    }
    function translateAxis(axis, distance) {
        axis.min = axis.min + distance;
        axis.max = axis.max + distance;
    }
    /**
     * Apply a transform to an axis from the latest resolved motion values.
     * This function basically acts as a bridge between a flat motion value map
     * and applyAxisDelta
     */
    function transformAxis(axis, axisTranslate, axisScale, boxScale, axisOrigin = 0.5) {
        const originPoint = mixNumber$1(axis.min, axis.max, axisOrigin);
        // Apply the axis delta to the final axis
        applyAxisDelta(axis, axisTranslate, axisScale, originPoint, boxScale);
    }
    /**
     * Apply a transform to a box from the latest resolved motion values.
     */
    function transformBox(box, transform) {
        transformAxis(box.x, transform.x, transform.scaleX, transform.scale, transform.originX);
        transformAxis(box.y, transform.y, transform.scaleY, transform.scale, transform.originY);
    }

    function measureViewportBox(instance, transformPoint) {
        return convertBoundingBoxToBox(transformBoxPoints(instance.getBoundingClientRect(), transformPoint));
    }
    function measurePageBox(element, rootProjectionNode, transformPagePoint) {
        const viewportBox = measureViewportBox(element, transformPagePoint);
        const { scroll } = rootProjectionNode;
        if (scroll) {
            translateAxis(viewportBox.x, scroll.offset.x);
            translateAxis(viewportBox.y, scroll.offset.y);
        }
        return viewportBox;
    }

    const translateAlias = {
        x: "translateX",
        y: "translateY",
        z: "translateZ",
        transformPerspective: "perspective",
    };
    const numTransforms = transformPropOrder.length;
    /**
     * Build a CSS transform style from individual x/y/scale etc properties.
     *
     * This outputs with a default order of transforms/scales/rotations, this can be customised by
     * providing a transformTemplate function.
     */
    function buildTransform(latestValues, transform, transformTemplate) {
        // The transform string we're going to build into.
        let transformString = "";
        let transformIsDefault = true;
        /**
         * Loop over all possible transforms in order, adding the ones that
         * are present to the transform string.
         */
        for (let i = 0; i < numTransforms; i++) {
            const key = transformPropOrder[i];
            const value = latestValues[key];
            if (value === undefined)
                continue;
            let valueIsDefault = true;
            if (typeof value === "number") {
                valueIsDefault = value === (key.startsWith("scale") ? 1 : 0);
            }
            else {
                valueIsDefault = parseFloat(value) === 0;
            }
            if (!valueIsDefault || transformTemplate) {
                const valueAsType = getValueAsType(value, numberValueTypes[key]);
                if (!valueIsDefault) {
                    transformIsDefault = false;
                    const transformName = translateAlias[key] || key;
                    transformString += `${transformName}(${valueAsType}) `;
                }
                if (transformTemplate) {
                    transform[key] = valueAsType;
                }
            }
        }
        transformString = transformString.trim();
        // If we have a custom `transform` template, pass our transform values and
        // generated transformString to that before returning
        if (transformTemplate) {
            transformString = transformTemplate(transform, transformIsDefault ? "" : transformString);
        }
        else if (transformIsDefault) {
            transformString = "none";
        }
        return transformString;
    }

    function buildHTMLStyles(state, latestValues, transformTemplate) {
        const { style, vars, transformOrigin } = state;
        // Track whether we encounter any transform or transformOrigin values.
        let hasTransform = false;
        let hasTransformOrigin = false;
        /**
         * Loop over all our latest animated values and decide whether to handle them
         * as a style or CSS variable.
         *
         * Transforms and transform origins are kept separately for further processing.
         */
        for (const key in latestValues) {
            const value = latestValues[key];
            if (transformProps.has(key)) {
                // If this is a transform, flag to enable further transform processing
                hasTransform = true;
                continue;
            }
            else if (isCSSVariableName(key)) {
                vars[key] = value;
                continue;
            }
            else {
                // Convert the value to its default value type, ie 0 -> "0px"
                const valueAsType = getValueAsType(value, numberValueTypes[key]);
                if (key.startsWith("origin")) {
                    // If this is a transform origin, flag and enable further transform-origin processing
                    hasTransformOrigin = true;
                    transformOrigin[key] =
                        valueAsType;
                }
                else {
                    style[key] = valueAsType;
                }
            }
        }
        if (!latestValues.transform) {
            if (hasTransform || transformTemplate) {
                style.transform = buildTransform(latestValues, state.transform, transformTemplate);
            }
            else if (style.transform) {
                /**
                 * If we have previously created a transform but currently don't have any,
                 * reset transform style to none.
                 */
                style.transform = "none";
            }
        }
        /**
         * Build a transformOrigin style. Uses the same defaults as the browser for
         * undefined origins.
         */
        if (hasTransformOrigin) {
            const { originX = "50%", originY = "50%", originZ = 0, } = transformOrigin;
            style.transformOrigin = `${originX} ${originY} ${originZ}`;
        }
    }

    function renderHTML(element, { style, vars }, styleProp, projection) {
        const elementStyle = element.style;
        let key;
        for (key in style) {
            // CSSStyleDeclaration has [index: number]: string; in the types, so we use that as key type.
            elementStyle[key] = style[key];
        }
        // Write projection styles directly to element style
        projection?.applyProjectionStyles(elementStyle, styleProp);
        for (key in vars) {
            // Loop over any CSS variables and assign those.
            // They can only be assigned using `setProperty`.
            elementStyle.setProperty(key, vars[key]);
        }
    }

    function pixelsToPercent(pixels, axis) {
        if (axis.max === axis.min)
            return 0;
        return (pixels / (axis.max - axis.min)) * 100;
    }
    /**
     * We always correct borderRadius as a percentage rather than pixels to reduce paints.
     * For example, if you are projecting a box that is 100px wide with a 10px borderRadius
     * into a box that is 200px wide with a 20px borderRadius, that is actually a 10%
     * borderRadius in both states. If we animate between the two in pixels that will trigger
     * a paint each time. If we animate between the two in percentage we'll avoid a paint.
     */
    const correctBorderRadius = {
        correct: (latest, node) => {
            if (!node.target)
                return latest;
            /**
             * If latest is a string, if it's a percentage we can return immediately as it's
             * going to be stretched appropriately. Otherwise, if it's a pixel, convert it to a number.
             */
            if (typeof latest === "string") {
                if (px.test(latest)) {
                    latest = parseFloat(latest);
                }
                else {
                    return latest;
                }
            }
            /**
             * If latest is a number, it's a pixel value. We use the current viewportBox to calculate that
             * pixel value as a percentage of each axis
             */
            const x = pixelsToPercent(latest, node.target.x);
            const y = pixelsToPercent(latest, node.target.y);
            return `${x}% ${y}%`;
        },
    };

    const correctBoxShadow = {
        correct: (latest, { treeScale, projectionDelta }) => {
            const original = latest;
            const shadow = complex.parse(latest);
            // TODO: Doesn't support multiple shadows
            if (shadow.length > 5)
                return original;
            const template = complex.createTransformer(latest);
            const offset = typeof shadow[0] !== "number" ? 1 : 0;
            // Calculate the overall context scale
            const xScale = projectionDelta.x.scale * treeScale.x;
            const yScale = projectionDelta.y.scale * treeScale.y;
            shadow[0 + offset] /= xScale;
            shadow[1 + offset] /= yScale;
            /**
             * Ideally we'd correct x and y scales individually, but because blur and
             * spread apply to both we have to take a scale average and apply that instead.
             * We could potentially improve the outcome of this by incorporating the ratio between
             * the two scales.
             */
            const averageScale = mixNumber$1(xScale, yScale, 0.5);
            // Blur
            if (typeof shadow[2 + offset] === "number")
                shadow[2 + offset] /= averageScale;
            // Spread
            if (typeof shadow[3 + offset] === "number")
                shadow[3 + offset] /= averageScale;
            return template(shadow);
        },
    };

    const scaleCorrectors = {
        borderRadius: {
            ...correctBorderRadius,
            applyTo: [
                "borderTopLeftRadius",
                "borderTopRightRadius",
                "borderBottomLeftRadius",
                "borderBottomRightRadius",
            ],
        },
        borderTopLeftRadius: correctBorderRadius,
        borderTopRightRadius: correctBorderRadius,
        borderBottomLeftRadius: correctBorderRadius,
        borderBottomRightRadius: correctBorderRadius,
        boxShadow: correctBoxShadow,
    };
    function addScaleCorrector(correctors) {
        for (const key in correctors) {
            scaleCorrectors[key] = correctors[key];
            if (isCSSVariableName(key)) {
                scaleCorrectors[key].isCSSVariable = true;
            }
        }
    }

    function isForcedMotionValue(key, { layout, layoutId }) {
        return (transformProps.has(key) ||
            key.startsWith("origin") ||
            ((layout || layoutId !== undefined) &&
                (!!scaleCorrectors[key] || key === "opacity")));
    }

    function scrapeMotionValuesFromProps$1(props, prevProps, visualElement) {
        const style = props.style;
        const prevStyle = prevProps?.style;
        const newValues = {};
        if (!style)
            return newValues;
        for (const key in style) {
            if (isMotionValue(style[key]) ||
                (prevStyle && isMotionValue(prevStyle[key])) ||
                isForcedMotionValue(key, props) ||
                visualElement?.getValue(key)?.liveStyle !== undefined) {
                newValues[key] = style[key];
            }
        }
        return newValues;
    }

    function getComputedStyle$1(element) {
        return window.getComputedStyle(element);
    }
    class HTMLVisualElement extends DOMVisualElement {
        constructor() {
            super(...arguments);
            this.type = "html";
            this.renderInstance = renderHTML;
        }
        readValueFromInstance(instance, key) {
            if (transformProps.has(key)) {
                return this.projection?.isProjecting
                    ? defaultTransformValue(key)
                    : readTransformValue(instance, key);
            }
            else {
                const computedStyle = getComputedStyle$1(instance);
                const value = (isCSSVariableName(key)
                    ? computedStyle.getPropertyValue(key)
                    : computedStyle[key]) || 0;
                return typeof value === "string" ? value.trim() : value;
            }
        }
        measureInstanceViewportBox(instance, { transformPagePoint }) {
            return measureViewportBox(instance, transformPagePoint);
        }
        build(renderState, latestValues, props) {
            buildHTMLStyles(renderState, latestValues, props.transformTemplate);
        }
        scrapeMotionValuesFromProps(props, prevProps, visualElement) {
            return scrapeMotionValuesFromProps$1(props, prevProps, visualElement);
        }
    }

    function isObjectKey(key, object) {
        return key in object;
    }
    class ObjectVisualElement extends VisualElement {
        constructor() {
            super(...arguments);
            this.type = "object";
        }
        readValueFromInstance(instance, key) {
            if (isObjectKey(key, instance)) {
                const value = instance[key];
                if (typeof value === "string" || typeof value === "number") {
                    return value;
                }
            }
            return undefined;
        }
        getBaseTargetFromProps() {
            return undefined;
        }
        removeValueFromRenderState(key, renderState) {
            delete renderState.output[key];
        }
        measureInstanceViewportBox() {
            return createBox();
        }
        build(renderState, latestValues) {
            Object.assign(renderState.output, latestValues);
        }
        renderInstance(instance, { output }) {
            Object.assign(instance, output);
        }
        sortInstanceNodePosition() {
            return 0;
        }
    }

    const dashKeys = {
        offset: "stroke-dashoffset",
        array: "stroke-dasharray",
    };
    const camelKeys = {
        offset: "strokeDashoffset",
        array: "strokeDasharray",
    };
    /**
     * Build SVG path properties. Uses the path's measured length to convert
     * our custom pathLength, pathSpacing and pathOffset into stroke-dashoffset
     * and stroke-dasharray attributes.
     *
     * This function is mutative to reduce per-frame GC.
     *
     * Note: We use unitless values for stroke-dasharray and stroke-dashoffset
     * because Safari incorrectly scales px values when the page is zoomed.
     */
    function buildSVGPath(attrs, length, spacing = 1, offset = 0, useDashCase = true) {
        // Normalise path length by setting SVG attribute pathLength to 1
        attrs.pathLength = 1;
        // We use dash case when setting attributes directly to the DOM node and camel case
        // when defining props on a React component.
        const keys = useDashCase ? dashKeys : camelKeys;
        // Build the dash offset (unitless to avoid Safari zoom bug)
        attrs[keys.offset] = `${-offset}`;
        // Build the dash array (unitless to avoid Safari zoom bug)
        attrs[keys.array] = `${length} ${spacing}`;
    }

    /**
     * CSS Motion Path properties that should remain as CSS styles on SVG elements.
     */
    const cssMotionPathProperties = [
        "offsetDistance",
        "offsetPath",
        "offsetRotate",
        "offsetAnchor",
    ];
    /**
     * Build SVG visual attributes, like cx and style.transform
     */
    function buildSVGAttrs(state, { attrX, attrY, attrScale, pathLength, pathSpacing = 1, pathOffset = 0, 
    // This is object creation, which we try to avoid per-frame.
    ...latest }, isSVGTag, transformTemplate, styleProp) {
        buildHTMLStyles(state, latest, transformTemplate);
        /**
         * For svg tags we just want to make sure viewBox is animatable and treat all the styles
         * as normal HTML tags.
         */
        if (isSVGTag) {
            if (state.style.viewBox) {
                state.attrs.viewBox = state.style.viewBox;
            }
            return;
        }
        state.attrs = state.style;
        state.style = {};
        const { attrs, style } = state;
        /**
         * However, we apply transforms as CSS transforms.
         * So if we detect a transform, transformOrigin we take it from attrs and copy it into style.
         */
        if (attrs.transform) {
            style.transform = attrs.transform;
            delete attrs.transform;
        }
        if (style.transform || attrs.transformOrigin) {
            style.transformOrigin = attrs.transformOrigin ?? "50% 50%";
            delete attrs.transformOrigin;
        }
        if (style.transform) {
            /**
             * SVG's element transform-origin uses its own median as a reference.
             * Therefore, transformBox becomes a fill-box
             */
            style.transformBox = styleProp?.transformBox ?? "fill-box";
            delete attrs.transformBox;
        }
        for (const key of cssMotionPathProperties) {
            if (attrs[key] !== undefined) {
                style[key] = attrs[key];
                delete attrs[key];
            }
        }
        // Render attrX/attrY/attrScale as attributes
        if (attrX !== undefined)
            attrs.x = attrX;
        if (attrY !== undefined)
            attrs.y = attrY;
        if (attrScale !== undefined)
            attrs.scale = attrScale;
        // Build SVG path if one has been defined
        if (pathLength !== undefined) {
            buildSVGPath(attrs, pathLength, pathSpacing, pathOffset, false);
        }
    }

    /**
     * A set of attribute names that are always read/written as camel case.
     */
    const camelCaseAttributes = new Set([
        "baseFrequency",
        "diffuseConstant",
        "kernelMatrix",
        "kernelUnitLength",
        "keySplines",
        "keyTimes",
        "limitingConeAngle",
        "markerHeight",
        "markerWidth",
        "numOctaves",
        "targetX",
        "targetY",
        "surfaceScale",
        "specularConstant",
        "specularExponent",
        "stdDeviation",
        "tableValues",
        "viewBox",
        "gradientTransform",
        "pathLength",
        "startOffset",
        "textLength",
        "lengthAdjust",
    ]);

    const isSVGTag = (tag) => typeof tag === "string" && tag.toLowerCase() === "svg";

    function renderSVG(element, renderState, _styleProp, projection) {
        renderHTML(element, renderState, undefined, projection);
        for (const key in renderState.attrs) {
            element.setAttribute(!camelCaseAttributes.has(key) ? camelToDash(key) : key, renderState.attrs[key]);
        }
    }

    function scrapeMotionValuesFromProps(props, prevProps, visualElement) {
        const newValues = scrapeMotionValuesFromProps$1(props, prevProps, visualElement);
        for (const key in props) {
            if (isMotionValue(props[key]) ||
                isMotionValue(prevProps[key])) {
                const targetKey = transformPropOrder.indexOf(key) !== -1
                    ? "attr" + key.charAt(0).toUpperCase() + key.substring(1)
                    : key;
                newValues[targetKey] = props[key];
            }
        }
        return newValues;
    }

    class SVGVisualElement extends DOMVisualElement {
        constructor() {
            super(...arguments);
            this.type = "svg";
            this.isSVGTag = false;
            this.measureInstanceViewportBox = createBox;
        }
        getBaseTargetFromProps(props, key) {
            return props[key];
        }
        readValueFromInstance(instance, key) {
            if (transformProps.has(key)) {
                const defaultType = getDefaultValueType(key);
                return defaultType ? defaultType.default || 0 : 0;
            }
            key = !camelCaseAttributes.has(key) ? camelToDash(key) : key;
            return instance.getAttribute(key);
        }
        scrapeMotionValuesFromProps(props, prevProps, visualElement) {
            return scrapeMotionValuesFromProps(props, prevProps, visualElement);
        }
        build(renderState, latestValues, props) {
            buildSVGAttrs(renderState, latestValues, this.isSVGTag, props.transformTemplate, props.style);
        }
        renderInstance(instance, renderState, styleProp, projection) {
            renderSVG(instance, renderState, styleProp, projection);
        }
        mount(instance) {
            this.isSVGTag = isSVGTag(instance.tagName);
            super.mount(instance);
        }
    }

    const numVariantProps = variantProps.length;
    /**
     * Get variant context from a visual element's parent chain.
     * Uses `any` type for visualElement to avoid circular dependencies.
     */
    function getVariantContext(visualElement) {
        if (!visualElement)
            return undefined;
        if (!visualElement.isControllingVariants) {
            const context = visualElement.parent
                ? getVariantContext(visualElement.parent) || {}
                : {};
            if (visualElement.props.initial !== undefined) {
                context.initial = visualElement.props.initial;
            }
            return context;
        }
        const context = {};
        for (let i = 0; i < numVariantProps; i++) {
            const name = variantProps[i];
            const prop = visualElement.props[name];
            if (isVariantLabel(prop) || prop === false) {
                context[name] = prop;
            }
        }
        return context;
    }

    function shallowCompare(next, prev) {
        if (!Array.isArray(prev))
            return false;
        const prevLength = prev.length;
        if (prevLength !== next.length)
            return false;
        for (let i = 0; i < prevLength; i++) {
            if (prev[i] !== next[i])
                return false;
        }
        return true;
    }

    const reversePriorityOrder = [...variantPriorityOrder].reverse();
    const numAnimationTypes = variantPriorityOrder.length;
    function createAnimateFunction(visualElement) {
        return (animations) => {
            return Promise.all(animations.map(({ animation, options }) => animateVisualElement(visualElement, animation, options)));
        };
    }
    function createAnimationState(visualElement) {
        let animate = createAnimateFunction(visualElement);
        let state = createState();
        let isInitialRender = true;
        /**
         * This function will be used to reduce the animation definitions for
         * each active animation type into an object of resolved values for it.
         */
        const buildResolvedTypeValues = (type) => (acc, definition) => {
            const resolved = resolveVariant(visualElement, definition, type === "exit"
                ? visualElement.presenceContext?.custom
                : undefined);
            if (resolved) {
                const { transition, transitionEnd, ...target } = resolved;
                acc = { ...acc, ...target, ...transitionEnd };
            }
            return acc;
        };
        /**
         * This just allows us to inject mocked animation functions
         * @internal
         */
        function setAnimateFunction(makeAnimator) {
            animate = makeAnimator(visualElement);
        }
        /**
         * When we receive new props, we need to:
         * 1. Create a list of protected keys for each type. This is a directory of
         *    value keys that are currently being "handled" by types of a higher priority
         *    so that whenever an animation is played of a given type, these values are
         *    protected from being animated.
         * 2. Determine if an animation type needs animating.
         * 3. Determine if any values have been removed from a type and figure out
         *    what to animate those to.
         */
        function animateChanges(changedActiveType) {
            const { props } = visualElement;
            const context = getVariantContext(visualElement.parent) || {};
            /**
             * A list of animations that we'll build into as we iterate through the animation
             * types. This will get executed at the end of the function.
             */
            const animations = [];
            /**
             * Keep track of which values have been removed. Then, as we hit lower priority
             * animation types, we can check if they contain removed values and animate to that.
             */
            const removedKeys = new Set();
            /**
             * A dictionary of all encountered keys. This is an object to let us build into and
             * copy it without iteration. Each time we hit an animation type we set its protected
             * keys - the keys its not allowed to animate - to the latest version of this object.
             */
            let encounteredKeys = {};
            /**
             * If a variant has been removed at a given index, and this component is controlling
             * variant animations, we want to ensure lower-priority variants are forced to animate.
             */
            let removedVariantIndex = Infinity;
            /**
             * Iterate through all animation types in reverse priority order. For each, we want to
             * detect which values it's handling and whether or not they've changed (and therefore
             * need to be animated). If any values have been removed, we want to detect those in
             * lower priority props and flag for animation.
             */
            for (let i = 0; i < numAnimationTypes; i++) {
                const type = reversePriorityOrder[i];
                const typeState = state[type];
                const prop = props[type] !== undefined
                    ? props[type]
                    : context[type];
                const propIsVariant = isVariantLabel(prop);
                /**
                 * If this type has *just* changed isActive status, set activeDelta
                 * to that status. Otherwise set to null.
                 */
                const activeDelta = type === changedActiveType ? typeState.isActive : null;
                if (activeDelta === false)
                    removedVariantIndex = i;
                /**
                 * If this prop is an inherited variant, rather than been set directly on the
                 * component itself, we want to make sure we allow the parent to trigger animations.
                 *
                 * TODO: Can probably change this to a !isControllingVariants check
                 */
                let isInherited = prop === context[type] &&
                    prop !== props[type] &&
                    propIsVariant;
                if (isInherited &&
                    isInitialRender &&
                    visualElement.manuallyAnimateOnMount) {
                    isInherited = false;
                }
                /**
                 * Set all encountered keys so far as the protected keys for this type. This will
                 * be any key that has been animated or otherwise handled by active, higher-priortiy types.
                 */
                typeState.protectedKeys = { ...encounteredKeys };
                // Check if we can skip analysing this prop early
                if (
                // If it isn't active and hasn't *just* been set as inactive
                (!typeState.isActive && activeDelta === null) ||
                    // If we didn't and don't have any defined prop for this animation type
                    (!prop && !typeState.prevProp) ||
                    // Or if the prop doesn't define an animation
                    isAnimationControls(prop) ||
                    typeof prop === "boolean") {
                    continue;
                }
                /**
                 * As we go look through the values defined on this type, if we detect
                 * a changed value or a value that was removed in a higher priority, we set
                 * this to true and add this prop to the animation list.
                 */
                const variantDidChange = checkVariantsDidChange(typeState.prevProp, prop);
                let shouldAnimateType = variantDidChange ||
                    // If we're making this variant active, we want to always make it active
                    (type === changedActiveType &&
                        typeState.isActive &&
                        !isInherited &&
                        propIsVariant) ||
                    // If we removed a higher-priority variant (i is in reverse order)
                    (i > removedVariantIndex && propIsVariant);
                let handledRemovedValues = false;
                /**
                 * As animations can be set as variant lists, variants or target objects, we
                 * coerce everything to an array if it isn't one already
                 */
                const definitionList = Array.isArray(prop) ? prop : [prop];
                /**
                 * Build an object of all the resolved values. We'll use this in the subsequent
                 * animateChanges calls to determine whether a value has changed.
                 */
                let resolvedValues = definitionList.reduce(buildResolvedTypeValues(type), {});
                if (activeDelta === false)
                    resolvedValues = {};
                /**
                 * Now we need to loop through all the keys in the prev prop and this prop,
                 * and decide:
                 * 1. If the value has changed, and needs animating
                 * 2. If it has been removed, and needs adding to the removedKeys set
                 * 3. If it has been removed in a higher priority type and needs animating
                 * 4. If it hasn't been removed in a higher priority but hasn't changed, and
                 *    needs adding to the type's protectedKeys list.
                 */
                const { prevResolvedValues = {} } = typeState;
                const allKeys = {
                    ...prevResolvedValues,
                    ...resolvedValues,
                };
                const markToAnimate = (key) => {
                    shouldAnimateType = true;
                    if (removedKeys.has(key)) {
                        handledRemovedValues = true;
                        removedKeys.delete(key);
                    }
                    typeState.needsAnimating[key] = true;
                    const motionValue = visualElement.getValue(key);
                    if (motionValue)
                        motionValue.liveStyle = false;
                };
                for (const key in allKeys) {
                    const next = resolvedValues[key];
                    const prev = prevResolvedValues[key];
                    // If we've already handled this we can just skip ahead
                    if (encounteredKeys.hasOwnProperty(key))
                        continue;
                    /**
                     * If the value has changed, we probably want to animate it.
                     */
                    let valueHasChanged = false;
                    if (isKeyframesTarget(next) && isKeyframesTarget(prev)) {
                        valueHasChanged = !shallowCompare(next, prev);
                    }
                    else {
                        valueHasChanged = next !== prev;
                    }
                    if (valueHasChanged) {
                        if (next !== undefined && next !== null) {
                            // If next is defined and doesn't equal prev, it needs animating
                            markToAnimate(key);
                        }
                        else {
                            // If it's undefined, it's been removed.
                            removedKeys.add(key);
                        }
                    }
                    else if (next !== undefined && removedKeys.has(key)) {
                        /**
                         * If next hasn't changed and it isn't undefined, we want to check if it's
                         * been removed by a higher priority
                         */
                        markToAnimate(key);
                    }
                    else {
                        /**
                         * If it hasn't changed, we add it to the list of protected values
                         * to ensure it doesn't get animated.
                         */
                        typeState.protectedKeys[key] = true;
                    }
                }
                /**
                 * Update the typeState so next time animateChanges is called we can compare the
                 * latest prop and resolvedValues to these.
                 */
                typeState.prevProp = prop;
                typeState.prevResolvedValues = resolvedValues;
                if (typeState.isActive) {
                    encounteredKeys = { ...encounteredKeys, ...resolvedValues };
                }
                if (isInitialRender && visualElement.blockInitialAnimation) {
                    shouldAnimateType = false;
                }
                /**
                 * If this is an inherited prop we want to skip this animation
                 * unless the inherited variants haven't changed on this render.
                 */
                const willAnimateViaParent = isInherited && variantDidChange;
                const needsAnimating = !willAnimateViaParent || handledRemovedValues;
                if (shouldAnimateType && needsAnimating) {
                    animations.push(...definitionList.map((animation) => {
                        const options = { type };
                        /**
                         * If we're performing the initial animation, but we're not
                         * rendering at the same time as the variant-controlling parent,
                         * we want to use the parent's transition to calculate the stagger.
                         */
                        if (typeof animation === "string" &&
                            isInitialRender &&
                            !willAnimateViaParent &&
                            visualElement.manuallyAnimateOnMount &&
                            visualElement.parent) {
                            const { parent } = visualElement;
                            const parentVariant = resolveVariant(parent, animation);
                            if (parent.enteringChildren && parentVariant) {
                                const { delayChildren } = parentVariant.transition || {};
                                options.delay = calcChildStagger(parent.enteringChildren, visualElement, delayChildren);
                            }
                        }
                        return {
                            animation: animation,
                            options,
                        };
                    }));
                }
            }
            /**
             * If there are some removed value that haven't been dealt with,
             * we need to create a new animation that falls back either to the value
             * defined in the style prop, or the last read value.
             */
            if (removedKeys.size) {
                const fallbackAnimation = {};
                /**
                 * If the initial prop contains a transition we can use that, otherwise
                 * allow the animation function to use the visual element's default.
                 */
                if (typeof props.initial !== "boolean") {
                    const initialTransition = resolveVariant(visualElement, Array.isArray(props.initial)
                        ? props.initial[0]
                        : props.initial);
                    if (initialTransition && initialTransition.transition) {
                        fallbackAnimation.transition = initialTransition.transition;
                    }
                }
                removedKeys.forEach((key) => {
                    const fallbackTarget = visualElement.getBaseTarget(key);
                    const motionValue = visualElement.getValue(key);
                    if (motionValue)
                        motionValue.liveStyle = true;
                    // @ts-expect-error - @mattgperry to figure if we should do something here
                    fallbackAnimation[key] = fallbackTarget ?? null;
                });
                animations.push({ animation: fallbackAnimation });
            }
            let shouldAnimate = Boolean(animations.length);
            if (isInitialRender &&
                (props.initial === false || props.initial === props.animate) &&
                !visualElement.manuallyAnimateOnMount) {
                shouldAnimate = false;
            }
            isInitialRender = false;
            return shouldAnimate ? animate(animations) : Promise.resolve();
        }
        /**
         * Change whether a certain animation type is active.
         */
        function setActive(type, isActive) {
            // If the active state hasn't changed, we can safely do nothing here
            if (state[type].isActive === isActive)
                return Promise.resolve();
            // Propagate active change to children
            visualElement.variantChildren?.forEach((child) => child.animationState?.setActive(type, isActive));
            state[type].isActive = isActive;
            const animations = animateChanges(type);
            for (const key in state) {
                state[key].protectedKeys = {};
            }
            return animations;
        }
        return {
            animateChanges,
            setActive,
            setAnimateFunction,
            getState: () => state,
            reset: () => {
                state = createState();
                /**
                 * Temporarily disabling resetting this flag as it prevents components
                 * with initial={false} from animating after being remounted, for instance
                 * as the child of an Activity component.
                 */
                // isInitialRender = true
            },
        };
    }
    function checkVariantsDidChange(prev, next) {
        if (typeof next === "string") {
            return next !== prev;
        }
        else if (Array.isArray(next)) {
            return !shallowCompare(next, prev);
        }
        return false;
    }
    function createTypeState(isActive = false) {
        return {
            isActive,
            protectedKeys: {},
            needsAnimating: {},
            prevResolvedValues: {},
        };
    }
    function createState() {
        return {
            animate: createTypeState(true),
            whileInView: createTypeState(),
            whileHover: createTypeState(),
            whileTap: createTypeState(),
            whileDrag: createTypeState(),
            whileFocus: createTypeState(),
            exit: createTypeState(),
        };
    }

    /**
     * Reset an axis to the provided origin box.
     *
     * This is a mutative operation.
     */
    function copyAxisInto(axis, originAxis) {
        axis.min = originAxis.min;
        axis.max = originAxis.max;
    }
    /**
     * Reset a box to the provided origin box.
     *
     * This is a mutative operation.
     */
    function copyBoxInto(box, originBox) {
        copyAxisInto(box.x, originBox.x);
        copyAxisInto(box.y, originBox.y);
    }
    /**
     * Reset a delta to the provided origin box.
     *
     * This is a mutative operation.
     */
    function copyAxisDeltaInto(delta, originDelta) {
        delta.translate = originDelta.translate;
        delta.scale = originDelta.scale;
        delta.originPoint = originDelta.originPoint;
        delta.origin = originDelta.origin;
    }

    const SCALE_PRECISION = 0.0001;
    const SCALE_MIN = 1 - SCALE_PRECISION;
    const SCALE_MAX = 1 + SCALE_PRECISION;
    const TRANSLATE_PRECISION = 0.01;
    const TRANSLATE_MIN = 0 - TRANSLATE_PRECISION;
    const TRANSLATE_MAX = 0 + TRANSLATE_PRECISION;
    function calcLength(axis) {
        return axis.max - axis.min;
    }
    function isNear(value, target, maxDistance) {
        return Math.abs(value - target) <= maxDistance;
    }
    function calcAxisDelta(delta, source, target, origin = 0.5) {
        delta.origin = origin;
        delta.originPoint = mixNumber$1(source.min, source.max, delta.origin);
        delta.scale = calcLength(target) / calcLength(source);
        delta.translate =
            mixNumber$1(target.min, target.max, delta.origin) - delta.originPoint;
        if ((delta.scale >= SCALE_MIN && delta.scale <= SCALE_MAX) ||
            isNaN(delta.scale)) {
            delta.scale = 1.0;
        }
        if ((delta.translate >= TRANSLATE_MIN &&
            delta.translate <= TRANSLATE_MAX) ||
            isNaN(delta.translate)) {
            delta.translate = 0.0;
        }
    }
    function calcBoxDelta(delta, source, target, origin) {
        calcAxisDelta(delta.x, source.x, target.x, origin ? origin.originX : undefined);
        calcAxisDelta(delta.y, source.y, target.y, origin ? origin.originY : undefined);
    }
    function calcRelativeAxis(target, relative, parent) {
        target.min = parent.min + relative.min;
        target.max = target.min + calcLength(relative);
    }
    function calcRelativeBox(target, relative, parent) {
        calcRelativeAxis(target.x, relative.x, parent.x);
        calcRelativeAxis(target.y, relative.y, parent.y);
    }
    function calcRelativeAxisPosition(target, layout, parent) {
        target.min = layout.min - parent.min;
        target.max = target.min + calcLength(layout);
    }
    function calcRelativePosition(target, layout, parent) {
        calcRelativeAxisPosition(target.x, layout.x, parent.x);
        calcRelativeAxisPosition(target.y, layout.y, parent.y);
    }

    /**
     * Remove a delta from a point. This is essentially the steps of applyPointDelta in reverse
     */
    function removePointDelta(point, translate, scale, originPoint, boxScale) {
        point -= translate;
        point = scalePoint(point, 1 / scale, originPoint);
        if (boxScale !== undefined) {
            point = scalePoint(point, 1 / boxScale, originPoint);
        }
        return point;
    }
    /**
     * Remove a delta from an axis. This is essentially the steps of applyAxisDelta in reverse
     */
    function removeAxisDelta(axis, translate = 0, scale = 1, origin = 0.5, boxScale, originAxis = axis, sourceAxis = axis) {
        if (percent.test(translate)) {
            translate = parseFloat(translate);
            const relativeProgress = mixNumber$1(sourceAxis.min, sourceAxis.max, translate / 100);
            translate = relativeProgress - sourceAxis.min;
        }
        if (typeof translate !== "number")
            return;
        let originPoint = mixNumber$1(originAxis.min, originAxis.max, origin);
        if (axis === originAxis)
            originPoint -= translate;
        axis.min = removePointDelta(axis.min, translate, scale, originPoint, boxScale);
        axis.max = removePointDelta(axis.max, translate, scale, originPoint, boxScale);
    }
    /**
     * Remove a transforms from an axis. This is essentially the steps of applyAxisTransforms in reverse
     * and acts as a bridge between motion values and removeAxisDelta
     */
    function removeAxisTransforms(axis, transforms, [key, scaleKey, originKey], origin, sourceAxis) {
        removeAxisDelta(axis, transforms[key], transforms[scaleKey], transforms[originKey], transforms.scale, origin, sourceAxis);
    }
    /**
     * The names of the motion values we want to apply as translation, scale and origin.
     */
    const xKeys = ["x", "scaleX", "originX"];
    const yKeys = ["y", "scaleY", "originY"];
    /**
     * Remove a transforms from an box. This is essentially the steps of applyAxisBox in reverse
     * and acts as a bridge between motion values and removeAxisDelta
     */
    function removeBoxTransforms(box, transforms, originBox, sourceBox) {
        removeAxisTransforms(box.x, transforms, xKeys, originBox ? originBox.x : undefined, sourceBox ? sourceBox.x : undefined);
        removeAxisTransforms(box.y, transforms, yKeys, originBox ? originBox.y : undefined, sourceBox ? sourceBox.y : undefined);
    }

    function isAxisDeltaZero(delta) {
        return delta.translate === 0 && delta.scale === 1;
    }
    function isDeltaZero(delta) {
        return isAxisDeltaZero(delta.x) && isAxisDeltaZero(delta.y);
    }
    function axisEquals(a, b) {
        return a.min === b.min && a.max === b.max;
    }
    function boxEquals(a, b) {
        return axisEquals(a.x, b.x) && axisEquals(a.y, b.y);
    }
    function axisEqualsRounded(a, b) {
        return (Math.round(a.min) === Math.round(b.min) &&
            Math.round(a.max) === Math.round(b.max));
    }
    function boxEqualsRounded(a, b) {
        return axisEqualsRounded(a.x, b.x) && axisEqualsRounded(a.y, b.y);
    }
    function aspectRatio(box) {
        return calcLength(box.x) / calcLength(box.y);
    }
    function axisDeltaEquals(a, b) {
        return (a.translate === b.translate &&
            a.scale === b.scale &&
            a.originPoint === b.originPoint);
    }

    function eachAxis(callback) {
        return [callback("x"), callback("y")];
    }

    function buildProjectionTransform(delta, treeScale, latestTransform) {
        let transform = "";
        /**
         * The translations we use to calculate are always relative to the viewport coordinate space.
         * But when we apply scales, we also scale the coordinate space of an element and its children.
         * For instance if we have a treeScale (the culmination of all parent scales) of 0.5 and we need
         * to move an element 100 pixels, we actually need to move it 200 in within that scaled space.
         */
        const xTranslate = delta.x.translate / treeScale.x;
        const yTranslate = delta.y.translate / treeScale.y;
        const zTranslate = latestTransform?.z || 0;
        if (xTranslate || yTranslate || zTranslate) {
            transform = `translate3d(${xTranslate}px, ${yTranslate}px, ${zTranslate}px) `;
        }
        /**
         * Apply scale correction for the tree transform.
         * This will apply scale to the screen-orientated axes.
         */
        if (treeScale.x !== 1 || treeScale.y !== 1) {
            transform += `scale(${1 / treeScale.x}, ${1 / treeScale.y}) `;
        }
        if (latestTransform) {
            const { transformPerspective, rotate, rotateX, rotateY, skewX, skewY } = latestTransform;
            if (transformPerspective)
                transform = `perspective(${transformPerspective}px) ${transform}`;
            if (rotate)
                transform += `rotate(${rotate}deg) `;
            if (rotateX)
                transform += `rotateX(${rotateX}deg) `;
            if (rotateY)
                transform += `rotateY(${rotateY}deg) `;
            if (skewX)
                transform += `skewX(${skewX}deg) `;
            if (skewY)
                transform += `skewY(${skewY}deg) `;
        }
        /**
         * Apply scale to match the size of the element to the size we want it.
         * This will apply scale to the element-orientated axes.
         */
        const elementScaleX = delta.x.scale * treeScale.x;
        const elementScaleY = delta.y.scale * treeScale.y;
        if (elementScaleX !== 1 || elementScaleY !== 1) {
            transform += `scale(${elementScaleX}, ${elementScaleY})`;
        }
        return transform || "none";
    }

    const borders = ["TopLeft", "TopRight", "BottomLeft", "BottomRight"];
    const numBorders = borders.length;
    const asNumber = (value) => typeof value === "string" ? parseFloat(value) : value;
    const isPx = (value) => typeof value === "number" || px.test(value);
    function mixValues(target, follow, lead, progress, shouldCrossfadeOpacity, isOnlyMember) {
        if (shouldCrossfadeOpacity) {
            target.opacity = mixNumber$1(0, lead.opacity ?? 1, easeCrossfadeIn(progress));
            target.opacityExit = mixNumber$1(follow.opacity ?? 1, 0, easeCrossfadeOut(progress));
        }
        else if (isOnlyMember) {
            target.opacity = mixNumber$1(follow.opacity ?? 1, lead.opacity ?? 1, progress);
        }
        /**
         * Mix border radius
         */
        for (let i = 0; i < numBorders; i++) {
            const borderLabel = `border${borders[i]}Radius`;
            let followRadius = getRadius(follow, borderLabel);
            let leadRadius = getRadius(lead, borderLabel);
            if (followRadius === undefined && leadRadius === undefined)
                continue;
            followRadius || (followRadius = 0);
            leadRadius || (leadRadius = 0);
            const canMix = followRadius === 0 ||
                leadRadius === 0 ||
                isPx(followRadius) === isPx(leadRadius);
            if (canMix) {
                target[borderLabel] = Math.max(mixNumber$1(asNumber(followRadius), asNumber(leadRadius), progress), 0);
                if (percent.test(leadRadius) || percent.test(followRadius)) {
                    target[borderLabel] += "%";
                }
            }
            else {
                target[borderLabel] = leadRadius;
            }
        }
        /**
         * Mix rotation
         */
        if (follow.rotate || lead.rotate) {
            target.rotate = mixNumber$1(follow.rotate || 0, lead.rotate || 0, progress);
        }
    }
    function getRadius(values, radiusName) {
        return values[radiusName] !== undefined
            ? values[radiusName]
            : values.borderRadius;
    }
    const easeCrossfadeIn = /*@__PURE__*/ compress(0, 0.5, motionUtils.circOut);
    const easeCrossfadeOut = /*@__PURE__*/ compress(0.5, 0.95, motionUtils.noop);
    function compress(min, max, easing) {
        return (p) => {
            // Could replace ifs with clamp
            if (p < min)
                return 0;
            if (p > max)
                return 1;
            return easing(motionUtils.progress(min, max, p));
        };
    }

    function animateSingleValue(value, keyframes, options) {
        const motionValue$1 = isMotionValue(value) ? value : motionValue(value);
        motionValue$1.start(animateMotionValue("", motionValue$1, keyframes, options));
        return motionValue$1.animation;
    }

    function addDomEvent(target, eventName, handler, options = { passive: true }) {
        target.addEventListener(eventName, handler, options);
        return () => target.removeEventListener(eventName, handler);
    }

    const compareByDepth = (a, b) => a.depth - b.depth;

    class FlatTree {
        constructor() {
            this.children = [];
            this.isDirty = false;
        }
        add(child) {
            motionUtils.addUniqueItem(this.children, child);
            this.isDirty = true;
        }
        remove(child) {
            motionUtils.removeItem(this.children, child);
            this.isDirty = true;
        }
        forEach(callback) {
            this.isDirty && this.children.sort(compareByDepth);
            this.isDirty = false;
            this.children.forEach(callback);
        }
    }

    /**
     * Timeout defined in ms
     */
    function delay(callback, timeout) {
        const start = time.now();
        const checkElapsed = ({ timestamp }) => {
            const elapsed = timestamp - start;
            if (elapsed >= timeout) {
                cancelFrame(checkElapsed);
                callback(elapsed - timeout);
            }
        };
        frame.setup(checkElapsed, true);
        return () => cancelFrame(checkElapsed);
    }
    function delayInSeconds(callback, timeout) {
        return delay(callback, motionUtils.secondsToMilliseconds(timeout));
    }

    /**
     * If the provided value is a MotionValue, this returns the actual value, otherwise just the value itself
     */
    function resolveMotionValue(value) {
        return isMotionValue(value) ? value.get() : value;
    }

    class NodeStack {
        constructor() {
            this.members = [];
        }
        add(node) {
            motionUtils.addUniqueItem(this.members, node);
            node.scheduleRender();
        }
        remove(node) {
            motionUtils.removeItem(this.members, node);
            if (node === this.prevLead) {
                this.prevLead = undefined;
            }
            if (node === this.lead) {
                const prevLead = this.members[this.members.length - 1];
                if (prevLead) {
                    this.promote(prevLead);
                }
            }
        }
        relegate(node) {
            const indexOfNode = this.members.findIndex((member) => node === member);
            if (indexOfNode === 0)
                return false;
            /**
             * Find the next projection node that is present
             */
            let prevLead;
            for (let i = indexOfNode; i >= 0; i--) {
                const member = this.members[i];
                if (member.isPresent !== false) {
                    prevLead = member;
                    break;
                }
            }
            if (prevLead) {
                this.promote(prevLead);
                return true;
            }
            else {
                return false;
            }
        }
        promote(node, preserveFollowOpacity) {
            const prevLead = this.lead;
            if (node === prevLead)
                return;
            this.prevLead = prevLead;
            this.lead = node;
            node.show();
            if (prevLead) {
                prevLead.instance && prevLead.scheduleRender();
                node.scheduleRender();
                node.resumeFrom = prevLead;
                if (preserveFollowOpacity) {
                    node.resumeFrom.preserveOpacity = true;
                }
                if (prevLead.snapshot) {
                    node.snapshot = prevLead.snapshot;
                    node.snapshot.latestValues =
                        prevLead.animationValues || prevLead.latestValues;
                }
                if (node.root && node.root.isUpdating) {
                    node.isLayoutDirty = true;
                }
                const { crossfade } = node.options;
                if (crossfade === false) {
                    prevLead.hide();
                }
            }
        }
        exitAnimationComplete() {
            this.members.forEach((node) => {
                const { options, resumingFrom } = node;
                options.onExitComplete && options.onExitComplete();
                if (resumingFrom) {
                    resumingFrom.options.onExitComplete &&
                        resumingFrom.options.onExitComplete();
                }
            });
        }
        scheduleRender() {
            this.members.forEach((node) => {
                node.instance && node.scheduleRender(false);
            });
        }
        /**
         * Clear any leads that have been removed this render to prevent them from being
         * used in future animations and to prevent memory leaks
         */
        removeLeadSnapshot() {
            if (this.lead && this.lead.snapshot) {
                this.lead.snapshot = undefined;
            }
        }
    }

    /**
     * This should only ever be modified on the client otherwise it'll
     * persist through server requests. If we need instanced states we
     * could lazy-init via root.
     */
    const globalProjectionState = {
        /**
         * Global flag as to whether the tree has animated since the last time
         * we resized the window
         */
        hasAnimatedSinceResize: true,
        /**
         * We set this to true once, on the first update. Any nodes added to the tree beyond that
         * update will be given a `data-projection-id` attribute.
         */
        hasEverUpdated: false,
    };

    const metrics = {
        nodes: 0,
        calculatedTargetDeltas: 0,
        calculatedProjections: 0,
    };
    const transformAxes = ["", "X", "Y", "Z"];
    /**
     * We use 1000 as the animation target as 0-1000 maps better to pixels than 0-1
     * which has a noticeable difference in spring animations
     */
    const animationTarget = 1000;
    let id = 0;
    function resetDistortingTransform(key, visualElement, values, sharedAnimationValues) {
        const { latestValues } = visualElement;
        // Record the distorting transform and then temporarily set it to 0
        if (latestValues[key]) {
            values[key] = latestValues[key];
            visualElement.setStaticValue(key, 0);
            if (sharedAnimationValues) {
                sharedAnimationValues[key] = 0;
            }
        }
    }
    function cancelTreeOptimisedTransformAnimations(projectionNode) {
        projectionNode.hasCheckedOptimisedAppear = true;
        if (projectionNode.root === projectionNode)
            return;
        const { visualElement } = projectionNode.options;
        if (!visualElement)
            return;
        const appearId = getOptimisedAppearId(visualElement);
        if (window.MotionHasOptimisedAnimation(appearId, "transform")) {
            const { layout, layoutId } = projectionNode.options;
            window.MotionCancelOptimisedAnimation(appearId, "transform", frame, !(layout || layoutId));
        }
        const { parent } = projectionNode;
        if (parent && !parent.hasCheckedOptimisedAppear) {
            cancelTreeOptimisedTransformAnimations(parent);
        }
    }
    function createProjectionNode$1({ attachResizeListener, defaultParent, measureScroll, checkIsScrollRoot, resetTransform, }) {
        return class ProjectionNode {
            constructor(latestValues = {}, parent = defaultParent?.()) {
                /**
                 * A unique ID generated for every projection node.
                 */
                this.id = id++;
                /**
                 * An id that represents a unique session instigated by startUpdate.
                 */
                this.animationId = 0;
                this.animationCommitId = 0;
                /**
                 * A Set containing all this component's children. This is used to iterate
                 * through the children.
                 *
                 * TODO: This could be faster to iterate as a flat array stored on the root node.
                 */
                this.children = new Set();
                /**
                 * Options for the node. We use this to configure what kind of layout animations
                 * we should perform (if any).
                 */
                this.options = {};
                /**
                 * We use this to detect when its safe to shut down part of a projection tree.
                 * We have to keep projecting children for scale correction and relative projection
                 * until all their parents stop performing layout animations.
                 */
                this.isTreeAnimating = false;
                this.isAnimationBlocked = false;
                /**
                 * Flag to true if we think this layout has been changed. We can't always know this,
                 * currently we set it to true every time a component renders, or if it has a layoutDependency
                 * if that has changed between renders. Additionally, components can be grouped by LayoutGroup
                 * and if one node is dirtied, they all are.
                 */
                this.isLayoutDirty = false;
                /**
                 * Flag to true if we think the projection calculations for this node needs
                 * recalculating as a result of an updated transform or layout animation.
                 */
                this.isProjectionDirty = false;
                /**
                 * Flag to true if the layout *or* transform has changed. This then gets propagated
                 * throughout the projection tree, forcing any element below to recalculate on the next frame.
                 */
                this.isSharedProjectionDirty = false;
                /**
                 * Flag transform dirty. This gets propagated throughout the whole tree but is only
                 * respected by shared nodes.
                 */
                this.isTransformDirty = false;
                /**
                 * Block layout updates for instant layout transitions throughout the tree.
                 */
                this.updateManuallyBlocked = false;
                this.updateBlockedByResize = false;
                /**
                 * Set to true between the start of the first `willUpdate` call and the end of the `didUpdate`
                 * call.
                 */
                this.isUpdating = false;
                /**
                 * If this is an SVG element we currently disable projection transforms
                 */
                this.isSVG = false;
                /**
                 * Flag to true (during promotion) if a node doing an instant layout transition needs to reset
                 * its projection styles.
                 */
                this.needsReset = false;
                /**
                 * Flags whether this node should have its transform reset prior to measuring.
                 */
                this.shouldResetTransform = false;
                /**
                 * Store whether this node has been checked for optimised appear animations. As
                 * effects fire bottom-up, and we want to look up the tree for appear animations,
                 * this makes sure we only check each path once, stopping at nodes that
                 * have already been checked.
                 */
                this.hasCheckedOptimisedAppear = false;
                /**
                 * An object representing the calculated contextual/accumulated/tree scale.
                 * This will be used to scale calculcated projection transforms, as these are
                 * calculated in screen-space but need to be scaled for elements to layoutly
                 * make it to their calculated destinations.
                 *
                 * TODO: Lazy-init
                 */
                this.treeScale = { x: 1, y: 1 };
                /**
                 *
                 */
                this.eventHandlers = new Map();
                this.hasTreeAnimated = false;
                this.layoutVersion = 0;
                // Note: Currently only running on root node
                this.updateScheduled = false;
                this.scheduleUpdate = () => this.update();
                this.projectionUpdateScheduled = false;
                this.checkUpdateFailed = () => {
                    if (this.isUpdating) {
                        this.isUpdating = false;
                        this.clearAllSnapshots();
                    }
                };
                /**
                 * This is a multi-step process as shared nodes might be of different depths. Nodes
                 * are sorted by depth order, so we need to resolve the entire tree before moving to
                 * the next step.
                 */
                this.updateProjection = () => {
                    this.projectionUpdateScheduled = false;
                    /**
                     * Reset debug counts. Manually resetting rather than creating a new
                     * object each frame.
                     */
                    if (statsBuffer.value) {
                        metrics.nodes =
                            metrics.calculatedTargetDeltas =
                                metrics.calculatedProjections =
                                    0;
                    }
                    this.nodes.forEach(propagateDirtyNodes);
                    this.nodes.forEach(resolveTargetDelta);
                    this.nodes.forEach(calcProjection);
                    this.nodes.forEach(cleanDirtyNodes);
                    if (statsBuffer.addProjectionMetrics) {
                        statsBuffer.addProjectionMetrics(metrics);
                    }
                };
                /**
                 * Frame calculations
                 */
                this.resolvedRelativeTargetAt = 0.0;
                this.linkedParentVersion = 0;
                this.hasProjected = false;
                this.isVisible = true;
                this.animationProgress = 0;
                /**
                 * Shared layout
                 */
                // TODO Only running on root node
                this.sharedNodes = new Map();
                this.latestValues = latestValues;
                this.root = parent ? parent.root || parent : this;
                this.path = parent ? [...parent.path, parent] : [];
                this.parent = parent;
                this.depth = parent ? parent.depth + 1 : 0;
                for (let i = 0; i < this.path.length; i++) {
                    this.path[i].shouldResetTransform = true;
                }
                if (this.root === this)
                    this.nodes = new FlatTree();
            }
            addEventListener(name, handler) {
                if (!this.eventHandlers.has(name)) {
                    this.eventHandlers.set(name, new motionUtils.SubscriptionManager());
                }
                return this.eventHandlers.get(name).add(handler);
            }
            notifyListeners(name, ...args) {
                const subscriptionManager = this.eventHandlers.get(name);
                subscriptionManager && subscriptionManager.notify(...args);
            }
            hasListeners(name) {
                return this.eventHandlers.has(name);
            }
            /**
             * Lifecycles
             */
            mount(instance) {
                if (this.instance)
                    return;
                this.isSVG = isSVGElement(instance) && !isSVGSVGElement(instance);
                this.instance = instance;
                const { layoutId, layout, visualElement } = this.options;
                if (visualElement && !visualElement.current) {
                    visualElement.mount(instance);
                }
                this.root.nodes.add(this);
                this.parent && this.parent.children.add(this);
                if (this.root.hasTreeAnimated && (layout || layoutId)) {
                    this.isLayoutDirty = true;
                }
                if (attachResizeListener) {
                    let cancelDelay;
                    let innerWidth = 0;
                    const resizeUnblockUpdate = () => (this.root.updateBlockedByResize = false);
                    // Set initial innerWidth in a frame.read callback to batch the read
                    frame.read(() => {
                        innerWidth = window.innerWidth;
                    });
                    attachResizeListener(instance, () => {
                        const newInnerWidth = window.innerWidth;
                        if (newInnerWidth === innerWidth)
                            return;
                        innerWidth = newInnerWidth;
                        this.root.updateBlockedByResize = true;
                        cancelDelay && cancelDelay();
                        cancelDelay = delay(resizeUnblockUpdate, 250);
                        if (globalProjectionState.hasAnimatedSinceResize) {
                            globalProjectionState.hasAnimatedSinceResize = false;
                            this.nodes.forEach(finishAnimation);
                        }
                    });
                }
                if (layoutId) {
                    this.root.registerSharedNode(layoutId, this);
                }
                // Only register the handler if it requires layout animation
                if (this.options.animate !== false &&
                    visualElement &&
                    (layoutId || layout)) {
                    this.addEventListener("didUpdate", ({ delta, hasLayoutChanged, hasRelativeLayoutChanged, layout: newLayout, }) => {
                        if (this.isTreeAnimationBlocked()) {
                            this.target = undefined;
                            this.relativeTarget = undefined;
                            return;
                        }
                        // TODO: Check here if an animation exists
                        const layoutTransition = this.options.transition ||
                            visualElement.getDefaultTransition() ||
                            defaultLayoutTransition;
                        const { onLayoutAnimationStart, onLayoutAnimationComplete, } = visualElement.getProps();
                        /**
                         * The target layout of the element might stay the same,
                         * but its position relative to its parent has changed.
                         */
                        const hasTargetChanged = !this.targetLayout ||
                            !boxEqualsRounded(this.targetLayout, newLayout);
                        /*
                         * Note: Disabled to fix relative animations always triggering new
                         * layout animations. If this causes further issues, we can try
                         * a different approach to detecting relative target changes.
                         */
                        // || hasRelativeLayoutChanged
                        /**
                         * If the layout hasn't seemed to have changed, it might be that the
                         * element is visually in the same place in the document but its position
                         * relative to its parent has indeed changed. So here we check for that.
                         */
                        const hasOnlyRelativeTargetChanged = !hasLayoutChanged && hasRelativeLayoutChanged;
                        if (this.options.layoutRoot ||
                            this.resumeFrom ||
                            hasOnlyRelativeTargetChanged ||
                            (hasLayoutChanged &&
                                (hasTargetChanged || !this.currentAnimation))) {
                            if (this.resumeFrom) {
                                this.resumingFrom = this.resumeFrom;
                                this.resumingFrom.resumingFrom = undefined;
                            }
                            const animationOptions = {
                                ...getValueTransition(layoutTransition, "layout"),
                                onPlay: onLayoutAnimationStart,
                                onComplete: onLayoutAnimationComplete,
                            };
                            if (visualElement.shouldReduceMotion ||
                                this.options.layoutRoot) {
                                animationOptions.delay = 0;
                                animationOptions.type = false;
                            }
                            this.startAnimation(animationOptions);
                            /**
                             * Set animation origin after starting animation to avoid layout jump
                             * caused by stopping previous layout animation
                             */
                            this.setAnimationOrigin(delta, hasOnlyRelativeTargetChanged);
                        }
                        else {
                            /**
                             * If the layout hasn't changed and we have an animation that hasn't started yet,
                             * finish it immediately. Otherwise it will be animating from a location
                             * that was probably never committed to screen and look like a jumpy box.
                             */
                            if (!hasLayoutChanged) {
                                finishAnimation(this);
                            }
                            if (this.isLead() && this.options.onExitComplete) {
                                this.options.onExitComplete();
                            }
                        }
                        this.targetLayout = newLayout;
                    });
                }
            }
            unmount() {
                this.options.layoutId && this.willUpdate();
                this.root.nodes.remove(this);
                const stack = this.getStack();
                stack && stack.remove(this);
                this.parent && this.parent.children.delete(this);
                this.instance = undefined;
                this.eventHandlers.clear();
                cancelFrame(this.updateProjection);
            }
            // only on the root
            blockUpdate() {
                this.updateManuallyBlocked = true;
            }
            unblockUpdate() {
                this.updateManuallyBlocked = false;
            }
            isUpdateBlocked() {
                return this.updateManuallyBlocked || this.updateBlockedByResize;
            }
            isTreeAnimationBlocked() {
                return (this.isAnimationBlocked ||
                    (this.parent && this.parent.isTreeAnimationBlocked()) ||
                    false);
            }
            // Note: currently only running on root node
            startUpdate() {
                if (this.isUpdateBlocked())
                    return;
                this.isUpdating = true;
                this.nodes && this.nodes.forEach(resetSkewAndRotation);
                this.animationId++;
            }
            getTransformTemplate() {
                const { visualElement } = this.options;
                return visualElement && visualElement.getProps().transformTemplate;
            }
            willUpdate(shouldNotifyListeners = true) {
                this.root.hasTreeAnimated = true;
                if (this.root.isUpdateBlocked()) {
                    this.options.onExitComplete && this.options.onExitComplete();
                    return;
                }
                /**
                 * If we're running optimised appear animations then these must be
                 * cancelled before measuring the DOM. This is so we can measure
                 * the true layout of the element rather than the WAAPI animation
                 * which will be unaffected by the resetSkewAndRotate step.
                 *
                 * Note: This is a DOM write. Worst case scenario is this is sandwiched
                 * between other snapshot reads which will cause unnecessary style recalculations.
                 * This has to happen here though, as we don't yet know which nodes will need
                 * snapshots in startUpdate(), but we only want to cancel optimised animations
                 * if a layout animation measurement is actually going to be affected by them.
                 */
                if (window.MotionCancelOptimisedAnimation &&
                    !this.hasCheckedOptimisedAppear) {
                    cancelTreeOptimisedTransformAnimations(this);
                }
                !this.root.isUpdating && this.root.startUpdate();
                if (this.isLayoutDirty)
                    return;
                this.isLayoutDirty = true;
                for (let i = 0; i < this.path.length; i++) {
                    const node = this.path[i];
                    node.shouldResetTransform = true;
                    node.updateScroll("snapshot");
                    if (node.options.layoutRoot) {
                        node.willUpdate(false);
                    }
                }
                const { layoutId, layout } = this.options;
                if (layoutId === undefined && !layout)
                    return;
                const transformTemplate = this.getTransformTemplate();
                this.prevTransformTemplateValue = transformTemplate
                    ? transformTemplate(this.latestValues, "")
                    : undefined;
                this.updateSnapshot();
                shouldNotifyListeners && this.notifyListeners("willUpdate");
            }
            update() {
                this.updateScheduled = false;
                const updateWasBlocked = this.isUpdateBlocked();
                // When doing an instant transition, we skip the layout update,
                // but should still clean up the measurements so that the next
                // snapshot could be taken correctly.
                if (updateWasBlocked) {
                    this.unblockUpdate();
                    this.clearAllSnapshots();
                    this.nodes.forEach(clearMeasurements);
                    return;
                }
                /**
                 * If this is a repeat of didUpdate then ignore the animation.
                 */
                if (this.animationId <= this.animationCommitId) {
                    this.nodes.forEach(clearIsLayoutDirty);
                    return;
                }
                this.animationCommitId = this.animationId;
                if (!this.isUpdating) {
                    this.nodes.forEach(clearIsLayoutDirty);
                }
                else {
                    this.isUpdating = false;
                    /**
                     * Write
                     */
                    this.nodes.forEach(resetTransformStyle);
                    /**
                     * Read ==================
                     */
                    // Update layout measurements of updated children
                    this.nodes.forEach(updateLayout);
                    /**
                     * Write
                     */
                    // Notify listeners that the layout is updated
                    this.nodes.forEach(notifyLayoutUpdate);
                }
                this.clearAllSnapshots();
                /**
                 * Manually flush any pending updates. Ideally
                 * we could leave this to the following requestAnimationFrame but this seems
                 * to leave a flash of incorrectly styled content.
                 */
                const now = time.now();
                frameData.delta = motionUtils.clamp(0, 1000 / 60, now - frameData.timestamp);
                frameData.timestamp = now;
                frameData.isProcessing = true;
                frameSteps.update.process(frameData);
                frameSteps.preRender.process(frameData);
                frameSteps.render.process(frameData);
                frameData.isProcessing = false;
            }
            didUpdate() {
                if (!this.updateScheduled) {
                    this.updateScheduled = true;
                    microtask.read(this.scheduleUpdate);
                }
            }
            clearAllSnapshots() {
                this.nodes.forEach(clearSnapshot);
                this.sharedNodes.forEach(removeLeadSnapshots);
            }
            scheduleUpdateProjection() {
                if (!this.projectionUpdateScheduled) {
                    this.projectionUpdateScheduled = true;
                    frame.preRender(this.updateProjection, false, true);
                }
            }
            scheduleCheckAfterUnmount() {
                /**
                 * If the unmounting node is in a layoutGroup and did trigger a willUpdate,
                 * we manually call didUpdate to give a chance to the siblings to animate.
                 * Otherwise, cleanup all snapshots to prevents future nodes from reusing them.
                 */
                frame.postRender(() => {
                    if (this.isLayoutDirty) {
                        this.root.didUpdate();
                    }
                    else {
                        this.root.checkUpdateFailed();
                    }
                });
            }
            /**
             * Update measurements
             */
            updateSnapshot() {
                if (this.snapshot || !this.instance)
                    return;
                this.snapshot = this.measure();
                if (this.snapshot &&
                    !calcLength(this.snapshot.measuredBox.x) &&
                    !calcLength(this.snapshot.measuredBox.y)) {
                    this.snapshot = undefined;
                }
            }
            updateLayout() {
                if (!this.instance)
                    return;
                this.updateScroll();
                if (!(this.options.alwaysMeasureLayout && this.isLead()) &&
                    !this.isLayoutDirty) {
                    return;
                }
                /**
                 * When a node is mounted, it simply resumes from the prevLead's
                 * snapshot instead of taking a new one, but the ancestors scroll
                 * might have updated while the prevLead is unmounted. We need to
                 * update the scroll again to make sure the layout we measure is
                 * up to date.
                 */
                if (this.resumeFrom && !this.resumeFrom.instance) {
                    for (let i = 0; i < this.path.length; i++) {
                        const node = this.path[i];
                        node.updateScroll();
                    }
                }
                const prevLayout = this.layout;
                this.layout = this.measure(false);
                this.layoutVersion++;
                this.layoutCorrected = createBox();
                this.isLayoutDirty = false;
                this.projectionDelta = undefined;
                this.notifyListeners("measure", this.layout.layoutBox);
                const { visualElement } = this.options;
                visualElement &&
                    visualElement.notify("LayoutMeasure", this.layout.layoutBox, prevLayout ? prevLayout.layoutBox : undefined);
            }
            updateScroll(phase = "measure") {
                let needsMeasurement = Boolean(this.options.layoutScroll && this.instance);
                if (this.scroll &&
                    this.scroll.animationId === this.root.animationId &&
                    this.scroll.phase === phase) {
                    needsMeasurement = false;
                }
                if (needsMeasurement && this.instance) {
                    const isRoot = checkIsScrollRoot(this.instance);
                    this.scroll = {
                        animationId: this.root.animationId,
                        phase,
                        isRoot,
                        offset: measureScroll(this.instance),
                        wasRoot: this.scroll ? this.scroll.isRoot : isRoot,
                    };
                }
            }
            resetTransform() {
                if (!resetTransform)
                    return;
                const isResetRequested = this.isLayoutDirty ||
                    this.shouldResetTransform ||
                    this.options.alwaysMeasureLayout;
                const hasProjection = this.projectionDelta && !isDeltaZero(this.projectionDelta);
                const transformTemplate = this.getTransformTemplate();
                const transformTemplateValue = transformTemplate
                    ? transformTemplate(this.latestValues, "")
                    : undefined;
                const transformTemplateHasChanged = transformTemplateValue !== this.prevTransformTemplateValue;
                if (isResetRequested &&
                    this.instance &&
                    (hasProjection ||
                        hasTransform(this.latestValues) ||
                        transformTemplateHasChanged)) {
                    resetTransform(this.instance, transformTemplateValue);
                    this.shouldResetTransform = false;
                    this.scheduleRender();
                }
            }
            measure(removeTransform = true) {
                const pageBox = this.measurePageBox();
                let layoutBox = this.removeElementScroll(pageBox);
                /**
                 * Measurements taken during the pre-render stage
                 * still have transforms applied so we remove them
                 * via calculation.
                 */
                if (removeTransform) {
                    layoutBox = this.removeTransform(layoutBox);
                }
                roundBox(layoutBox);
                return {
                    animationId: this.root.animationId,
                    measuredBox: pageBox,
                    layoutBox,
                    latestValues: {},
                    source: this.id,
                };
            }
            measurePageBox() {
                const { visualElement } = this.options;
                if (!visualElement)
                    return createBox();
                const box = visualElement.measureViewportBox();
                const wasInScrollRoot = this.scroll?.wasRoot || this.path.some(checkNodeWasScrollRoot);
                if (!wasInScrollRoot) {
                    // Remove viewport scroll to give page-relative coordinates
                    const { scroll } = this.root;
                    if (scroll) {
                        translateAxis(box.x, scroll.offset.x);
                        translateAxis(box.y, scroll.offset.y);
                    }
                }
                return box;
            }
            removeElementScroll(box) {
                const boxWithoutScroll = createBox();
                copyBoxInto(boxWithoutScroll, box);
                if (this.scroll?.wasRoot) {
                    return boxWithoutScroll;
                }
                /**
                 * Performance TODO: Keep a cumulative scroll offset down the tree
                 * rather than loop back up the path.
                 */
                for (let i = 0; i < this.path.length; i++) {
                    const node = this.path[i];
                    const { scroll, options } = node;
                    if (node !== this.root && scroll && options.layoutScroll) {
                        /**
                         * If this is a new scroll root, we want to remove all previous scrolls
                         * from the viewport box.
                         */
                        if (scroll.wasRoot) {
                            copyBoxInto(boxWithoutScroll, box);
                        }
                        translateAxis(boxWithoutScroll.x, scroll.offset.x);
                        translateAxis(boxWithoutScroll.y, scroll.offset.y);
                    }
                }
                return boxWithoutScroll;
            }
            applyTransform(box, transformOnly = false) {
                const withTransforms = createBox();
                copyBoxInto(withTransforms, box);
                for (let i = 0; i < this.path.length; i++) {
                    const node = this.path[i];
                    if (!transformOnly &&
                        node.options.layoutScroll &&
                        node.scroll &&
                        node !== node.root) {
                        transformBox(withTransforms, {
                            x: -node.scroll.offset.x,
                            y: -node.scroll.offset.y,
                        });
                    }
                    if (!hasTransform(node.latestValues))
                        continue;
                    transformBox(withTransforms, node.latestValues);
                }
                if (hasTransform(this.latestValues)) {
                    transformBox(withTransforms, this.latestValues);
                }
                return withTransforms;
            }
            removeTransform(box) {
                const boxWithoutTransform = createBox();
                copyBoxInto(boxWithoutTransform, box);
                for (let i = 0; i < this.path.length; i++) {
                    const node = this.path[i];
                    if (!node.instance)
                        continue;
                    if (!hasTransform(node.latestValues))
                        continue;
                    hasScale(node.latestValues) && node.updateSnapshot();
                    const sourceBox = createBox();
                    const nodeBox = node.measurePageBox();
                    copyBoxInto(sourceBox, nodeBox);
                    removeBoxTransforms(boxWithoutTransform, node.latestValues, node.snapshot ? node.snapshot.layoutBox : undefined, sourceBox);
                }
                if (hasTransform(this.latestValues)) {
                    removeBoxTransforms(boxWithoutTransform, this.latestValues);
                }
                return boxWithoutTransform;
            }
            setTargetDelta(delta) {
                this.targetDelta = delta;
                this.root.scheduleUpdateProjection();
                this.isProjectionDirty = true;
            }
            setOptions(options) {
                this.options = {
                    ...this.options,
                    ...options,
                    crossfade: options.crossfade !== undefined ? options.crossfade : true,
                };
            }
            clearMeasurements() {
                this.scroll = undefined;
                this.layout = undefined;
                this.snapshot = undefined;
                this.prevTransformTemplateValue = undefined;
                this.targetDelta = undefined;
                this.target = undefined;
                this.isLayoutDirty = false;
            }
            forceRelativeParentToResolveTarget() {
                if (!this.relativeParent)
                    return;
                /**
                 * If the parent target isn't up-to-date, force it to update.
                 * This is an unfortunate de-optimisation as it means any updating relative
                 * projection will cause all the relative parents to recalculate back
                 * up the tree.
                 */
                if (this.relativeParent.resolvedRelativeTargetAt !==
                    frameData.timestamp) {
                    this.relativeParent.resolveTargetDelta(true);
                }
            }
            resolveTargetDelta(forceRecalculation = false) {
                /**
                 * Once the dirty status of nodes has been spread through the tree, we also
                 * need to check if we have a shared node of a different depth that has itself
                 * been dirtied.
                 */
                const lead = this.getLead();
                this.isProjectionDirty || (this.isProjectionDirty = lead.isProjectionDirty);
                this.isTransformDirty || (this.isTransformDirty = lead.isTransformDirty);
                this.isSharedProjectionDirty || (this.isSharedProjectionDirty = lead.isSharedProjectionDirty);
                const isShared = Boolean(this.resumingFrom) || this !== lead;
                /**
                 * We don't use transform for this step of processing so we don't
                 * need to check whether any nodes have changed transform.
                 */
                const canSkip = !(forceRecalculation ||
                    (isShared && this.isSharedProjectionDirty) ||
                    this.isProjectionDirty ||
                    this.parent?.isProjectionDirty ||
                    this.attemptToResolveRelativeTarget ||
                    this.root.updateBlockedByResize);
                if (canSkip)
                    return;
                const { layout, layoutId } = this.options;
                /**
                 * If we have no layout, we can't perform projection, so early return
                 */
                if (!this.layout || !(layout || layoutId))
                    return;
                this.resolvedRelativeTargetAt = frameData.timestamp;
                const relativeParent = this.getClosestProjectingParent();
                if (relativeParent &&
                    this.linkedParentVersion !== relativeParent.layoutVersion &&
                    !relativeParent.options.layoutRoot) {
                    this.removeRelativeTarget();
                }
                /**
                 * If we don't have a targetDelta but do have a layout, we can attempt to resolve
                 * a relativeParent. This will allow a component to perform scale correction
                 * even if no animation has started.
                 */
                if (!this.targetDelta && !this.relativeTarget) {
                    if (relativeParent && relativeParent.layout) {
                        this.createRelativeTarget(relativeParent, this.layout.layoutBox, relativeParent.layout.layoutBox);
                    }
                    else {
                        this.removeRelativeTarget();
                    }
                }
                /**
                 * If we have no relative target or no target delta our target isn't valid
                 * for this frame.
                 */
                if (!this.relativeTarget && !this.targetDelta)
                    return;
                /**
                 * Lazy-init target data structure
                 */
                if (!this.target) {
                    this.target = createBox();
                    this.targetWithTransforms = createBox();
                }
                /**
                 * If we've got a relative box for this component, resolve it into a target relative to the parent.
                 */
                if (this.relativeTarget &&
                    this.relativeTargetOrigin &&
                    this.relativeParent &&
                    this.relativeParent.target) {
                    this.forceRelativeParentToResolveTarget();
                    calcRelativeBox(this.target, this.relativeTarget, this.relativeParent.target);
                    /**
                     * If we've only got a targetDelta, resolve it into a target
                     */
                }
                else if (this.targetDelta) {
                    if (Boolean(this.resumingFrom)) {
                        // TODO: This is creating a new object every frame
                        this.target = this.applyTransform(this.layout.layoutBox);
                    }
                    else {
                        copyBoxInto(this.target, this.layout.layoutBox);
                    }
                    applyBoxDelta(this.target, this.targetDelta);
                }
                else {
                    /**
                     * If no target, use own layout as target
                     */
                    copyBoxInto(this.target, this.layout.layoutBox);
                }
                /**
                 * If we've been told to attempt to resolve a relative target, do so.
                 */
                if (this.attemptToResolveRelativeTarget) {
                    this.attemptToResolveRelativeTarget = false;
                    if (relativeParent &&
                        Boolean(relativeParent.resumingFrom) ===
                            Boolean(this.resumingFrom) &&
                        !relativeParent.options.layoutScroll &&
                        relativeParent.target &&
                        this.animationProgress !== 1) {
                        this.createRelativeTarget(relativeParent, this.target, relativeParent.target);
                    }
                    else {
                        this.relativeParent = this.relativeTarget = undefined;
                    }
                }
                /**
                 * Increase debug counter for resolved target deltas
                 */
                if (statsBuffer.value) {
                    metrics.calculatedTargetDeltas++;
                }
            }
            getClosestProjectingParent() {
                if (!this.parent ||
                    hasScale(this.parent.latestValues) ||
                    has2DTranslate(this.parent.latestValues)) {
                    return undefined;
                }
                if (this.parent.isProjecting()) {
                    return this.parent;
                }
                else {
                    return this.parent.getClosestProjectingParent();
                }
            }
            isProjecting() {
                return Boolean((this.relativeTarget ||
                    this.targetDelta ||
                    this.options.layoutRoot) &&
                    this.layout);
            }
            createRelativeTarget(relativeParent, layout, parentLayout) {
                this.relativeParent = relativeParent;
                this.linkedParentVersion = relativeParent.layoutVersion;
                this.forceRelativeParentToResolveTarget();
                this.relativeTarget = createBox();
                this.relativeTargetOrigin = createBox();
                calcRelativePosition(this.relativeTargetOrigin, layout, parentLayout);
                copyBoxInto(this.relativeTarget, this.relativeTargetOrigin);
            }
            removeRelativeTarget() {
                this.relativeParent = this.relativeTarget = undefined;
            }
            calcProjection() {
                const lead = this.getLead();
                const isShared = Boolean(this.resumingFrom) || this !== lead;
                let canSkip = true;
                /**
                 * If this is a normal layout animation and neither this node nor its nearest projecting
                 * is dirty then we can't skip.
                 */
                if (this.isProjectionDirty || this.parent?.isProjectionDirty) {
                    canSkip = false;
                }
                /**
                 * If this is a shared layout animation and this node's shared projection is dirty then
                 * we can't skip.
                 */
                if (isShared &&
                    (this.isSharedProjectionDirty || this.isTransformDirty)) {
                    canSkip = false;
                }
                /**
                 * If we have resolved the target this frame we must recalculate the
                 * projection to ensure it visually represents the internal calculations.
                 */
                if (this.resolvedRelativeTargetAt === frameData.timestamp) {
                    canSkip = false;
                }
                if (canSkip)
                    return;
                const { layout, layoutId } = this.options;
                /**
                 * If this section of the tree isn't animating we can
                 * delete our target sources for the following frame.
                 */
                this.isTreeAnimating = Boolean((this.parent && this.parent.isTreeAnimating) ||
                    this.currentAnimation ||
                    this.pendingAnimation);
                if (!this.isTreeAnimating) {
                    this.targetDelta = this.relativeTarget = undefined;
                }
                if (!this.layout || !(layout || layoutId))
                    return;
                /**
                 * Reset the corrected box with the latest values from box, as we're then going
                 * to perform mutative operations on it.
                 */
                copyBoxInto(this.layoutCorrected, this.layout.layoutBox);
                /**
                 * Record previous tree scales before updating.
                 */
                const prevTreeScaleX = this.treeScale.x;
                const prevTreeScaleY = this.treeScale.y;
                /**
                 * Apply all the parent deltas to this box to produce the corrected box. This
                 * is the layout box, as it will appear on screen as a result of the transforms of its parents.
                 */
                applyTreeDeltas(this.layoutCorrected, this.treeScale, this.path, isShared);
                /**
                 * If this layer needs to perform scale correction but doesn't have a target,
                 * use the layout as the target.
                 */
                if (lead.layout &&
                    !lead.target &&
                    (this.treeScale.x !== 1 || this.treeScale.y !== 1)) {
                    lead.target = lead.layout.layoutBox;
                    lead.targetWithTransforms = createBox();
                }
                const { target } = lead;
                if (!target) {
                    /**
                     * If we don't have a target to project into, but we were previously
                     * projecting, we want to remove the stored transform and schedule
                     * a render to ensure the elements reflect the removed transform.
                     */
                    if (this.prevProjectionDelta) {
                        this.createProjectionDeltas();
                        this.scheduleRender();
                    }
                    return;
                }
                if (!this.projectionDelta || !this.prevProjectionDelta) {
                    this.createProjectionDeltas();
                }
                else {
                    copyAxisDeltaInto(this.prevProjectionDelta.x, this.projectionDelta.x);
                    copyAxisDeltaInto(this.prevProjectionDelta.y, this.projectionDelta.y);
                }
                /**
                 * Update the delta between the corrected box and the target box before user-set transforms were applied.
                 * This will allow us to calculate the corrected borderRadius and boxShadow to compensate
                 * for our layout reprojection, but still allow them to be scaled correctly by the user.
                 * It might be that to simplify this we may want to accept that user-set scale is also corrected
                 * and we wouldn't have to keep and calc both deltas, OR we could support a user setting
                 * to allow people to choose whether these styles are corrected based on just the
                 * layout reprojection or the final bounding box.
                 */
                calcBoxDelta(this.projectionDelta, this.layoutCorrected, target, this.latestValues);
                if (this.treeScale.x !== prevTreeScaleX ||
                    this.treeScale.y !== prevTreeScaleY ||
                    !axisDeltaEquals(this.projectionDelta.x, this.prevProjectionDelta.x) ||
                    !axisDeltaEquals(this.projectionDelta.y, this.prevProjectionDelta.y)) {
                    this.hasProjected = true;
                    this.scheduleRender();
                    this.notifyListeners("projectionUpdate", target);
                }
                /**
                 * Increase debug counter for recalculated projections
                 */
                if (statsBuffer.value) {
                    metrics.calculatedProjections++;
                }
            }
            hide() {
                this.isVisible = false;
                // TODO: Schedule render
            }
            show() {
                this.isVisible = true;
                // TODO: Schedule render
            }
            scheduleRender(notifyAll = true) {
                this.options.visualElement?.scheduleRender();
                if (notifyAll) {
                    const stack = this.getStack();
                    stack && stack.scheduleRender();
                }
                if (this.resumingFrom && !this.resumingFrom.instance) {
                    this.resumingFrom = undefined;
                }
            }
            createProjectionDeltas() {
                this.prevProjectionDelta = createDelta();
                this.projectionDelta = createDelta();
                this.projectionDeltaWithTransform = createDelta();
            }
            setAnimationOrigin(delta, hasOnlyRelativeTargetChanged = false) {
                const snapshot = this.snapshot;
                const snapshotLatestValues = snapshot ? snapshot.latestValues : {};
                const mixedValues = { ...this.latestValues };
                const targetDelta = createDelta();
                if (!this.relativeParent ||
                    !this.relativeParent.options.layoutRoot) {
                    this.relativeTarget = this.relativeTargetOrigin = undefined;
                }
                this.attemptToResolveRelativeTarget = !hasOnlyRelativeTargetChanged;
                const relativeLayout = createBox();
                const snapshotSource = snapshot ? snapshot.source : undefined;
                const layoutSource = this.layout ? this.layout.source : undefined;
                const isSharedLayoutAnimation = snapshotSource !== layoutSource;
                const stack = this.getStack();
                const isOnlyMember = !stack || stack.members.length <= 1;
                const shouldCrossfadeOpacity = Boolean(isSharedLayoutAnimation &&
                    !isOnlyMember &&
                    this.options.crossfade === true &&
                    !this.path.some(hasOpacityCrossfade));
                this.animationProgress = 0;
                let prevRelativeTarget;
                this.mixTargetDelta = (latest) => {
                    const progress = latest / 1000;
                    mixAxisDelta(targetDelta.x, delta.x, progress);
                    mixAxisDelta(targetDelta.y, delta.y, progress);
                    this.setTargetDelta(targetDelta);
                    if (this.relativeTarget &&
                        this.relativeTargetOrigin &&
                        this.layout &&
                        this.relativeParent &&
                        this.relativeParent.layout) {
                        calcRelativePosition(relativeLayout, this.layout.layoutBox, this.relativeParent.layout.layoutBox);
                        mixBox(this.relativeTarget, this.relativeTargetOrigin, relativeLayout, progress);
                        /**
                         * If this is an unchanged relative target we can consider the
                         * projection not dirty.
                         */
                        if (prevRelativeTarget &&
                            boxEquals(this.relativeTarget, prevRelativeTarget)) {
                            this.isProjectionDirty = false;
                        }
                        if (!prevRelativeTarget)
                            prevRelativeTarget = createBox();
                        copyBoxInto(prevRelativeTarget, this.relativeTarget);
                    }
                    if (isSharedLayoutAnimation) {
                        this.animationValues = mixedValues;
                        mixValues(mixedValues, snapshotLatestValues, this.latestValues, progress, shouldCrossfadeOpacity, isOnlyMember);
                    }
                    this.root.scheduleUpdateProjection();
                    this.scheduleRender();
                    this.animationProgress = progress;
                };
                this.mixTargetDelta(this.options.layoutRoot ? 1000 : 0);
            }
            startAnimation(options) {
                this.notifyListeners("animationStart");
                this.currentAnimation?.stop();
                this.resumingFrom?.currentAnimation?.stop();
                if (this.pendingAnimation) {
                    cancelFrame(this.pendingAnimation);
                    this.pendingAnimation = undefined;
                }
                /**
                 * Start the animation in the next frame to have a frame with progress 0,
                 * where the target is the same as when the animation started, so we can
                 * calculate the relative positions correctly for instant transitions.
                 */
                this.pendingAnimation = frame.update(() => {
                    globalProjectionState.hasAnimatedSinceResize = true;
                    activeAnimations.layout++;
                    this.motionValue || (this.motionValue = motionValue(0));
                    this.currentAnimation = animateSingleValue(this.motionValue, [0, 1000], {
                        ...options,
                        velocity: 0,
                        isSync: true,
                        onUpdate: (latest) => {
                            this.mixTargetDelta(latest);
                            options.onUpdate && options.onUpdate(latest);
                        },
                        onStop: () => {
                            activeAnimations.layout--;
                        },
                        onComplete: () => {
                            activeAnimations.layout--;
                            options.onComplete && options.onComplete();
                            this.completeAnimation();
                        },
                    });
                    if (this.resumingFrom) {
                        this.resumingFrom.currentAnimation = this.currentAnimation;
                    }
                    this.pendingAnimation = undefined;
                });
            }
            completeAnimation() {
                if (this.resumingFrom) {
                    this.resumingFrom.currentAnimation = undefined;
                    this.resumingFrom.preserveOpacity = undefined;
                }
                const stack = this.getStack();
                stack && stack.exitAnimationComplete();
                this.resumingFrom =
                    this.currentAnimation =
                        this.animationValues =
                            undefined;
                this.notifyListeners("animationComplete");
            }
            finishAnimation() {
                if (this.currentAnimation) {
                    this.mixTargetDelta && this.mixTargetDelta(animationTarget);
                    this.currentAnimation.stop();
                }
                this.completeAnimation();
            }
            applyTransformsToTarget() {
                const lead = this.getLead();
                let { targetWithTransforms, target, layout, latestValues } = lead;
                if (!targetWithTransforms || !target || !layout)
                    return;
                /**
                 * If we're only animating position, and this element isn't the lead element,
                 * then instead of projecting into the lead box we instead want to calculate
                 * a new target that aligns the two boxes but maintains the layout shape.
                 */
                if (this !== lead &&
                    this.layout &&
                    layout &&
                    shouldAnimatePositionOnly(this.options.animationType, this.layout.layoutBox, layout.layoutBox)) {
                    target = this.target || createBox();
                    const xLength = calcLength(this.layout.layoutBox.x);
                    target.x.min = lead.target.x.min;
                    target.x.max = target.x.min + xLength;
                    const yLength = calcLength(this.layout.layoutBox.y);
                    target.y.min = lead.target.y.min;
                    target.y.max = target.y.min + yLength;
                }
                copyBoxInto(targetWithTransforms, target);
                /**
                 * Apply the latest user-set transforms to the targetBox to produce the targetBoxFinal.
                 * This is the final box that we will then project into by calculating a transform delta and
                 * applying it to the corrected box.
                 */
                transformBox(targetWithTransforms, latestValues);
                /**
                 * Update the delta between the corrected box and the final target box, after
                 * user-set transforms are applied to it. This will be used by the renderer to
                 * create a transform style that will reproject the element from its layout layout
                 * into the desired bounding box.
                 */
                calcBoxDelta(this.projectionDeltaWithTransform, this.layoutCorrected, targetWithTransforms, latestValues);
            }
            registerSharedNode(layoutId, node) {
                if (!this.sharedNodes.has(layoutId)) {
                    this.sharedNodes.set(layoutId, new NodeStack());
                }
                const stack = this.sharedNodes.get(layoutId);
                stack.add(node);
                const config = node.options.initialPromotionConfig;
                node.promote({
                    transition: config ? config.transition : undefined,
                    preserveFollowOpacity: config && config.shouldPreserveFollowOpacity
                        ? config.shouldPreserveFollowOpacity(node)
                        : undefined,
                });
            }
            isLead() {
                const stack = this.getStack();
                return stack ? stack.lead === this : true;
            }
            getLead() {
                const { layoutId } = this.options;
                return layoutId ? this.getStack()?.lead || this : this;
            }
            getPrevLead() {
                const { layoutId } = this.options;
                return layoutId ? this.getStack()?.prevLead : undefined;
            }
            getStack() {
                const { layoutId } = this.options;
                if (layoutId)
                    return this.root.sharedNodes.get(layoutId);
            }
            promote({ needsReset, transition, preserveFollowOpacity, } = {}) {
                const stack = this.getStack();
                if (stack)
                    stack.promote(this, preserveFollowOpacity);
                if (needsReset) {
                    this.projectionDelta = undefined;
                    this.needsReset = true;
                }
                if (transition)
                    this.setOptions({ transition });
            }
            relegate() {
                const stack = this.getStack();
                if (stack) {
                    return stack.relegate(this);
                }
                else {
                    return false;
                }
            }
            resetSkewAndRotation() {
                const { visualElement } = this.options;
                if (!visualElement)
                    return;
                // If there's no detected skew or rotation values, we can early return without a forced render.
                let hasDistortingTransform = false;
                /**
                 * An unrolled check for rotation values. Most elements don't have any rotation and
                 * skipping the nested loop and new object creation is 50% faster.
                 */
                const { latestValues } = visualElement;
                if (latestValues.z ||
                    latestValues.rotate ||
                    latestValues.rotateX ||
                    latestValues.rotateY ||
                    latestValues.rotateZ ||
                    latestValues.skewX ||
                    latestValues.skewY) {
                    hasDistortingTransform = true;
                }
                // If there's no distorting values, we don't need to do any more.
                if (!hasDistortingTransform)
                    return;
                const resetValues = {};
                if (latestValues.z) {
                    resetDistortingTransform("z", visualElement, resetValues, this.animationValues);
                }
                // Check the skew and rotate value of all axes and reset to 0
                for (let i = 0; i < transformAxes.length; i++) {
                    resetDistortingTransform(`rotate${transformAxes[i]}`, visualElement, resetValues, this.animationValues);
                    resetDistortingTransform(`skew${transformAxes[i]}`, visualElement, resetValues, this.animationValues);
                }
                // Force a render of this element to apply the transform with all skews and rotations
                // set to 0.
                visualElement.render();
                // Put back all the values we reset
                for (const key in resetValues) {
                    visualElement.setStaticValue(key, resetValues[key]);
                    if (this.animationValues) {
                        this.animationValues[key] = resetValues[key];
                    }
                }
                // Schedule a render for the next frame. This ensures we won't visually
                // see the element with the reset rotate value applied.
                visualElement.scheduleRender();
            }
            applyProjectionStyles(targetStyle, // CSSStyleDeclaration - doesn't allow numbers to be assigned to properties
            styleProp) {
                if (!this.instance || this.isSVG)
                    return;
                if (!this.isVisible) {
                    targetStyle.visibility = "hidden";
                    return;
                }
                const transformTemplate = this.getTransformTemplate();
                if (this.needsReset) {
                    this.needsReset = false;
                    targetStyle.visibility = "";
                    targetStyle.opacity = "";
                    targetStyle.pointerEvents =
                        resolveMotionValue(styleProp?.pointerEvents) || "";
                    targetStyle.transform = transformTemplate
                        ? transformTemplate(this.latestValues, "")
                        : "none";
                    return;
                }
                const lead = this.getLead();
                if (!this.projectionDelta || !this.layout || !lead.target) {
                    if (this.options.layoutId) {
                        targetStyle.opacity =
                            this.latestValues.opacity !== undefined
                                ? this.latestValues.opacity
                                : 1;
                        targetStyle.pointerEvents =
                            resolveMotionValue(styleProp?.pointerEvents) || "";
                    }
                    if (this.hasProjected && !hasTransform(this.latestValues)) {
                        targetStyle.transform = transformTemplate
                            ? transformTemplate({}, "")
                            : "none";
                        this.hasProjected = false;
                    }
                    return;
                }
                targetStyle.visibility = "";
                const valuesToRender = lead.animationValues || lead.latestValues;
                this.applyTransformsToTarget();
                let transform = buildProjectionTransform(this.projectionDeltaWithTransform, this.treeScale, valuesToRender);
                if (transformTemplate) {
                    transform = transformTemplate(valuesToRender, transform);
                }
                targetStyle.transform = transform;
                const { x, y } = this.projectionDelta;
                targetStyle.transformOrigin = `${x.origin * 100}% ${y.origin * 100}% 0`;
                if (lead.animationValues) {
                    /**
                     * If the lead component is animating, assign this either the entering/leaving
                     * opacity
                     */
                    targetStyle.opacity =
                        lead === this
                            ? valuesToRender.opacity ??
                                this.latestValues.opacity ??
                                1
                            : this.preserveOpacity
                                ? this.latestValues.opacity
                                : valuesToRender.opacityExit;
                }
                else {
                    /**
                     * Or we're not animating at all, set the lead component to its layout
                     * opacity and other components to hidden.
                     */
                    targetStyle.opacity =
                        lead === this
                            ? valuesToRender.opacity !== undefined
                                ? valuesToRender.opacity
                                : ""
                            : valuesToRender.opacityExit !== undefined
                                ? valuesToRender.opacityExit
                                : 0;
                }
                /**
                 * Apply scale correction
                 */
                for (const key in scaleCorrectors) {
                    if (valuesToRender[key] === undefined)
                        continue;
                    const { correct, applyTo, isCSSVariable } = scaleCorrectors[key];
                    /**
                     * Only apply scale correction to the value if we have an
                     * active projection transform. Otherwise these values become
                     * vulnerable to distortion if the element changes size without
                     * a corresponding layout animation.
                     */
                    const corrected = transform === "none"
                        ? valuesToRender[key]
                        : correct(valuesToRender[key], lead);
                    if (applyTo) {
                        const num = applyTo.length;
                        for (let i = 0; i < num; i++) {
                            targetStyle[applyTo[i]] = corrected;
                        }
                    }
                    else {
                        // If this is a CSS variable, set it directly on the instance.
                        // Replacing this function from creating styles to setting them
                        // would be a good place to remove per frame object creation
                        if (isCSSVariable) {
                            this.options.visualElement.renderState.vars[key] = corrected;
                        }
                        else {
                            targetStyle[key] = corrected;
                        }
                    }
                }
                /**
                 * Disable pointer events on follow components. This is to ensure
                 * that if a follow component covers a lead component it doesn't block
                 * pointer events on the lead.
                 */
                if (this.options.layoutId) {
                    targetStyle.pointerEvents =
                        lead === this
                            ? resolveMotionValue(styleProp?.pointerEvents) || ""
                            : "none";
                }
            }
            clearSnapshot() {
                this.resumeFrom = this.snapshot = undefined;
            }
            // Only run on root
            resetTree() {
                this.root.nodes.forEach((node) => node.currentAnimation?.stop());
                this.root.nodes.forEach(clearMeasurements);
                this.root.sharedNodes.clear();
            }
        };
    }
    function updateLayout(node) {
        node.updateLayout();
    }
    function notifyLayoutUpdate(node) {
        const snapshot = node.resumeFrom?.snapshot || node.snapshot;
        if (node.isLead() &&
            node.layout &&
            snapshot &&
            node.hasListeners("didUpdate")) {
            const { layoutBox: layout, measuredBox: measuredLayout } = node.layout;
            const { animationType } = node.options;
            const isShared = snapshot.source !== node.layout.source;
            // TODO Maybe we want to also resize the layout snapshot so we don't trigger
            // animations for instance if layout="size" and an element has only changed position
            if (animationType === "size") {
                eachAxis((axis) => {
                    const axisSnapshot = isShared
                        ? snapshot.measuredBox[axis]
                        : snapshot.layoutBox[axis];
                    const length = calcLength(axisSnapshot);
                    axisSnapshot.min = layout[axis].min;
                    axisSnapshot.max = axisSnapshot.min + length;
                });
            }
            else if (shouldAnimatePositionOnly(animationType, snapshot.layoutBox, layout)) {
                eachAxis((axis) => {
                    const axisSnapshot = isShared
                        ? snapshot.measuredBox[axis]
                        : snapshot.layoutBox[axis];
                    const length = calcLength(layout[axis]);
                    axisSnapshot.max = axisSnapshot.min + length;
                    /**
                     * Ensure relative target gets resized and rerendererd
                     */
                    if (node.relativeTarget && !node.currentAnimation) {
                        node.isProjectionDirty = true;
                        node.relativeTarget[axis].max =
                            node.relativeTarget[axis].min + length;
                    }
                });
            }
            const layoutDelta = createDelta();
            calcBoxDelta(layoutDelta, layout, snapshot.layoutBox);
            const visualDelta = createDelta();
            if (isShared) {
                calcBoxDelta(visualDelta, node.applyTransform(measuredLayout, true), snapshot.measuredBox);
            }
            else {
                calcBoxDelta(visualDelta, layout, snapshot.layoutBox);
            }
            const hasLayoutChanged = !isDeltaZero(layoutDelta);
            let hasRelativeLayoutChanged = false;
            if (!node.resumeFrom) {
                const relativeParent = node.getClosestProjectingParent();
                /**
                 * If the relativeParent is itself resuming from a different element then
                 * the relative snapshot is not relavent
                 */
                if (relativeParent && !relativeParent.resumeFrom) {
                    const { snapshot: parentSnapshot, layout: parentLayout } = relativeParent;
                    if (parentSnapshot && parentLayout) {
                        const relativeSnapshot = createBox();
                        calcRelativePosition(relativeSnapshot, snapshot.layoutBox, parentSnapshot.layoutBox);
                        const relativeLayout = createBox();
                        calcRelativePosition(relativeLayout, layout, parentLayout.layoutBox);
                        if (!boxEqualsRounded(relativeSnapshot, relativeLayout)) {
                            hasRelativeLayoutChanged = true;
                        }
                        if (relativeParent.options.layoutRoot) {
                            node.relativeTarget = relativeLayout;
                            node.relativeTargetOrigin = relativeSnapshot;
                            node.relativeParent = relativeParent;
                        }
                    }
                }
            }
            node.notifyListeners("didUpdate", {
                layout,
                snapshot,
                delta: visualDelta,
                layoutDelta,
                hasLayoutChanged,
                hasRelativeLayoutChanged,
            });
        }
        else if (node.isLead()) {
            const { onExitComplete } = node.options;
            onExitComplete && onExitComplete();
        }
        /**
         * Clearing transition
         * TODO: Investigate why this transition is being passed in as {type: false } from Framer
         * and why we need it at all
         */
        node.options.transition = undefined;
    }
    function propagateDirtyNodes(node) {
        /**
         * Increase debug counter for nodes encountered this frame
         */
        if (statsBuffer.value) {
            metrics.nodes++;
        }
        if (!node.parent)
            return;
        /**
         * If this node isn't projecting, propagate isProjectionDirty. It will have
         * no performance impact but it will allow the next child that *is* projecting
         * but *isn't* dirty to just check its parent to see if *any* ancestor needs
         * correcting.
         */
        if (!node.isProjecting()) {
            node.isProjectionDirty = node.parent.isProjectionDirty;
        }
        /**
         * Propagate isSharedProjectionDirty and isTransformDirty
         * throughout the whole tree. A future revision can take another look at
         * this but for safety we still recalcualte shared nodes.
         */
        node.isSharedProjectionDirty || (node.isSharedProjectionDirty = Boolean(node.isProjectionDirty ||
            node.parent.isProjectionDirty ||
            node.parent.isSharedProjectionDirty));
        node.isTransformDirty || (node.isTransformDirty = node.parent.isTransformDirty);
    }
    function cleanDirtyNodes(node) {
        node.isProjectionDirty =
            node.isSharedProjectionDirty =
                node.isTransformDirty =
                    false;
    }
    function clearSnapshot(node) {
        node.clearSnapshot();
    }
    function clearMeasurements(node) {
        node.clearMeasurements();
    }
    function clearIsLayoutDirty(node) {
        node.isLayoutDirty = false;
    }
    function resetTransformStyle(node) {
        const { visualElement } = node.options;
        if (visualElement && visualElement.getProps().onBeforeLayoutMeasure) {
            visualElement.notify("BeforeLayoutMeasure");
        }
        node.resetTransform();
    }
    function finishAnimation(node) {
        node.finishAnimation();
        node.targetDelta = node.relativeTarget = node.target = undefined;
        node.isProjectionDirty = true;
    }
    function resolveTargetDelta(node) {
        node.resolveTargetDelta();
    }
    function calcProjection(node) {
        node.calcProjection();
    }
    function resetSkewAndRotation(node) {
        node.resetSkewAndRotation();
    }
    function removeLeadSnapshots(stack) {
        stack.removeLeadSnapshot();
    }
    function mixAxisDelta(output, delta, p) {
        output.translate = mixNumber$1(delta.translate, 0, p);
        output.scale = mixNumber$1(delta.scale, 1, p);
        output.origin = delta.origin;
        output.originPoint = delta.originPoint;
    }
    function mixAxis(output, from, to, p) {
        output.min = mixNumber$1(from.min, to.min, p);
        output.max = mixNumber$1(from.max, to.max, p);
    }
    function mixBox(output, from, to, p) {
        mixAxis(output.x, from.x, to.x, p);
        mixAxis(output.y, from.y, to.y, p);
    }
    function hasOpacityCrossfade(node) {
        return (node.animationValues && node.animationValues.opacityExit !== undefined);
    }
    const defaultLayoutTransition = {
        duration: 0.45,
        ease: [0.4, 0, 0.1, 1],
    };
    const userAgentContains = (string) => typeof navigator !== "undefined" &&
        navigator.userAgent &&
        navigator.userAgent.toLowerCase().includes(string);
    /**
     * Measured bounding boxes must be rounded in Safari and
     * left untouched in Chrome, otherwise non-integer layouts within scaled-up elements
     * can appear to jump.
     */
    const roundPoint = userAgentContains("applewebkit/") && !userAgentContains("chrome/")
        ? Math.round
        : motionUtils.noop;
    function roundAxis(axis) {
        // Round to the nearest .5 pixels to support subpixel layouts
        axis.min = roundPoint(axis.min);
        axis.max = roundPoint(axis.max);
    }
    function roundBox(box) {
        roundAxis(box.x);
        roundAxis(box.y);
    }
    function shouldAnimatePositionOnly(animationType, snapshot, layout) {
        return (animationType === "position" ||
            (animationType === "preserve-aspect" &&
                !isNear(aspectRatio(snapshot), aspectRatio(layout), 0.2)));
    }
    function checkNodeWasScrollRoot(node) {
        return node !== node.root && node.scroll?.wasRoot;
    }

    const DocumentProjectionNode = createProjectionNode$1({
        attachResizeListener: (ref, notify) => addDomEvent(ref, "resize", notify),
        measureScroll: () => ({
            x: document.documentElement.scrollLeft || document.body?.scrollLeft || 0,
            y: document.documentElement.scrollTop || document.body?.scrollTop || 0,
        }),
        checkIsScrollRoot: () => true,
    });

    const notify = (node) => !node.isLayoutDirty && node.willUpdate(false);
    function nodeGroup() {
        const nodes = new Set();
        const subscriptions = new WeakMap();
        const dirtyAll = () => nodes.forEach(notify);
        return {
            add: (node) => {
                nodes.add(node);
                subscriptions.set(node, node.addEventListener("willUpdate", dirtyAll));
            },
            remove: (node) => {
                nodes.delete(node);
                const unsubscribe = subscriptions.get(node);
                if (unsubscribe) {
                    unsubscribe();
                    subscriptions.delete(node);
                }
                dirtyAll();
            },
            dirty: dirtyAll,
        };
    }

    const rootProjectionNode = {
        current: undefined,
    };
    const HTMLProjectionNode = createProjectionNode$1({
        measureScroll: (instance) => ({
            x: instance.scrollLeft,
            y: instance.scrollTop,
        }),
        defaultParent: () => {
            if (!rootProjectionNode.current) {
                const documentNode = new DocumentProjectionNode({});
                documentNode.mount(window);
                documentNode.setOptions({ layoutScroll: true });
                rootProjectionNode.current = documentNode;
            }
            return rootProjectionNode.current;
        },
        resetTransform: (instance, value) => {
            instance.style.transform = value !== undefined ? value : "none";
        },
        checkIsScrollRoot: (instance) => Boolean(window.getComputedStyle(instance).position === "fixed"),
    });

    const LAYOUT_SELECTOR = "[data-layout], [data-layout-id]";
    function getLayoutElements(scope) {
        const elements = Array.from(scope.querySelectorAll(LAYOUT_SELECTOR));
        // Include scope itself if it's an Element (not Document) and has layout attributes
        if (scope instanceof Element && hasLayout(scope)) {
            elements.unshift(scope);
        }
        return elements;
    }
    function getLayoutId(element) {
        return element.getAttribute("data-layout-id");
    }
    function hasLayout(element) {
        return (element.hasAttribute("data-layout") ||
            element.hasAttribute("data-layout-id"));
    }

    let scaleCorrectorAdded = false;
    /**
     * Track active projection nodes per element to handle animation interruption.
     * When a new animation starts on an element that already has an active animation,
     * we need to stop the old animation so the new one can start from the current
     * visual position.
     */
    const activeProjectionNodes = new WeakMap();
    function ensureScaleCorrectors() {
        if (scaleCorrectorAdded)
            return;
        scaleCorrectorAdded = true;
        addScaleCorrector({
            borderRadius: {
                ...correctBorderRadius,
                applyTo: [
                    "borderTopLeftRadius",
                    "borderTopRightRadius",
                    "borderBottomLeftRadius",
                    "borderBottomRightRadius",
                ],
            },
            borderTopLeftRadius: correctBorderRadius,
            borderTopRightRadius: correctBorderRadius,
            borderBottomLeftRadius: correctBorderRadius,
            borderBottomRightRadius: correctBorderRadius,
            boxShadow: correctBoxShadow,
        });
    }
    /**
     * Get DOM depth of an element
     */
    function getDepth(element) {
        let depth = 0;
        let current = element.parentElement;
        while (current) {
            depth++;
            current = current.parentElement;
        }
        return depth;
    }
    /**
     * Find the closest projection parent for an element
     */
    function findProjectionParent(element, nodeCache) {
        let parent = element.parentElement;
        while (parent) {
            const node = nodeCache.get(parent);
            if (node)
                return node;
            parent = parent.parentElement;
        }
        return undefined;
    }
    /**
     * Create or reuse a projection node for an element
     */
    function createProjectionNode(element, parent, options, transition) {
        // Check for existing active node - reuse it to preserve animation state
        const existingNode = activeProjectionNodes.get(element);
        if (existingNode) {
            const visualElement = existingNode.options.visualElement;
            // Update transition options for the new animation
            const nodeTransition = transition
                ? { duration: transition.duration, ease: transition.ease }
                : { duration: 0.3, ease: "easeOut" };
            existingNode.setOptions({
                ...existingNode.options,
                animate: true,
                transition: nodeTransition,
                ...options,
            });
            // Re-mount the node if it was previously unmounted
            // This re-adds it to root.nodes so didUpdate() will process it
            if (!existingNode.instance) {
                existingNode.mount(element);
            }
            return { node: existingNode, visualElement };
        }
        // No existing node - create a new one
        const latestValues = {};
        const visualElement = new HTMLVisualElement({
            visualState: {
                latestValues,
                renderState: {
                    transformOrigin: {},
                    transform: {},
                    style: {},
                    vars: {},
                },
            },
            presenceContext: null,
            props: {},
        });
        const node = new HTMLProjectionNode(latestValues, parent);
        // Convert AnimationOptions to transition format for the projection system
        const nodeTransition = transition
            ? { duration: transition.duration, ease: transition.ease }
            : { duration: 0.3, ease: "easeOut" };
        node.setOptions({
            visualElement,
            layout: true,
            animate: true,
            transition: nodeTransition,
            ...options,
        });
        node.mount(element);
        visualElement.projection = node;
        // Track this node as the active one for this element
        activeProjectionNodes.set(element, node);
        return { node, visualElement };
    }
    /**
     * Build a projection tree from a list of elements
     */
    function buildProjectionTree(elements, existingContext, options) {
        ensureScaleCorrectors();
        const nodes = existingContext?.nodes ?? new Map();
        const visualElements = existingContext?.visualElements ?? new Map();
        const group = existingContext?.group ?? nodeGroup();
        const defaultTransition = options?.defaultTransition;
        const sharedTransitions = options?.sharedTransitions;
        // Sort elements by DOM depth (parents before children)
        const sorted = [...elements].sort((a, b) => getDepth(a) - getDepth(b));
        let root = existingContext?.root;
        for (const element of sorted) {
            // Skip if already has a node
            if (nodes.has(element))
                continue;
            const parent = findProjectionParent(element, nodes);
            const layoutId = getLayoutId(element);
            const layoutMode = element.getAttribute("data-layout");
            const nodeOptions = {
                layoutId: layoutId ?? undefined,
                animationType: parseLayoutMode(layoutMode),
            };
            // Use layoutId-specific transition if available, otherwise use default
            const transition = layoutId && sharedTransitions?.get(layoutId)
                ? sharedTransitions.get(layoutId)
                : defaultTransition;
            const { node, visualElement } = createProjectionNode(element, parent, nodeOptions, transition);
            nodes.set(element, node);
            visualElements.set(element, visualElement);
            group.add(node);
            if (!root) {
                root = node.root;
            }
        }
        return {
            nodes,
            visualElements,
            group,
            root: root,
        };
    }
    /**
     * Parse the data-layout attribute value
     */
    function parseLayoutMode(value) {
        if (value === "position")
            return "position";
        if (value === "size")
            return "size";
        if (value === "preserve-aspect")
            return "preserve-aspect";
        return "both";
    }
    /**
     * Clean up projection nodes for specific elements.
     * If elementsToCleanup is provided, only those elements are cleaned up.
     * If not provided, all nodes are cleaned up.
     *
     * This allows persisting elements to keep their nodes between animations,
     * matching React's behavior where nodes persist for elements that remain in the DOM.
     */
    function cleanupProjectionTree(context, elementsToCleanup) {
        const elementsToProcess = elementsToCleanup
            ? [...context.nodes.entries()].filter(([el]) => elementsToCleanup.has(el))
            : [...context.nodes.entries()];
        for (const [element, node] of elementsToProcess) {
            context.group.remove(node);
            node.unmount();
            // Only clear from activeProjectionNodes if this is still the active node.
            // A newer animation might have already taken over.
            if (activeProjectionNodes.get(element) === node) {
                activeProjectionNodes.delete(element);
            }
            context.nodes.delete(element);
            context.visualElements.delete(element);
        }
    }

    class LayoutAnimationBuilder {
        constructor(scope, updateDom, defaultOptions) {
            this.sharedTransitions = new Map();
            this.notifyReady = motionUtils.noop;
            this.executed = false;
            this.scope = scope;
            this.updateDom = updateDom;
            this.defaultOptions = defaultOptions;
            this.readyPromise = new Promise((resolve) => {
                this.notifyReady = resolve;
            });
            // Queue execution on microtask to allow builder methods to be called
            queueMicrotask(() => this.execute());
        }
        shared(id, options) {
            this.sharedTransitions.set(id, options);
            return this;
        }
        then(onfulfilled, onrejected) {
            return this.readyPromise.then(onfulfilled, onrejected);
        }
        async execute() {
            if (this.executed)
                return;
            this.executed = true;
            let context;
            // Phase 1: Pre-mutation - Build projection tree and take snapshots
            const beforeElements = getLayoutElements(this.scope);
            if (beforeElements.length > 0) {
                context = buildProjectionTree(beforeElements, undefined, this.getBuildOptions());
                context.root.startUpdate();
                for (const node of context.nodes.values()) {
                    node.isLayoutDirty = false;
                    node.willUpdate();
                }
            }
            // Phase 2: Execute DOM update
            this.updateDom();
            // Phase 3: Post-mutation - Compare before/after elements
            const afterElements = getLayoutElements(this.scope);
            const beforeSet = new Set(beforeElements);
            const afterSet = new Set(afterElements);
            const entering = afterElements.filter((el) => !beforeSet.has(el));
            const exiting = beforeElements.filter((el) => !afterSet.has(el));
            // Build projection nodes for entering elements
            if (entering.length > 0) {
                context = buildProjectionTree(entering, context, this.getBuildOptions());
            }
            // No layout elements - return empty animation
            if (!context) {
                this.notifyReady(new GroupAnimation([]));
                return;
            }
            // Handle shared elements
            for (const element of exiting) {
                const node = context.nodes.get(element);
                node?.getStack()?.remove(node);
            }
            for (const element of entering) {
                context.nodes.get(element)?.promote();
            }
            // Phase 4: Animate
            context.root.didUpdate();
            await new Promise((resolve) => frame.postRender(() => resolve()));
            const animations = [];
            for (const node of context.nodes.values()) {
                if (node.currentAnimation) {
                    animations.push(node.currentAnimation);
                }
            }
            const groupAnimation = new GroupAnimation(animations);
            groupAnimation.finished.then(() => {
                // Only clean up nodes for elements no longer in the document.
                // Elements still in DOM keep their nodes so subsequent animations
                // can use the stored position snapshots (A→B→A pattern).
                const elementsToCleanup = new Set();
                for (const element of context.nodes.keys()) {
                    if (!document.contains(element)) {
                        elementsToCleanup.add(element);
                    }
                }
                cleanupProjectionTree(context, elementsToCleanup);
            });
            this.notifyReady(groupAnimation);
        }
        getBuildOptions() {
            return {
                defaultTransition: this.defaultOptions || {
                    duration: 0.3,
                    ease: "easeOut",
                },
                sharedTransitions: this.sharedTransitions.size > 0
                    ? this.sharedTransitions
                    : undefined,
            };
        }
    }
    /**
     * Parse arguments for animateLayout overloads
     */
    function parseAnimateLayoutArgs(scopeOrUpdateDom, updateDomOrOptions, options) {
        // animateLayout(updateDom)
        if (typeof scopeOrUpdateDom === "function") {
            return {
                scope: document,
                updateDom: scopeOrUpdateDom,
                defaultOptions: updateDomOrOptions,
            };
        }
        // animateLayout(scope, updateDom, options?)
        const elements = resolveElements(scopeOrUpdateDom);
        const scope = elements[0] || document;
        return {
            scope: scope instanceof Document ? scope : scope,
            updateDom: updateDomOrOptions,
            defaultOptions: options,
        };
    }

    /**
     * @deprecated
     *
     * Import as `frame` instead.
     */
    const sync = frame;
    /**
     * @deprecated
     *
     * Use cancelFrame(callback) instead.
     */
    const cancelSync = stepsOrder.reduce((acc, key) => {
        acc[key] = (process) => cancelFrame(process);
        return acc;
    }, {});

    exports.AsyncMotionValueAnimation = AsyncMotionValueAnimation;
    exports.DOMKeyframesResolver = DOMKeyframesResolver;
    exports.DOMVisualElement = DOMVisualElement;
    exports.DocumentProjectionNode = DocumentProjectionNode;
    exports.Feature = Feature;
    exports.FlatTree = FlatTree;
    exports.GroupAnimation = GroupAnimation;
    exports.GroupAnimationWithThen = GroupAnimationWithThen;
    exports.HTMLProjectionNode = HTMLProjectionNode;
    exports.HTMLVisualElement = HTMLVisualElement;
    exports.JSAnimation = JSAnimation;
    exports.KeyframeResolver = KeyframeResolver;
    exports.LayoutAnimationBuilder = LayoutAnimationBuilder;
    exports.MotionValue = MotionValue;
    exports.NativeAnimation = NativeAnimation;
    exports.NativeAnimationExtended = NativeAnimationExtended;
    exports.NativeAnimationWrapper = NativeAnimationWrapper;
    exports.NodeStack = NodeStack;
    exports.ObjectVisualElement = ObjectVisualElement;
    exports.SVGVisualElement = SVGVisualElement;
    exports.ViewTransitionBuilder = ViewTransitionBuilder;
    exports.VisualElement = VisualElement;
    exports.acceleratedValues = acceleratedValues;
    exports.activeAnimations = activeAnimations;
    exports.addAttrValue = addAttrValue;
    exports.addDomEvent = addDomEvent;
    exports.addScaleCorrector = addScaleCorrector;
    exports.addStyleValue = addStyleValue;
    exports.addValueToWillChange = addValueToWillChange;
    exports.alpha = alpha;
    exports.analyseComplexValue = analyseComplexValue;
    exports.animateMotionValue = animateMotionValue;
    exports.animateSingleValue = animateSingleValue;
    exports.animateTarget = animateTarget;
    exports.animateValue = animateValue;
    exports.animateVariant = animateVariant;
    exports.animateView = animateView;
    exports.animateVisualElement = animateVisualElement;
    exports.animationMapKey = animationMapKey;
    exports.applyAxisDelta = applyAxisDelta;
    exports.applyBoxDelta = applyBoxDelta;
    exports.applyGeneratorOptions = applyGeneratorOptions;
    exports.applyPointDelta = applyPointDelta;
    exports.applyPxDefaults = applyPxDefaults;
    exports.applyTreeDeltas = applyTreeDeltas;
    exports.aspectRatio = aspectRatio;
    exports.attachSpring = attachSpring;
    exports.attrEffect = attrEffect;
    exports.axisDeltaEquals = axisDeltaEquals;
    exports.axisEquals = axisEquals;
    exports.axisEqualsRounded = axisEqualsRounded;
    exports.boxEquals = boxEquals;
    exports.boxEqualsRounded = boxEqualsRounded;
    exports.buildHTMLStyles = buildHTMLStyles;
    exports.buildProjectionTransform = buildProjectionTransform;
    exports.buildSVGAttrs = buildSVGAttrs;
    exports.buildSVGPath = buildSVGPath;
    exports.buildTransform = buildTransform;
    exports.calcAxisDelta = calcAxisDelta;
    exports.calcBoxDelta = calcBoxDelta;
    exports.calcChildStagger = calcChildStagger;
    exports.calcGeneratorDuration = calcGeneratorDuration;
    exports.calcLength = calcLength;
    exports.calcRelativeAxis = calcRelativeAxis;
    exports.calcRelativeAxisPosition = calcRelativeAxisPosition;
    exports.calcRelativeBox = calcRelativeBox;
    exports.calcRelativePosition = calcRelativePosition;
    exports.camelCaseAttributes = camelCaseAttributes;
    exports.camelToDash = camelToDash;
    exports.cancelFrame = cancelFrame;
    exports.cancelMicrotask = cancelMicrotask;
    exports.cancelSync = cancelSync;
    exports.checkVariantsDidChange = checkVariantsDidChange;
    exports.cleanDirtyNodes = cleanDirtyNodes;
    exports.collectMotionValues = collectMotionValues;
    exports.color = color;
    exports.compareByDepth = compareByDepth;
    exports.complex = complex;
    exports.containsCSSVariable = containsCSSVariable;
    exports.convertBoundingBoxToBox = convertBoundingBoxToBox;
    exports.convertBoxToBoundingBox = convertBoxToBoundingBox;
    exports.convertOffsetToTimes = convertOffsetToTimes;
    exports.copyAxisDeltaInto = copyAxisDeltaInto;
    exports.copyAxisInto = copyAxisInto;
    exports.copyBoxInto = copyBoxInto;
    exports.correctBorderRadius = correctBorderRadius;
    exports.correctBoxShadow = correctBoxShadow;
    exports.createAnimationState = createAnimationState;
    exports.createAxis = createAxis;
    exports.createAxisDelta = createAxisDelta;
    exports.createBox = createBox;
    exports.createDelta = createDelta;
    exports.createGeneratorEasing = createGeneratorEasing;
    exports.createProjectionNode = createProjectionNode$1;
    exports.createRenderBatcher = createRenderBatcher;
    exports.cubicBezierAsString = cubicBezierAsString;
    exports.defaultEasing = defaultEasing;
    exports.defaultOffset = defaultOffset;
    exports.defaultTransformValue = defaultTransformValue;
    exports.defaultValueTypes = defaultValueTypes;
    exports.degrees = degrees;
    exports.delay = delay;
    exports.delayInSeconds = delayInSeconds;
    exports.dimensionValueTypes = dimensionValueTypes;
    exports.eachAxis = eachAxis;
    exports.fillOffset = fillOffset;
    exports.fillWildcards = fillWildcards;
    exports.findDimensionValueType = findDimensionValueType;
    exports.findValueType = findValueType;
    exports.flushKeyframeResolvers = flushKeyframeResolvers;
    exports.frame = frame;
    exports.frameData = frameData;
    exports.frameSteps = frameSteps;
    exports.generateLinearEasing = generateLinearEasing;
    exports.getAnimatableNone = getAnimatableNone;
    exports.getAnimationMap = getAnimationMap;
    exports.getComputedStyle = getComputedStyle$2;
    exports.getDefaultTransition = getDefaultTransition;
    exports.getDefaultValueType = getDefaultValueType;
    exports.getFeatureDefinitions = getFeatureDefinitions;
    exports.getFinalKeyframe = getFinalKeyframe;
    exports.getMixer = getMixer;
    exports.getOptimisedAppearId = getOptimisedAppearId;
    exports.getOriginIndex = getOriginIndex;
    exports.getValueAsType = getValueAsType;
    exports.getValueTransition = getValueTransition;
    exports.getVariableValue = getVariableValue;
    exports.getVariantContext = getVariantContext;
    exports.getViewAnimationLayerInfo = getViewAnimationLayerInfo;
    exports.getViewAnimations = getViewAnimations;
    exports.globalProjectionState = globalProjectionState;
    exports.has2DTranslate = has2DTranslate;
    exports.hasReducedMotionListener = hasReducedMotionListener;
    exports.hasScale = hasScale;
    exports.hasTransform = hasTransform;
    exports.hex = hex;
    exports.hover = hover;
    exports.hsla = hsla;
    exports.hslaToRgba = hslaToRgba;
    exports.inertia = inertia;
    exports.initPrefersReducedMotion = initPrefersReducedMotion;
    exports.interpolate = interpolate;
    exports.invisibleValues = invisibleValues;
    exports.isAnimationControls = isAnimationControls;
    exports.isCSSVariableName = isCSSVariableName;
    exports.isCSSVariableToken = isCSSVariableToken;
    exports.isControllingVariants = isControllingVariants;
    exports.isDeltaZero = isDeltaZero;
    exports.isDragActive = isDragActive;
    exports.isDragging = isDragging;
    exports.isElementKeyboardAccessible = isElementKeyboardAccessible;
    exports.isForcedMotionValue = isForcedMotionValue;
    exports.isGenerator = isGenerator;
    exports.isHTMLElement = isHTMLElement;
    exports.isKeyframesTarget = isKeyframesTarget;
    exports.isMotionValue = isMotionValue;
    exports.isNear = isNear;
    exports.isNodeOrChild = isNodeOrChild;
    exports.isPrimaryPointer = isPrimaryPointer;
    exports.isSVGElement = isSVGElement;
    exports.isSVGSVGElement = isSVGSVGElement;
    exports.isSVGTag = isSVGTag;
    exports.isTransitionDefined = isTransitionDefined;
    exports.isVariantLabel = isVariantLabel;
    exports.isVariantNode = isVariantNode;
    exports.isWaapiSupportedEasing = isWaapiSupportedEasing;
    exports.isWillChangeMotionValue = isWillChangeMotionValue;
    exports.keyframes = keyframes;
    exports.makeAnimationInstant = makeAnimationInstant;
    exports.mapEasingToNativeEasing = mapEasingToNativeEasing;
    exports.mapValue = mapValue;
    exports.maxGeneratorDuration = maxGeneratorDuration;
    exports.measurePageBox = measurePageBox;
    exports.measureViewportBox = measureViewportBox;
    exports.microtask = microtask;
    exports.mix = mix;
    exports.mixArray = mixArray;
    exports.mixColor = mixColor;
    exports.mixComplex = mixComplex;
    exports.mixImmediate = mixImmediate;
    exports.mixLinearColor = mixLinearColor;
    exports.mixNumber = mixNumber$1;
    exports.mixObject = mixObject;
    exports.mixValues = mixValues;
    exports.mixVisibility = mixVisibility;
    exports.motionValue = motionValue;
    exports.nodeGroup = nodeGroup;
    exports.number = number;
    exports.numberValueTypes = numberValueTypes;
    exports.observeTimeline = observeTimeline;
    exports.optimizedAppearDataAttribute = optimizedAppearDataAttribute;
    exports.optimizedAppearDataId = optimizedAppearDataId;
    exports.parseAnimateLayoutArgs = parseAnimateLayoutArgs;
    exports.parseCSSVariable = parseCSSVariable;
    exports.parseValueFromTransform = parseValueFromTransform;
    exports.percent = percent;
    exports.pixelsToPercent = pixelsToPercent;
    exports.positionalKeys = positionalKeys;
    exports.prefersReducedMotion = prefersReducedMotion;
    exports.press = press;
    exports.progressPercentage = progressPercentage;
    exports.propEffect = propEffect;
    exports.propagateDirtyNodes = propagateDirtyNodes;
    exports.px = px;
    exports.readTransformValue = readTransformValue;
    exports.recordStats = recordStats;
    exports.removeAxisDelta = removeAxisDelta;
    exports.removeAxisTransforms = removeAxisTransforms;
    exports.removeBoxTransforms = removeBoxTransforms;
    exports.removePointDelta = removePointDelta;
    exports.renderHTML = renderHTML;
    exports.renderSVG = renderSVG;
    exports.resize = resize;
    exports.resolveElements = resolveElements;
    exports.resolveMotionValue = resolveMotionValue;
    exports.resolveVariant = resolveVariant;
    exports.resolveVariantFromProps = resolveVariantFromProps;
    exports.rgbUnit = rgbUnit;
    exports.rgba = rgba;
    exports.rootProjectionNode = rootProjectionNode;
    exports.scale = scale;
    exports.scaleCorrectors = scaleCorrectors;
    exports.scalePoint = scalePoint;
    exports.scrapeHTMLMotionValuesFromProps = scrapeMotionValuesFromProps$1;
    exports.scrapeSVGMotionValuesFromProps = scrapeMotionValuesFromProps;
    exports.setDragLock = setDragLock;
    exports.setFeatureDefinitions = setFeatureDefinitions;
    exports.setStyle = setStyle;
    exports.setTarget = setTarget;
    exports.spring = spring;
    exports.springValue = springValue;
    exports.stagger = stagger;
    exports.startWaapiAnimation = startWaapiAnimation;
    exports.statsBuffer = statsBuffer;
    exports.styleEffect = styleEffect;
    exports.supportedWaapiEasing = supportedWaapiEasing;
    exports.supportsBrowserAnimation = supportsBrowserAnimation;
    exports.supportsFlags = supportsFlags;
    exports.supportsLinearEasing = supportsLinearEasing;
    exports.supportsPartialKeyframes = supportsPartialKeyframes;
    exports.supportsScrollTimeline = supportsScrollTimeline;
    exports.svgEffect = svgEffect;
    exports.sync = sync;
    exports.testValueType = testValueType;
    exports.time = time;
    exports.transform = transform;
    exports.transformAxis = transformAxis;
    exports.transformBox = transformBox;
    exports.transformBoxPoints = transformBoxPoints;
    exports.transformPropOrder = transformPropOrder;
    exports.transformProps = transformProps;
    exports.transformValue = transformValue;
    exports.transformValueTypes = transformValueTypes;
    exports.translateAxis = translateAxis;
    exports.updateMotionValuesFromProps = updateMotionValuesFromProps;
    exports.variantPriorityOrder = variantPriorityOrder;
    exports.variantProps = variantProps;
    exports.vh = vh;
    exports.visualElementStore = visualElementStore;
    exports.vw = vw;

}));
