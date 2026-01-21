import * as motion_utils from 'motion-utils';
import { Point, BoundingBox, Axis, Box, TransformPoint, Easing, EasingFunction, BezierDefinition, Delta, AxisDelta, SubscriptionManager } from 'motion-utils';

/**
 * Passed in to pan event handlers like `onPan` the `PanInfo` object contains
 * information about the current state of the tap gesture such as its
 * `point`, `delta`, `offset` and `velocity`.
 *
 * ```jsx
 * <motion.div onPan={(event, info) => {
 *   console.log(info.point.x, info.point.y)
 * }} />
 * ```
 *
 * @public
 */
interface PanInfo {
    /**
     * Contains `x` and `y` values for the current pan position relative
     * to the device or page.
     *
     * ```jsx
     * function onPan(event, info) {
     *   console.log(info.point.x, info.point.y)
     * }
     *
     * <motion.div onPan={onPan} />
     * ```
     *
     * @public
     */
    point: Point;
    /**
     * Contains `x` and `y` values for the distance moved since
     * the last event.
     *
     * ```jsx
     * function onPan(event, info) {
     *   console.log(info.delta.x, info.delta.y)
     * }
     *
     * <motion.div onPan={onPan} />
     * ```
     *
     * @public
     */
    delta: Point;
    /**
     * Contains `x` and `y` values for the distance moved from
     * the first pan event.
     *
     * ```jsx
     * function onPan(event, info) {
     *   console.log(info.offset.x, info.offset.y)
     * }
     *
     * <motion.div onPan={onPan} />
     * ```
     *
     * @public
     */
    offset: Point;
    /**
     * Contains `x` and `y` values for the current velocity of the pointer, in px/ms.
     *
     * ```jsx
     * function onPan(event, info) {
     *   console.log(info.velocity.x, info.velocity.y)
     * }
     *
     * <motion.div onPan={onPan} />
     * ```
     *
     * @public
     */
    velocity: Point;
}
type PanHandler = (event: Event, info: PanInfo) => void;

type DragHandler = (event: MouseEvent | TouchEvent | PointerEvent, info: PanInfo) => void;
type DragElastic = boolean | number | Partial<BoundingBox>;
interface ResolvedConstraints {
    x: Partial<Axis>;
    y: Partial<Axis>;
}
interface ResolvedElastic {
    x: Axis;
    y: Axis;
}

interface EventInfo {
    point: Point;
}
/**
 * A generic set of string/number values
 */
interface ResolvedValues$1 {
    [key: string]: AnyResolvedKeyframe;
}
type AnimationDefinition = VariantLabels | TargetAndTransition | TargetResolver;
/**
 * An object that specifies values to animate to. Each value may be set either as
 * a single value, or an array of values.
 *
 * It may also option contain these properties:
 *
 * - `transition`: Specifies transitions for all or individual values.
 * - `transitionEnd`: Specifies values to set when the animation finishes.
 *
 * ```jsx
 * const target = {
 *   x: "0%",
 *   opacity: 0,
 *   transition: { duration: 1 },
 *   transitionEnd: { display: "none" }
 * }
 * ```
 *
 * @public
 */
type TargetAndTransition = Target & {
    transition?: Transition;
    transitionEnd?: ResolvedValues$1;
};
type TargetResolver = (custom: any, current: ResolvedValues$1, velocity: ResolvedValues$1) => TargetAndTransition | string;
/**
 * Either a string, or array of strings, that reference variants defined via the `variants` prop.
 * @public
 */
type VariantLabels = string | string[];
type Variant = TargetAndTransition | TargetResolver;
interface Variants {
    [key: string]: Variant;
}
/**
 * @deprecated
 */
type LegacyAnimationControls = {
    /**
     * Subscribes a component's animation controls to this.
     *
     * @param controls - The controls to subscribe
     * @returns An unsubscribe function.
     */
    subscribe(visualElement: any): () => void;
    /**
     * Starts an animation on all linked components.
     *
     * @remarks
     *
     * ```jsx
     * controls.start("variantLabel")
     * controls.start({
     *   x: 0,
     *   transition: { duration: 1 }
     * })
     * ```
     *
     * @param definition - Properties or variant label to animate to
     * @param transition - Optional `transition` to apply to a variant
     * @returns - A `Promise` that resolves when all animations have completed.
     *
     * @public
     */
    start(definition: AnimationDefinition, transitionOverride?: Transition): Promise<any>;
    /**
     * Instantly set to a set of properties or a variant.
     *
     * ```jsx
     * // With properties
     * controls.set({ opacity: 0 })
     *
     * // With variants
     * controls.set("hidden")
     * ```
     *
     * @privateRemarks
     * We could perform a similar trick to `.start` where this can be called before mount
     * and we maintain a list of of pending actions that get applied on mount. But the
     * expectation of `set` is that it happens synchronously and this would be difficult
     * to do before any children have even attached themselves. It's also poor practise
     * and we should discourage render-synchronous `.start` calls rather than lean into this.
     *
     * @public
     */
    set(definition: AnimationDefinition): void;
    /**
     * Stops animations on all linked components.
     *
     * ```jsx
     * controls.stop()
     * ```
     *
     * @public
     */
    stop(): void;
    mount(): () => void;
};
interface MotionNodeAnimationOptions {
    /**
     * Properties, variant label or array of variant labels to start in.
     *
     * Set to `false` to initialise with the values in `animate` (disabling the mount animation)
     *
     * ```jsx
     * // As values
     * <motion.div initial={{ opacity: 1 }} />
     *
     * // As variant
     * <motion.div initial="visible" variants={variants} />
     *
     * // Multiple variants
     * <motion.div initial={["visible", "active"]} variants={variants} />
     *
     * // As false (disable mount animation)
     * <motion.div initial={false} animate={{ opacity: 0 }} />
     * ```
     */
    initial?: TargetAndTransition | VariantLabels | boolean;
    /**
     * Values to animate to, variant label(s), or `LegacyAnimationControls`.
     *
     * ```jsx
     * // As values
     * <motion.div animate={{ opacity: 1 }} />
     *
     * // As variant
     * <motion.div animate="visible" variants={variants} />
     *
     * // Multiple variants
     * <motion.div animate={["visible", "active"]} variants={variants} />
     *
     * // LegacyAnimationControls
     * <motion.div animate={animation} />
     * ```
     */
    animate?: TargetAndTransition | VariantLabels | boolean | LegacyAnimationControls;
    /**
     * A target to animate to when this component is removed from the tree.
     *
     * This component **must** be the first animatable child of an `AnimatePresence` to enable this exit animation.
     *
     * This limitation exists because React doesn't allow components to defer unmounting until after
     * an animation is complete. Once this limitation is fixed, the `AnimatePresence` component will be unnecessary.
     *
     * ```jsx
     * import { AnimatePresence, motion } from 'framer-motion'
     *
     * export const MyComponent = ({ isVisible }) => {
     *   return (
     *     <AnimatePresence>
     *        {isVisible && (
     *          <motion.div
     *            initial={{ opacity: 0 }}
     *            animate={{ opacity: 1 }}
     *            exit={{ opacity: 0 }}
     *          />
     *        )}
     *     </AnimatePresence>
     *   )
     * }
     * ```
     */
    exit?: TargetAndTransition | VariantLabels;
    /**
     * Variants allow you to define animation states and organise them by name. They allow
     * you to control animations throughout a component tree by switching a single `animate` prop.
     *
     * Using `transition` options like `delayChildren` and `when`, you can orchestrate
     * when children animations play relative to their parent.

     *
     * After passing variants to one or more `motion` component's `variants` prop, these variants
     * can be used in place of values on the `animate`, `initial`, `whileFocus`, `whileTap` and `whileHover` props.
     *
     * ```jsx
     * const variants = {
     *   active: {
     *       backgroundColor: "#f00"
     *   },
     *   inactive: {
     *     backgroundColor: "#fff",
     *     transition: { duration: 2 }
     *   }
     * }
     *
     * <motion.div variants={variants} animate="active" />
     * ```
     */
    variants?: Variants;
    /**
     * Default transition. If no `transition` is defined in `animate`, it will use the transition defined here.
     * ```jsx
     * const spring = {
     *   type: "spring",
     *   damping: 10,
     *   stiffness: 100
     * }
     *
     * <motion.div transition={spring} animate={{ scale: 1.2 }} />
     * ```
     */
    transition?: Transition;
}
interface MotionNodeEventOptions {
    /**
     * Callback with latest motion values, fired max once per frame.
     *
     * ```jsx
     * function onUpdate(latest) {
     *   console.log(latest.x, latest.opacity)
     * }
     *
     * <motion.div animate={{ x: 100, opacity: 0 }} onUpdate={onUpdate} />
     * ```
     */
    onUpdate?(latest: ResolvedValues$1): void;
    /**
     * Callback when animation defined in `animate` begins.
     *
     * The provided callback will be called with the triggering animation definition.
     * If this is a variant, it'll be the variant name, and if a target object
     * then it'll be the target object.
     *
     * This way, it's possible to figure out which animation has started.
     *
     * ```jsx
     * function onStart() {
     *   console.log("Animation started")
     * }
     *
     * <motion.div animate={{ x: 100 }} onAnimationStart={onStart} />
     * ```
     */
    onAnimationStart?(definition: AnimationDefinition): void;
    /**
     * Callback when animation defined in `animate` is complete.
     *
     * The provided callback will be called with the triggering animation definition.
     * If this is a variant, it'll be the variant name, and if a target object
     * then it'll be the target object.
     *
     * This way, it's possible to figure out which animation has completed.
     *
     * ```jsx
     * function onComplete() {
     *   console.log("Animation completed")
     * }
     *
     * <motion.div
     *   animate={{ x: 100 }}
     *   onAnimationComplete={definition => {
     *     console.log('Completed animating', definition)
     *   }}
     * />
     * ```
     */
    onAnimationComplete?(definition: AnimationDefinition): void;
    onBeforeLayoutMeasure?(box: Box): void;
    onLayoutMeasure?(box: Box, prevBox: Box): void;
    onLayoutAnimationStart?(): void;
    onLayoutAnimationComplete?(): void;
}
interface MotionNodePanHandlers {
    /**
     * Callback function that fires when the pan gesture is recognised on this element.
     *
     * **Note:** For pan gestures to work correctly with touch input, the element needs
     * touch scrolling to be disabled on either x/y or both axis with the
     * [touch-action](https://developer.mozilla.org/en-US/docs/Web/CSS/touch-action) CSS rule.
     *
     * ```jsx
     * function onPan(event, info) {
     *   console.log(info.point.x, info.point.y)
     * }
     *
     * <motion.div onPan={onPan} />
     * ```
     *
     * @param event - The originating pointer event.
     * @param info - A {@link PanInfo} object containing `x` and `y` values for:
     *
     *   - `point`: Relative to the device or page.
     *   - `delta`: Distance moved since the last event.
     *   - `offset`: Offset from the original pan event.
     *   - `velocity`: Current velocity of the pointer.
     */
    onPan?(event: PointerEvent, info: PanInfo): void;
    /**
     * Callback function that fires when the pan gesture begins on this element.
     *
     * ```jsx
     * function onPanStart(event, info) {
     *   console.log(info.point.x, info.point.y)
     * }
     *
     * <motion.div onPanStart={onPanStart} />
     * ```
     *
     * @param event - The originating pointer event.
     * @param info - A {@link PanInfo} object containing `x`/`y` values for:
     *
     *   - `point`: Relative to the device or page.
     *   - `delta`: Distance moved since the last event.
     *   - `offset`: Offset from the original pan event.
     *   - `velocity`: Current velocity of the pointer.
     */
    onPanStart?(event: PointerEvent, info: PanInfo): void;
    /**
     * Callback function that fires when we begin detecting a pan gesture. This
     * is analogous to `onMouseStart` or `onTouchStart`.
     *
     * ```jsx
     * function onPanSessionStart(event, info) {
     *   console.log(info.point.x, info.point.y)
     * }
     *
     * <motion.div onPanSessionStart={onPanSessionStart} />
     * ```
     *
     * @param event - The originating pointer event.
     * @param info - An {@link EventInfo} object containing `x`/`y` values for:
     *
     *   - `point`: Relative to the device or page.
     */
    onPanSessionStart?(event: PointerEvent, info: EventInfo): void;
    /**
     * Callback function that fires when the pan gesture ends on this element.
     *
     * ```jsx
     * function onPanEnd(event, info) {
     *   console.log(info.point.x, info.point.y)
     * }
     *
     * <motion.div onPanEnd={onPanEnd} />
     * ```
     *
     * @param event - The originating pointer event.
     * @param info - A {@link PanInfo} object containing `x`/`y` values for:
     *
     *   - `point`: Relative to the device or page.
     *   - `delta`: Distance moved since the last event.
     *   - `offset`: Offset from the original pan event.
     *   - `velocity`: Current velocity of the pointer.
     */
    onPanEnd?(event: PointerEvent, info: PanInfo): void;
}
interface MotionNodeHoverHandlers {
    /**
     * Properties or variant label to animate to while the hover gesture is recognised.
     *
     * ```jsx
     * <motion.div whileHover={{ scale: 1.2 }} />
     * ```
     */
    whileHover?: VariantLabels | TargetAndTransition;
    /**
     * Callback function that fires when pointer starts hovering over the component.
     *
     * ```jsx
     * <motion.div onHoverStart={() => console.log('Hover starts')} />
     * ```
     */
    onHoverStart?(event: MouseEvent, info: EventInfo): void;
    /**
     * Callback function that fires when pointer stops hovering over the component.
     *
     * ```jsx
     * <motion.div onHoverEnd={() => console.log("Hover ends")} />
     * ```
     */
    onHoverEnd?(event: MouseEvent, info: EventInfo): void;
}
/**
 * Passed in to tap event handlers like `onTap` the `TapInfo` object contains
 * information about the tap gesture such as it‘s location.
 *
 * ```jsx
 * function onTap(event, info) {
 *   console.log(info.point.x, info.point.y)
 * }
 *
 * <motion.div onTap={onTap} />
 * ```
 *
 * @public
 */
interface TapInfo {
    /**
     * Contains `x` and `y` values for the tap gesture relative to the
     * device or page.
     *
     * ```jsx
     * function onTapStart(event, info) {
     *   console.log(info.point.x, info.point.y)
     * }
     *
     * <motion.div onTapStart={onTapStart} />
     * ```
     *
     * @public
     */
    point: Point;
}
interface MotionNodeTapHandlers {
    /**
     * Callback when the tap gesture successfully ends on this element.
     *
     * ```jsx
     * function onTap(event, info) {
     *   console.log(info.point.x, info.point.y)
     * }
     *
     * <motion.div onTap={onTap} />
     * ```
     *
     * @param event - The originating pointer event.
     * @param info - An {@link TapInfo} object containing `x` and `y` values for the `point` relative to the device or page.
     */
    onTap?(event: MouseEvent | TouchEvent | PointerEvent, info: TapInfo): void;
    /**
     * Callback when the tap gesture starts on this element.
     *
     * ```jsx
     * function onTapStart(event, info) {
     *   console.log(info.point.x, info.point.y)
     * }
     *
     * <motion.div onTapStart={onTapStart} />
     * ```
     *
     * @param event - The originating pointer event.
     * @param info - An {@link TapInfo} object containing `x` and `y` values for the `point` relative to the device or page.
     */
    onTapStart?(event: MouseEvent | TouchEvent | PointerEvent, info: TapInfo): void;
    /**
     * Callback when the tap gesture ends outside this element.
     *
     * ```jsx
     * function onTapCancel(event, info) {
     *   console.log(info.point.x, info.point.y)
     * }
     *
     * <motion.div onTapCancel={onTapCancel} />
     * ```
     *
     * @param event - The originating pointer event.
     * @param info - An {@link TapInfo} object containing `x` and `y` values for the `point` relative to the device or page.
     */
    onTapCancel?(event: MouseEvent | TouchEvent | PointerEvent, info: TapInfo): void;
    /**
     * Properties or variant label to animate to while the component is pressed.
     *
     * ```jsx
     * <motion.div whileTap={{ scale: 0.8 }} />
     * ```
     */
    whileTap?: VariantLabels | TargetAndTransition;
    /**
     * If `true`, the tap gesture will attach its start listener to window.
     *
     * Note: This is not supported publically.
     */
    globalTapTarget?: boolean;
}
/**
 * @deprecated - Use MotionNodeTapHandlers
 */
interface TapHandlers extends MotionNodeTapHandlers {
}
interface MotionNodeFocusHandlers {
    /**
     * Properties or variant label to animate to while the focus gesture is recognised.
     *
     * ```jsx
     * <motion.input whileFocus={{ scale: 1.2 }} />
     * ```
     */
    whileFocus?: VariantLabels | TargetAndTransition;
}
/**
 * TODO: Replace with types from inView()
 */
type ViewportEventHandler = (entry: IntersectionObserverEntry | null) => void;
interface ViewportOptions {
    root?: {
        current: Element | null;
    };
    once?: boolean;
    margin?: string;
    amount?: "some" | "all" | number;
}
interface MotionNodeViewportOptions {
    whileInView?: VariantLabels | TargetAndTransition;
    onViewportEnter?: ViewportEventHandler;
    onViewportLeave?: ViewportEventHandler;
    viewport?: ViewportOptions;
}
interface MotionNodeDraggableOptions {
    /**
     * Enable dragging for this element. Set to `false` by default.
     * Set `true` to drag in both directions.
     * Set `"x"` or `"y"` to only drag in a specific direction.
     *
     * ```jsx
     * <motion.div drag="x" />
     * ```
     */
    drag?: boolean | "x" | "y";
    /**
     * Properties or variant label to animate to while the drag gesture is recognised.
     *
     * ```jsx
     * <motion.div whileDrag={{ scale: 1.2 }} />
     * ```
     */
    whileDrag?: VariantLabels | TargetAndTransition;
    /**
     * If `true`, this will lock dragging to the initially-detected direction. Defaults to `false`.
     *
     * ```jsx
     * <motion.div drag dragDirectionLock />
     * ```
     */
    dragDirectionLock?: boolean;
    /**
     * Allows drag gesture propagation to child components. Set to `false` by
     * default.
     *
     * ```jsx
     * <motion.div drag="x" dragPropagation />
     * ```
     */
    dragPropagation?: boolean;
    /**
     * Applies constraints on the permitted draggable area.
     *
     * It can accept an object of optional `top`, `left`, `right`, and `bottom` values, measured in pixels.
     * This will define a distance from the named edge of the draggable component.
     *
     * Alternatively, it can accept a `ref` to another component created with React's `useRef` hook.
     * This `ref` should be passed both to the draggable component's `dragConstraints` prop, and the `ref`
     * of the component you want to use as constraints.
     *
     * ```jsx
     * // In pixels
     * <motion.div
     *   drag="x"
     *   dragConstraints={{ left: 0, right: 300 }}
     * />
     *
     * // As a ref to another component
     * const MyComponent = () => {
     *   const constraintsRef = useRef(null)
     *
     *   return (
     *      <motion.div ref={constraintsRef}>
     *          <motion.div drag dragConstraints={constraintsRef} />
     *      </motion.div>
     *   )
     * }
     * ```
     */
    dragConstraints?: false | Partial<BoundingBox> | {
        current: Element | null;
    };
    /**
     * The degree of movement allowed outside constraints. 0 = no movement, 1 =
     * full movement.
     *
     * Set to `0.5` by default. Can also be set as `false` to disable movement.
     *
     * By passing an object of `top`/`right`/`bottom`/`left`, individual values can be set
     * per constraint. Any missing values will be set to `0`.
     *
     * ```jsx
     * <motion.div
     *   drag
     *   dragConstraints={{ left: 0, right: 300 }}
     *   dragElastic={0.2}
     * />
     * ```
     */
    dragElastic?: DragElastic;
    /**
     * Apply momentum from the pan gesture to the component when dragging
     * finishes. Set to `true` by default.
     *
     * ```jsx
     * <motion.div
     *   drag
     *   dragConstraints={{ left: 0, right: 300 }}
     *   dragMomentum={false}
     * />
     * ```
     */
    dragMomentum?: boolean;
    /**
     * Allows you to change dragging inertia parameters.
     * When releasing a draggable Frame, an animation with type `inertia` starts. The animation is based on your dragging velocity. This property allows you to customize it.
     * See {@link https://motion.dev/docs/react-motion-component#dragtransition | Inertia} for all properties you can use.
     *
     * ```jsx
     * <motion.div
     *   drag
     *   dragTransition={{ bounceStiffness: 600, bounceDamping: 10 }}
     * />
     * ```
     */
    dragTransition?: InertiaOptions;
    /**
     * Usually, dragging is initiated by pressing down on a component and moving it. For some
     * use-cases, for instance clicking at an arbitrary point on a video scrubber, we
     * might want to initiate dragging from a different component than the draggable one.
     *
     * By creating a `dragControls` using the `useDragControls` hook, we can pass this into
     * the draggable component's `dragControls` prop. It exposes a `start` method
     * that can start dragging from pointer events on other components.
     *
     * ```jsx
     * const dragControls = useDragControls()
     *
     * function startDrag(event) {
     *   dragControls.start(event, { snapToCursor: true })
     * }
     *
     * return (
     *   <>
     *     <div onPointerDown={startDrag} />
     *     <motion.div drag="x" dragControls={dragControls} />
     *   </>
     * )
     * ```
     */
    dragControls?: any;
    /**
     * If true, element will snap back to its origin when dragging ends.
     *
     * Enabling this is the equivalent of setting all `dragConstraints` axes to `0`
     * with `dragElastic={1}`, but when used together `dragConstraints` can define
     * a wider draggable area and `dragSnapToOrigin` will ensure the element
     * animates back to its origin on release.
     */
    dragSnapToOrigin?: boolean;
    /**
     * By default, if `drag` is defined on a component then an event listener will be attached
     * to automatically initiate dragging when a user presses down on it.
     *
     * By setting `dragListener` to `false`, this event listener will not be created.
     *
     * ```jsx
     * const dragControls = useDragControls()
     *
     * function startDrag(event) {
     *   dragControls.start(event, { snapToCursor: true })
     * }
     *
     * return (
     *   <>
     *     <div onPointerDown={startDrag} />
     *     <motion.div
     *       drag="x"
     *       dragControls={dragControls}
     *       dragListener={false}
     *     />
     *   </>
     * )
     * ```
     */
    dragListener?: boolean;
    /**
     * If `dragConstraints` is set to a React ref, this callback will call with the measured drag constraints.
     *
     * @public
     */
    onMeasureDragConstraints?: (constraints: BoundingBox) => BoundingBox | void;
    /**
     * Usually, dragging uses the layout project engine, and applies transforms to the underlying VisualElement.
     * Passing MotionValues as _dragX and _dragY instead applies drag updates to these motion values.
     * This allows you to manually control how updates from a drag gesture on an element is applied.
     *
     * @public
     */
    _dragX?: MotionValue<number>;
    /**
     * Usually, dragging uses the layout project engine, and applies transforms to the underlying VisualElement.
     * Passing MotionValues as _dragX and _dragY instead applies drag updates to these motion values.
     * This allows you to manually control how updates from a drag gesture on an element is applied.
     *
     * @public
     */
    _dragY?: MotionValue<number>;
}
interface MotionNodeDragHandlers {
    /**
     * Callback function that fires when dragging starts.
     *
     * ```jsx
     * <motion.div
     *   drag
     *   onDragStart={
     *     (event, info) => console.log(info.point.x, info.point.y)
     *   }
     * />
     * ```
     *
     * @public
     */
    onDragStart?(event: MouseEvent | TouchEvent | PointerEvent, info: PanInfo): void;
    /**
     * Callback function that fires when dragging ends.
     *
     * ```jsx
     * <motion.div
     *   drag
     *   onDragEnd={
     *     (event, info) => console.log(info.point.x, info.point.y)
     *   }
     * />
     * ```
     *
     * @public
     */
    onDragEnd?(event: MouseEvent | TouchEvent | PointerEvent, info: PanInfo): void;
    /**
     * Callback function that fires when the component is dragged.
     *
     * ```jsx
     * <motion.div
     *   drag
     *   onDrag={
     *     (event, info) => console.log(info.point.x, info.point.y)
     *   }
     * />
     * ```
     *
     * @public
     */
    onDrag?(event: MouseEvent | TouchEvent | PointerEvent, info: PanInfo): void;
    /**
     * Callback function that fires a drag direction is determined.
     *
     * ```jsx
     * <motion.div
     *   drag
     *   dragDirectionLock
     *   onDirectionLock={axis => console.log(axis)}
     * />
     * ```
     *
     * @public
     */
    onDirectionLock?(axis: "x" | "y"): void;
    /**
     * Callback function that fires when drag momentum/bounce transition finishes.
     *
     * ```jsx
     * <motion.div
     *   drag
     *   onDragTransitionEnd={() => console.log('Drag transition complete')}
     * />
     * ```
     *
     * @public
     */
    onDragTransitionEnd?(): void;
}
interface MotionNodeLayoutOptions {
    /**
     * If `true`, this component will automatically animate to its new position when
     * its layout changes.
     *
     * ```jsx
     * <motion.div layout />
     * ```
     *
     * This will perform a layout animation using performant transforms. Part of this technique
     * involved animating an element's scale. This can introduce visual distortions on children,
     * `boxShadow` and `borderRadius`.
     *
     * To correct distortion on immediate children, add `layout` to those too.
     *
     * `boxShadow` and `borderRadius` will automatically be corrected if they are already being
     * animated on this component. Otherwise, set them directly via the `initial` prop.
     *
     * If `layout` is set to `"position"`, the size of the component will change instantly and
     * only its position will animate.
     *
     * If `layout` is set to `"size"`, the position of the component will change instantly and
     * only its size will animate.
     *
     * If `layout` is set to `"preserve-aspect"`, the component will animate size & position if
     * the aspect ratio remains the same between renders, and just position if the ratio changes.
     *
     * @public
     */
    layout?: boolean | "position" | "size" | "preserve-aspect";
    /**
     * Enable shared layout transitions between different components with the same `layoutId`.
     *
     * When a component with a layoutId is removed from the React tree, and then
     * added elsewhere, it will visually animate from the previous component's bounding box
     * and its latest animated values.
     *
     * ```jsx
     *   {items.map(item => (
     *      <motion.li layout>
     *         {item.name}
     *         {item.isSelected && <motion.div layoutId="underline" />}
     *      </motion.li>
     *   ))}
     * ```
     *
     * If the previous component remains in the tree it will crossfade with the new component.
     *
     * @public
     */
    layoutId?: string;
    /**
     * A callback that will fire when a layout animation on this component starts.
     *
     * @public
     */
    onLayoutAnimationStart?(): void;
    /**
     * A callback that will fire when a layout animation on this component completes.
     *
     * @public
     */
    onLayoutAnimationComplete?(): void;
    /**
     * @public
     */
    layoutDependency?: any;
    /**
     * Whether a projection node should measure its scroll when it or its descendants update their layout.
     *
     * @public
     */
    layoutScroll?: boolean;
    /**
     * Whether an element should be considered a "layout root", where
     * all children will be forced to resolve relatively to it.
     * Currently used for `position: sticky` elements in Framer.
     */
    layoutRoot?: boolean;
    /**
     * Attached to a portal root to ensure we attach the child to the document root and don't
     * perform scale correction on it.
     */
    "data-framer-portal-id"?: string;
    /**
     * By default, shared layout elements will crossfade. By setting this
     * to `false`, this element will take its default opacity throughout the animation.
     */
    layoutCrossfade?: boolean;
}
/**
 * @deprecated - Use MotionNodeDragHandlers/MotionNodeDraggableOptions
 */
interface DraggableProps extends MotionNodeDragHandlers, MotionNodeDraggableOptions {
}
type TransformTemplate = (transform: TransformProperties, generatedTransform: string) => string;
interface MotionNodeAdvancedOptions {
    /**
     * Custom data to use to resolve dynamic variants differently for each animating component.
     *
     * ```jsx
     * const variants = {
     *   visible: (custom) => ({
     *     opacity: 1,
     *     transition: { delay: custom * 0.2 }
     *   })
     * }
     *
     * <motion.div custom={0} animate="visible" variants={variants} />
     * <motion.div custom={1} animate="visible" variants={variants} />
     * <motion.div custom={2} animate="visible" variants={variants} />
     * ```
     *
     * @public
     */
    custom?: any;
    /**
     * @public
     * Set to `false` to prevent inheriting variant changes from its parent.
     */
    inherit?: boolean;
    /**
     * @public
     * Set to `false` to prevent throwing an error when a `motion` component is used within a `LazyMotion` set to strict.
     */
    ignoreStrict?: boolean;
    /**
     * Provide a set of motion values to perform animations on.
     */
    values?: {
        [key: string]: MotionValue<number> | MotionValue<string>;
    };
    /**
     * By default, Motion generates a `transform` property with a sensible transform order. `transformTemplate`
     * can be used to create a different order, or to append/preprend the automatically generated `transform` property.
     *
     * ```jsx
     * <motion.div
     *   style={{ x: 0, rotate: 180 }}
     *   transformTemplate={
     *     ({ x, rotate }) => `rotate(${rotate}deg) translateX(${x}px)`
     *   }
     * />
     * ```
     *
     * @param transform - The latest animated transform props.
     * @param generatedTransform - The transform string as automatically generated by Motion
     *
     * @public
     */
    transformTemplate?: TransformTemplate;
    "data-framer-appear-id"?: string;
}
interface MotionNodeOptions extends MotionNodeAnimationOptions, MotionNodeEventOptions, MotionNodePanHandlers, MotionNodeTapHandlers, MotionNodeHoverHandlers, MotionNodeFocusHandlers, MotionNodeViewportOptions, MotionNodeDragHandlers, MotionNodeDraggableOptions, MotionNodeLayoutOptions, MotionNodeAdvancedOptions {
}

/**
 * @public
 */
interface PresenceContextProps {
    id: string;
    isPresent: boolean;
    register: (id: string | number) => () => void;
    onExitComplete?: (id: string | number) => void;
    initial?: false | VariantLabels;
    custom?: any;
}
/**
 * @public
 */
type ReducedMotionConfig = "always" | "never" | "user";
/**
 * @public
 */
interface MotionConfigContextProps {
    /**
     * Internal, exported only for usage in Framer
     */
    transformPagePoint: TransformPoint;
    /**
     * Internal. Determines whether this is a static context ie the Framer canvas. If so,
     * it'll disable all dynamic functionality.
     */
    isStatic: boolean;
    /**
     * Defines a new default transition for the entire tree.
     *
     * @public
     */
    transition?: Transition;
    /**
     * If true, will respect the device prefersReducedMotion setting by switching
     * transform animations off.
     *
     * @public
     */
    reducedMotion?: ReducedMotionConfig;
    /**
     * A custom `nonce` attribute used when wanting to enforce a Content Security Policy (CSP).
     * For more details see:
     * https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy/style-src#unsafe_inline_styles
     *
     * @public
     */
    nonce?: string;
}
interface VisualState<_Instance, RenderState> {
    latestValues: ResolvedValues$1;
    renderState: RenderState;
}
interface VisualElementOptions<Instance, RenderState = any> {
    visualState: VisualState<Instance, RenderState>;
    parent?: any;
    variantParent?: any;
    presenceContext: PresenceContextProps | null;
    props: MotionNodeOptions;
    blockInitialAnimation?: boolean;
    reducedMotionConfig?: ReducedMotionConfig;
    /**
     * Explicit override for SVG detection. When true, uses SVG rendering;
     * when false, uses HTML rendering. If undefined, auto-detects.
     */
    isSVG?: boolean;
}
interface VisualElementEventCallbacks {
    BeforeLayoutMeasure: () => void;
    LayoutMeasure: (layout: Box, prevLayout?: Box) => void;
    LayoutUpdate: (layout: Axis, prevLayout: Axis) => void;
    Update: (latest: ResolvedValues$1) => void;
    AnimationStart: (definition: AnimationDefinition) => void;
    AnimationComplete: (definition: AnimationDefinition) => void;
    LayoutAnimationStart: () => void;
    LayoutAnimationComplete: () => void;
    SetAxisTarget: () => void;
    Unmount: () => void;
}
interface LayoutLifecycles {
    onBeforeLayoutMeasure?(box: Box): void;
    onLayoutMeasure?(box: Box, prevBox: Box): void;
}
type ScrapeMotionValuesFromProps = (props: MotionNodeOptions, prevProps: MotionNodeOptions, visualElement?: any) => {
    [key: string]: MotionValue | AnyResolvedKeyframe;
};
type UseRenderState<RenderState = any> = () => RenderState;
/**
 * Animation type for variant state management
 */
type AnimationType = "animate" | "whileHover" | "whileTap" | "whileDrag" | "whileFocus" | "whileInView" | "exit";
interface FeatureClass<Props = unknown> {
    new (props: Props): any;
}
interface FeatureDefinition {
    isEnabled: (props: MotionNodeOptions) => boolean;
    Feature?: FeatureClass<unknown>;
    ProjectionNode?: any;
    MeasureLayout?: any;
}
type FeatureDefinitions = {
    animation?: FeatureDefinition;
    exit?: FeatureDefinition;
    drag?: FeatureDefinition;
    tap?: FeatureDefinition;
    focus?: FeatureDefinition;
    hover?: FeatureDefinition;
    pan?: FeatureDefinition;
    inView?: FeatureDefinition;
    layout?: FeatureDefinition;
};

interface TransformOrigin {
    originX?: number | string;
    originY?: number | string;
    originZ?: number | string;
}
interface HTMLRenderState {
    /**
     * A mutable record of transforms we want to apply directly to the rendered Element
     * every frame. We use a mutable data structure to reduce GC during animations.
     */
    transform: ResolvedValues$1;
    /**
     * A mutable record of transform origins we want to apply directly to the rendered Element
     * every frame. We use a mutable data structure to reduce GC during animations.
     */
    transformOrigin: TransformOrigin;
    /**
     * A mutable record of styles we want to apply directly to the rendered Element
     * every frame. We use a mutable data structure to reduce GC during animations.
     */
    style: ResolvedValues$1;
    /**
     * A mutable record of CSS variables we want to apply directly to the rendered Element
     * every frame. We use a mutable data structure to reduce GC during animations.
     */
    vars: ResolvedValues$1;
}

interface SVGRenderState extends HTMLRenderState {
    /**
     * A mutable record of attributes we want to apply directly to the rendered Element
     * every frame. We use a mutable data structure to reduce GC during animations.
     */
    attrs: ResolvedValues$1;
}
interface SVGAttributes {
    accentHeight?: AnyResolvedKeyframe | undefined;
    accumulate?: "none" | "sum" | undefined;
    additive?: "replace" | "sum" | undefined;
    alignmentBaseline?: "auto" | "baseline" | "before-edge" | "text-before-edge" | "middle" | "central" | "after-edge" | "text-after-edge" | "ideographic" | "alphabetic" | "hanging" | "mathematical" | "inherit" | undefined;
    allowReorder?: "no" | "yes" | undefined;
    alphabetic?: AnyResolvedKeyframe | undefined;
    amplitude?: AnyResolvedKeyframe | undefined;
    arabicForm?: "initial" | "medial" | "terminal" | "isolated" | undefined;
    ascent?: AnyResolvedKeyframe | undefined;
    attributeName?: string | undefined;
    attributeType?: string | undefined;
    autoReverse?: boolean | undefined;
    azimuth?: AnyResolvedKeyframe | undefined;
    baseFrequency?: AnyResolvedKeyframe | undefined;
    baselineShift?: AnyResolvedKeyframe | undefined;
    baseProfile?: AnyResolvedKeyframe | undefined;
    bbox?: AnyResolvedKeyframe | undefined;
    begin?: AnyResolvedKeyframe | undefined;
    bias?: AnyResolvedKeyframe | undefined;
    by?: AnyResolvedKeyframe | undefined;
    calcMode?: AnyResolvedKeyframe | undefined;
    capHeight?: AnyResolvedKeyframe | undefined;
    clip?: AnyResolvedKeyframe | undefined;
    clipPath?: string | undefined;
    clipPathUnits?: AnyResolvedKeyframe | undefined;
    clipRule?: AnyResolvedKeyframe | undefined;
    colorInterpolation?: AnyResolvedKeyframe | undefined;
    colorInterpolationFilters?: "auto" | "sRGB" | "linearRGB" | "inherit" | undefined;
    colorProfile?: AnyResolvedKeyframe | undefined;
    colorRendering?: AnyResolvedKeyframe | undefined;
    contentScriptType?: AnyResolvedKeyframe | undefined;
    contentStyleType?: AnyResolvedKeyframe | undefined;
    cursor?: AnyResolvedKeyframe | undefined;
    cx?: AnyResolvedKeyframe | undefined;
    cy?: AnyResolvedKeyframe | undefined;
    d?: string | undefined;
    decelerate?: AnyResolvedKeyframe | undefined;
    descent?: AnyResolvedKeyframe | undefined;
    diffuseConstant?: AnyResolvedKeyframe | undefined;
    direction?: AnyResolvedKeyframe | undefined;
    display?: AnyResolvedKeyframe | undefined;
    divisor?: AnyResolvedKeyframe | undefined;
    dominantBaseline?: AnyResolvedKeyframe | undefined;
    dur?: AnyResolvedKeyframe | undefined;
    dx?: AnyResolvedKeyframe | undefined;
    dy?: AnyResolvedKeyframe | undefined;
    edgeMode?: AnyResolvedKeyframe | undefined;
    elevation?: AnyResolvedKeyframe | undefined;
    enableBackground?: AnyResolvedKeyframe | undefined;
    end?: AnyResolvedKeyframe | undefined;
    exponent?: AnyResolvedKeyframe | undefined;
    externalResourcesRequired?: boolean | undefined;
    fill?: string | undefined;
    fillOpacity?: AnyResolvedKeyframe | undefined;
    fillRule?: "nonzero" | "evenodd" | "inherit" | undefined;
    filter?: string | undefined;
    filterRes?: AnyResolvedKeyframe | undefined;
    filterUnits?: AnyResolvedKeyframe | undefined;
    floodColor?: AnyResolvedKeyframe | undefined;
    floodOpacity?: AnyResolvedKeyframe | undefined;
    focusable?: boolean | "auto" | undefined;
    fontFamily?: string | undefined;
    fontSize?: AnyResolvedKeyframe | undefined;
    fontSizeAdjust?: AnyResolvedKeyframe | undefined;
    fontStretch?: AnyResolvedKeyframe | undefined;
    fontStyle?: AnyResolvedKeyframe | undefined;
    fontVariant?: AnyResolvedKeyframe | undefined;
    fontWeight?: AnyResolvedKeyframe | undefined;
    format?: AnyResolvedKeyframe | undefined;
    fr?: AnyResolvedKeyframe | undefined;
    from?: AnyResolvedKeyframe | undefined;
    fx?: AnyResolvedKeyframe | undefined;
    fy?: AnyResolvedKeyframe | undefined;
    g1?: AnyResolvedKeyframe | undefined;
    g2?: AnyResolvedKeyframe | undefined;
    glyphName?: AnyResolvedKeyframe | undefined;
    glyphOrientationHorizontal?: AnyResolvedKeyframe | undefined;
    glyphOrientationVertical?: AnyResolvedKeyframe | undefined;
    glyphRef?: AnyResolvedKeyframe | undefined;
    gradientTransform?: string | undefined;
    gradientUnits?: string | undefined;
    hanging?: AnyResolvedKeyframe | undefined;
    horizAdvX?: AnyResolvedKeyframe | undefined;
    horizOriginX?: AnyResolvedKeyframe | undefined;
    href?: string | undefined;
    ideographic?: AnyResolvedKeyframe | undefined;
    imageRendering?: AnyResolvedKeyframe | undefined;
    in2?: AnyResolvedKeyframe | undefined;
    in?: string | undefined;
    intercept?: AnyResolvedKeyframe | undefined;
    k1?: AnyResolvedKeyframe | undefined;
    k2?: AnyResolvedKeyframe | undefined;
    k3?: AnyResolvedKeyframe | undefined;
    k4?: AnyResolvedKeyframe | undefined;
    k?: AnyResolvedKeyframe | undefined;
    kernelMatrix?: AnyResolvedKeyframe | undefined;
    kernelUnitLength?: AnyResolvedKeyframe | undefined;
    kerning?: AnyResolvedKeyframe | undefined;
    keyPoints?: AnyResolvedKeyframe | undefined;
    keySplines?: AnyResolvedKeyframe | undefined;
    keyTimes?: AnyResolvedKeyframe | undefined;
    lengthAdjust?: AnyResolvedKeyframe | undefined;
    letterSpacing?: AnyResolvedKeyframe | undefined;
    lightingColor?: AnyResolvedKeyframe | undefined;
    limitingConeAngle?: AnyResolvedKeyframe | undefined;
    local?: AnyResolvedKeyframe | undefined;
    markerEnd?: string | undefined;
    markerHeight?: AnyResolvedKeyframe | undefined;
    markerMid?: string | undefined;
    markerStart?: string | undefined;
    markerUnits?: AnyResolvedKeyframe | undefined;
    markerWidth?: AnyResolvedKeyframe | undefined;
    mask?: string | undefined;
    maskContentUnits?: AnyResolvedKeyframe | undefined;
    maskUnits?: AnyResolvedKeyframe | undefined;
    mathematical?: AnyResolvedKeyframe | undefined;
    mode?: AnyResolvedKeyframe | undefined;
    numOctaves?: AnyResolvedKeyframe | undefined;
    offset?: AnyResolvedKeyframe | undefined;
    opacity?: AnyResolvedKeyframe | undefined;
    operator?: AnyResolvedKeyframe | undefined;
    order?: AnyResolvedKeyframe | undefined;
    orient?: AnyResolvedKeyframe | undefined;
    orientation?: AnyResolvedKeyframe | undefined;
    origin?: AnyResolvedKeyframe | undefined;
    overflow?: AnyResolvedKeyframe | undefined;
    overlinePosition?: AnyResolvedKeyframe | undefined;
    overlineThickness?: AnyResolvedKeyframe | undefined;
    paintOrder?: AnyResolvedKeyframe | undefined;
    panose1?: AnyResolvedKeyframe | undefined;
    path?: string | undefined;
    pathLength?: AnyResolvedKeyframe | undefined;
    patternContentUnits?: string | undefined;
    patternTransform?: AnyResolvedKeyframe | undefined;
    patternUnits?: string | undefined;
    pointerEvents?: AnyResolvedKeyframe | undefined;
    points?: string | undefined;
    pointsAtX?: AnyResolvedKeyframe | undefined;
    pointsAtY?: AnyResolvedKeyframe | undefined;
    pointsAtZ?: AnyResolvedKeyframe | undefined;
    preserveAlpha?: boolean | undefined;
    preserveAspectRatio?: string | undefined;
    primitiveUnits?: AnyResolvedKeyframe | undefined;
    r?: AnyResolvedKeyframe | undefined;
    radius?: AnyResolvedKeyframe | undefined;
    refX?: AnyResolvedKeyframe | undefined;
    refY?: AnyResolvedKeyframe | undefined;
    renderingIntent?: AnyResolvedKeyframe | undefined;
    repeatCount?: AnyResolvedKeyframe | undefined;
    repeatDur?: AnyResolvedKeyframe | undefined;
    requiredExtensions?: AnyResolvedKeyframe | undefined;
    requiredFeatures?: AnyResolvedKeyframe | undefined;
    restart?: AnyResolvedKeyframe | undefined;
    result?: string | undefined;
    rotate?: AnyResolvedKeyframe | undefined;
    rx?: AnyResolvedKeyframe | undefined;
    ry?: AnyResolvedKeyframe | undefined;
    scale?: AnyResolvedKeyframe | undefined;
    seed?: AnyResolvedKeyframe | undefined;
    shapeRendering?: AnyResolvedKeyframe | undefined;
    slope?: AnyResolvedKeyframe | undefined;
    spacing?: AnyResolvedKeyframe | undefined;
    specularConstant?: AnyResolvedKeyframe | undefined;
    specularExponent?: AnyResolvedKeyframe | undefined;
    speed?: AnyResolvedKeyframe | undefined;
    spreadMethod?: string | undefined;
    startOffset?: AnyResolvedKeyframe | undefined;
    stdDeviation?: AnyResolvedKeyframe | undefined;
    stemh?: AnyResolvedKeyframe | undefined;
    stemv?: AnyResolvedKeyframe | undefined;
    stitchTiles?: AnyResolvedKeyframe | undefined;
    stopColor?: string | undefined;
    stopOpacity?: AnyResolvedKeyframe | undefined;
    strikethroughPosition?: AnyResolvedKeyframe | undefined;
    strikethroughThickness?: AnyResolvedKeyframe | undefined;
    string?: AnyResolvedKeyframe | undefined;
    stroke?: string | undefined;
    strokeDasharray?: AnyResolvedKeyframe | undefined;
    strokeDashoffset?: AnyResolvedKeyframe | undefined;
    strokeLinecap?: "butt" | "round" | "square" | "inherit" | undefined;
    strokeLinejoin?: "miter" | "round" | "bevel" | "inherit" | undefined;
    strokeMiterlimit?: AnyResolvedKeyframe | undefined;
    strokeOpacity?: AnyResolvedKeyframe | undefined;
    strokeWidth?: AnyResolvedKeyframe | undefined;
    surfaceScale?: AnyResolvedKeyframe | undefined;
    systemLanguage?: AnyResolvedKeyframe | undefined;
    tableValues?: AnyResolvedKeyframe | undefined;
    targetX?: AnyResolvedKeyframe | undefined;
    targetY?: AnyResolvedKeyframe | undefined;
    textAnchor?: string | undefined;
    textDecoration?: AnyResolvedKeyframe | undefined;
    textLength?: AnyResolvedKeyframe | undefined;
    textRendering?: AnyResolvedKeyframe | undefined;
    to?: AnyResolvedKeyframe | undefined;
    transform?: string | undefined;
    u1?: AnyResolvedKeyframe | undefined;
    u2?: AnyResolvedKeyframe | undefined;
    underlinePosition?: AnyResolvedKeyframe | undefined;
    underlineThickness?: AnyResolvedKeyframe | undefined;
    unicode?: AnyResolvedKeyframe | undefined;
    unicodeBidi?: AnyResolvedKeyframe | undefined;
    unicodeRange?: AnyResolvedKeyframe | undefined;
    unitsPerEm?: AnyResolvedKeyframe | undefined;
    vAlphabetic?: AnyResolvedKeyframe | undefined;
    values?: string | undefined;
    vectorEffect?: AnyResolvedKeyframe | undefined;
    version?: string | undefined;
    vertAdvY?: AnyResolvedKeyframe | undefined;
    vertOriginX?: AnyResolvedKeyframe | undefined;
    vertOriginY?: AnyResolvedKeyframe | undefined;
    vHanging?: AnyResolvedKeyframe | undefined;
    vIdeographic?: AnyResolvedKeyframe | undefined;
    viewBox?: string | undefined;
    viewTarget?: AnyResolvedKeyframe | undefined;
    visibility?: AnyResolvedKeyframe | undefined;
    vMathematical?: AnyResolvedKeyframe | undefined;
    widths?: AnyResolvedKeyframe | undefined;
    wordSpacing?: AnyResolvedKeyframe | undefined;
    writingMode?: AnyResolvedKeyframe | undefined;
    x1?: AnyResolvedKeyframe | undefined;
    x2?: AnyResolvedKeyframe | undefined;
    x?: AnyResolvedKeyframe | undefined;
    xChannelSelector?: string | undefined;
    xHeight?: AnyResolvedKeyframe | undefined;
    xlinkActuate?: string | undefined;
    xlinkArcrole?: string | undefined;
    xlinkHref?: string | undefined;
    xlinkRole?: string | undefined;
    xlinkShow?: string | undefined;
    xlinkTitle?: string | undefined;
    xlinkType?: string | undefined;
    xmlBase?: string | undefined;
    xmlLang?: string | undefined;
    xmlns?: string | undefined;
    xmlnsXlink?: string | undefined;
    xmlSpace?: string | undefined;
    y1?: AnyResolvedKeyframe | undefined;
    y2?: AnyResolvedKeyframe | undefined;
    y?: AnyResolvedKeyframe | undefined;
    yChannelSelector?: string | undefined;
    z?: AnyResolvedKeyframe | undefined;
    zoomAndPan?: string | undefined;
}

/**
 * An update function. It accepts a timestamp used to advance the animation.
 */
type Update$1 = (timestamp: number) => void;
/**
 * Drivers accept a update function and call it at an interval. This interval
 * could be a synchronous loop, a setInterval, or tied to the device's framerate.
 */
interface DriverControls {
    start: (keepAlive?: boolean) => void;
    stop: () => void;
    now: () => number;
}
type Driver = (update: Update$1) => DriverControls;

/**
 * Temporary subset of VisualElement until VisualElement is
 * moved to motion-dom
 */
interface WithRender {
    render: () => void;
    readValue: (name: string, keyframe: any) => any;
    getValue: (name: string, defaultValue?: any) => any;
    current?: HTMLElement | SVGElement;
    measureViewportBox: () => Box;
}

type AnyResolvedKeyframe = string | number;
interface ProgressTimeline {
    currentTime: null | {
        value: number;
    };
    cancel?: VoidFunction;
}
interface ValueAnimationOptionsWithRenderContext<V extends AnyResolvedKeyframe = number> extends ValueAnimationOptions<V> {
    KeyframeResolver?: typeof KeyframeResolver;
    motionValue?: MotionValue<V>;
    element?: WithRender;
}
interface TimelineWithFallback {
    timeline?: ProgressTimeline;
    observe: (animation: AnimationPlaybackControls) => VoidFunction;
}
/**
 * Methods to control an animation.
 */
interface AnimationPlaybackControls {
    /**
     * The current time of the animation, in seconds.
     */
    time: number;
    /**
     * The playback speed of the animation.
     * 1 = normal speed, 2 = double speed, 0.5 = half speed.
     */
    speed: number;
    /**
     * The start time of the animation, in milliseconds.
     */
    startTime: number | null;
    /**
     * The state of the animation.
     *
     * This is currently for internal use only.
     */
    state: AnimationPlayState;
    duration: number;
    /**
     * The duration of the animation, including any delay.
     */
    iterationDuration: number;
    /**
     * Stops the animation at its current state, and prevents it from
     * resuming when the animation is played again.
     */
    stop: () => void;
    /**
     * Plays the animation.
     */
    play: () => void;
    /**
     * Pauses the animation.
     */
    pause: () => void;
    /**
     * Completes the animation and applies the final state.
     */
    complete: () => void;
    /**
     * Cancels the animation and applies the initial state.
     */
    cancel: () => void;
    /**
     * Attaches a timeline to the animation, for instance the `ScrollTimeline`.
     *
     * This is currently for internal use only.
     */
    attachTimeline: (timeline: TimelineWithFallback) => VoidFunction;
    finished: Promise<any>;
}
type AnimationPlaybackControlsWithThen = AnimationPlaybackControls & {
    then: (onResolve: VoidFunction, onReject?: VoidFunction) => Promise<void>;
};
interface AnimationState$1<V> {
    value: V;
    done: boolean;
}
interface KeyframeGenerator<V> {
    calculatedDuration: null | number;
    next: (t: number) => AnimationState$1<V>;
    toString: () => string;
}
interface DOMValueAnimationOptions<V extends AnyResolvedKeyframe = number> extends ValueAnimationTransition<V> {
    element: HTMLElement | SVGElement;
    keyframes: ValueKeyframesDefinition;
    name: string;
    pseudoElement?: string;
    allowFlatten?: boolean;
}
interface ValueAnimationOptions<V extends AnyResolvedKeyframe = number> extends ValueAnimationTransition {
    keyframes: V[];
    element?: any;
    name?: string;
    motionValue?: MotionValue<V>;
    from?: any;
    isHandoff?: boolean;
    allowFlatten?: boolean;
    finalKeyframe?: V;
}
type GeneratorFactoryFunction = (options: ValueAnimationOptions<any>) => KeyframeGenerator<any>;
interface GeneratorFactory extends GeneratorFactoryFunction {
    applyToOptions?: (options: Transition) => Transition;
}
type AnimationGeneratorName = "decay" | "spring" | "keyframes" | "tween" | "inertia";
type AnimationGeneratorType = GeneratorFactory | AnimationGeneratorName | false;
interface AnimationPlaybackLifecycles<V> {
    onUpdate?: (latest: V) => void;
    onPlay?: () => void;
    onComplete?: () => void;
    onRepeat?: () => void;
    onStop?: () => void;
}
interface ValueAnimationTransition<V = any> extends ValueTransition, AnimationPlaybackLifecycles<V> {
    isSync?: boolean;
}
type RepeatType = "loop" | "reverse" | "mirror";
interface AnimationPlaybackOptions {
    /**
     * The number of times to repeat the transition. Set to `Infinity` for perpetual repeating.
     *
     * Without setting `repeatType`, this will loop the animation.
     *
     * @public
     */
    repeat?: number;
    /**
     * How to repeat the animation. This can be either:
     *
     * "loop": Repeats the animation from the start
     *
     * "reverse": Alternates between forward and backwards playback
     *
     * "mirror": Switches `from` and `to` alternately
     *
     * @public
     */
    repeatType?: RepeatType;
    /**
     * When repeating an animation, `repeatDelay` will set the
     * duration of the time to wait, in seconds, between each repetition.
     *
     * @public
     */
    repeatDelay?: number;
}
interface VelocityOptions {
    velocity?: number;
    /**
     * End animation if absolute speed (in units per second) drops below this
     * value and delta is smaller than `restDelta`. Set to `0.01` by default.
     *
     * @public
     */
    restSpeed?: number;
    /**
     * End animation if distance is below this value and speed is below
     * `restSpeed`. When animation ends, spring gets "snapped" to. Set to
     * `0.01` by default.
     *
     * @public
     */
    restDelta?: number;
}
interface DurationSpringOptions {
    /**
     * The total duration of the animation. Set to `0.3` by default.
     *
     * @public
     */
    duration?: number;
    /**
     * If visualDuration is set, this will override duration.
     *
     * The visual duration is a time, set in seconds, that the animation will take to visually appear to reach its target.
     *
     * In other words, the bulk of the transition will occur before this time, and the "bouncy bit" will mostly happen after.
     *
     * This makes it easier to edit a spring, as well as visually coordinate it with other time-based animations.
     *
     * @public
     */
    visualDuration?: number;
    /**
     * `bounce` determines the "bounciness" of a spring animation.
     *
     * `0` is no bounce, and `1` is extremely bouncy.
     *
     * If `duration` is set, this defaults to `0.25`.
     *
     * Note: `bounce` and `duration` will be overridden if `stiffness`, `damping` or `mass` are set.
     *
     * @public
     */
    bounce?: number;
}
interface SpringOptions extends DurationSpringOptions, VelocityOptions {
    /**
     * Stiffness of the spring. Higher values will create more sudden movement.
     * Set to `100` by default.
     *
     * @public
     */
    stiffness?: number;
    /**
     * Strength of opposing force. If set to 0, spring will oscillate
     * indefinitely. Set to `10` by default.
     *
     * @public
     */
    damping?: number;
    /**
     * Mass of the moving object. Higher values will result in more lethargic
     * movement. Set to `1` by default.
     *
     * @public
     */
    mass?: number;
}
/**
 * @deprecated Use SpringOptions instead
 */
interface Spring extends SpringOptions {
}
interface DecayOptions extends VelocityOptions {
    keyframes?: number[];
    /**
     * A higher power value equals a further target. Set to `0.8` by default.
     *
     * @public
     */
    power?: number;
    /**
     * Adjusting the time constant will change the duration of the
     * deceleration, thereby affecting its feel. Set to `700` by default.
     *
     * @public
     */
    timeConstant?: number;
    /**
     * A function that receives the automatically-calculated target and returns a new one. Useful for snapping the target to a grid.
     *
     * @public
     */
    modifyTarget?: (v: number) => number;
}
interface InertiaOptions extends DecayOptions {
    /**
     * If `min` or `max` is set, this affects the stiffness of the bounce
     * spring. Higher values will create more sudden movement. Set to `500` by
     * default.
     *
     * @public
     */
    bounceStiffness?: number;
    /**
     * If `min` or `max` is set, this affects the damping of the bounce spring.
     * If set to `0`, spring will oscillate indefinitely. Set to `10` by
     * default.
     *
     * @public
     */
    bounceDamping?: number;
    /**
     * Minimum constraint. If set, the value will "bump" against this value (or immediately spring to it if the animation starts as less than this value).
     *
     * @public
     */
    min?: number;
    /**
     * Maximum constraint. If set, the value will "bump" against this value (or immediately snap to it, if the initial animation value exceeds this value).
     *
     * @public
     */
    max?: number;
}
interface AnimationOrchestrationOptions {
    /**
     * Delay the animation by this duration (in seconds). Defaults to `0`.
     *
     * @public
     */
    delay?: number;
    /**
     * Describes the relationship between the transition and its children. Set
     * to `false` by default.
     *
     * @remarks
     * When using variants, the transition can be scheduled in relation to its
     * children with either `"beforeChildren"` to finish this transition before
     * starting children transitions, `"afterChildren"` to finish children
     * transitions before starting this transition.
     *
     * @public
     */
    when?: false | "beforeChildren" | "afterChildren" | string;
    /**
     * When using variants, children animations will start after this duration
     * (in seconds). You can add the `transition` property to both the `motion.div` and the
     * `variant` directly. Adding it to the `variant` generally offers more flexibility,
     * as it allows you to customize the delay per visual state.
     *
     * @public
     */
    delayChildren?: number | DynamicOption<number>;
    /**
     * When using variants, animations of child components can be staggered by this
     * duration (in seconds).
     *
     * For instance, if `staggerChildren` is `0.01`, the first child will be
     * delayed by `0` seconds, the second by `0.01`, the third by `0.02` and so
     * on.
     *
     * The calculated stagger delay will be added to `delayChildren`.
     *
     * @deprecated - Use `delayChildren: stagger(interval)` instead.
     */
    staggerChildren?: number;
    /**
     * The direction in which to stagger children.
     *
     * A value of `1` staggers from the first to the last while `-1`
     * staggers from the last to the first.
     *
     * @deprecated - Use `delayChildren: stagger(interval, { from: "last" })` instead.
     */
    staggerDirection?: number;
}
interface KeyframeOptions {
    /**
     * The total duration of the animation. Set to `0.3` by default.
     *
     * @public
     */
    duration?: number;
    ease?: Easing | Easing[];
    times?: number[];
}
interface ValueTransition extends AnimationOrchestrationOptions, AnimationPlaybackOptions, Omit<SpringOptions, "keyframes">, Omit<InertiaOptions, "keyframes">, KeyframeOptions {
    /**
     * Delay the animation by this duration (in seconds). Defaults to `0`.
     *
     * @public
     */
    delay?: number;
    /**
     * The duration of time already elapsed in the animation. Set to `0` by
     * default.
     */
    elapsed?: number;
    driver?: Driver;
    /**
     * Type of animation to use.
     *
     * - "tween": Duration-based animation with ease curve
     * - "spring": Physics or duration-based spring animation
     * - false: Use an instant animation
     */
    type?: AnimationGeneratorType;
    /**
     * The duration of the tween animation. Set to `0.3` by default, 0r `0.8` if animating a series of keyframes.
     *
     * @public
     */
    duration?: number;
    autoplay?: boolean;
    startTime?: number;
    from?: any;
}
/**
 * @deprecated Use KeyframeOptions instead
 */
interface Tween extends KeyframeOptions {
}
type SVGForcedAttrTransitions = {
    [K in keyof SVGForcedAttrProperties]: ValueTransition;
};
type SVGPathTransitions = {
    [K in keyof SVGPathProperties]: ValueTransition;
};
type SVGTransitions = {
    [K in keyof Omit<SVGAttributes, "from">]: ValueTransition;
};
interface VariableTransitions {
    [key: `--${string}`]: ValueTransition;
}
type StyleTransitions = {
    [K in keyof CSSStyleDeclarationWithTransform]?: ValueTransition;
};
type ValueKeyframe<T extends AnyResolvedKeyframe = AnyResolvedKeyframe> = T;
type UnresolvedValueKeyframe<T extends AnyResolvedKeyframe = AnyResolvedKeyframe> = ValueKeyframe<T> | null;
type ResolvedValueKeyframe = ValueKeyframe | ValueKeyframe[];
type ValueKeyframesDefinition = ValueKeyframe | ValueKeyframe[] | UnresolvedValueKeyframe[];
type StyleKeyframesDefinition = {
    [K in keyof CSSStyleDeclarationWithTransform]?: ValueKeyframesDefinition;
};
type SVGKeyframesDefinition = {
    [K in keyof Omit<SVGAttributes, "from">]?: ValueKeyframesDefinition;
};
interface VariableKeyframesDefinition {
    [key: `--${string}`]: ValueKeyframesDefinition;
}
type SVGForcedAttrKeyframesDefinition = {
    [K in keyof SVGForcedAttrProperties]?: ValueKeyframesDefinition;
};
type SVGPathKeyframesDefinition = {
    [K in keyof SVGPathProperties]?: ValueKeyframesDefinition;
};
type DOMKeyframesDefinition = StyleKeyframesDefinition & SVGKeyframesDefinition & SVGPathKeyframesDefinition & SVGForcedAttrKeyframesDefinition & VariableKeyframesDefinition;
interface Target extends DOMKeyframesDefinition {
}
type CSSPropertyKeys = {
    [K in keyof CSSStyleDeclaration as K extends string ? CSSStyleDeclaration[K] extends AnyResolvedKeyframe ? K : never : never]: CSSStyleDeclaration[K];
};
interface CSSStyleDeclarationWithTransform extends Omit<CSSPropertyKeys, "direction" | "transition" | "x" | "y" | "z"> {
    x: number | string;
    y: number | string;
    z: number | string;
    originX: number;
    originY: number;
    originZ: number;
    translateX: number | string;
    translateY: number | string;
    translateZ: number | string;
    rotateX: number | string;
    rotateY: number | string;
    rotateZ: number | string;
    scaleX: number;
    scaleY: number;
    scaleZ: number;
    skewX: number | string;
    skewY: number | string;
    transformPerspective: number;
}
type TransitionWithValueOverrides<V> = ValueAnimationTransition<V> & StyleTransitions & SVGPathTransitions & SVGForcedAttrTransitions & SVGTransitions & VariableTransitions & {
    default?: ValueTransition;
    layout?: ValueTransition;
};
type Transition<V = any> = ValueAnimationTransition<V> | TransitionWithValueOverrides<V>;
type DynamicOption<T> = (i: number, total: number) => T;
type ValueAnimationWithDynamicDelay = Omit<ValueAnimationTransition<any>, "delay"> & {
    delay?: number | DynamicOption<number>;
};
type AnimationOptions = ValueAnimationWithDynamicDelay | (ValueAnimationWithDynamicDelay & StyleTransitions & SVGPathTransitions & SVGForcedAttrTransitions & SVGTransitions & VariableTransitions & {
    default?: ValueTransition;
    layout?: ValueTransition;
});
interface TransformProperties {
    x?: AnyResolvedKeyframe;
    y?: AnyResolvedKeyframe;
    z?: AnyResolvedKeyframe;
    translateX?: AnyResolvedKeyframe;
    translateY?: AnyResolvedKeyframe;
    translateZ?: AnyResolvedKeyframe;
    rotate?: AnyResolvedKeyframe;
    rotateX?: AnyResolvedKeyframe;
    rotateY?: AnyResolvedKeyframe;
    rotateZ?: AnyResolvedKeyframe;
    scale?: AnyResolvedKeyframe;
    scaleX?: AnyResolvedKeyframe;
    scaleY?: AnyResolvedKeyframe;
    scaleZ?: AnyResolvedKeyframe;
    skew?: AnyResolvedKeyframe;
    skewX?: AnyResolvedKeyframe;
    skewY?: AnyResolvedKeyframe;
    originX?: AnyResolvedKeyframe;
    originY?: AnyResolvedKeyframe;
    originZ?: AnyResolvedKeyframe;
    perspective?: AnyResolvedKeyframe;
    transformPerspective?: AnyResolvedKeyframe;
}
interface SVGForcedAttrProperties {
    attrX?: number;
    attrY?: number;
    attrScale?: number;
}
interface SVGPathProperties {
    pathLength?: number;
    pathOffset?: number;
    pathSpacing?: number;
}

/**
 * @public
 */
type Subscriber<T> = (v: T) => void;
/**
 * @public
 */
type PassiveEffect<T> = (v: T, safeSetter: (v: T) => void) => void;
type StartAnimation = (complete: () => void) => AnimationPlaybackControlsWithThen | undefined;
interface MotionValueEventCallbacks<V> {
    animationStart: () => void;
    animationComplete: () => void;
    animationCancel: () => void;
    change: (latestValue: V) => void;
    destroy: () => void;
}
interface ResolvedValues {
    [key: string]: AnyResolvedKeyframe;
}
interface Owner {
    current: HTMLElement | unknown;
    getProps: () => {
        onUpdate?: (latest: ResolvedValues) => void;
        transformTemplate?: (transform: TransformProperties, generatedTransform: string) => string;
    };
}
interface MotionValueOptions {
    owner?: Owner;
}
declare const collectMotionValues: {
    current: MotionValue[] | undefined;
};
/**
 * `MotionValue` is used to track the state and velocity of motion values.
 *
 * @public
 */
declare class MotionValue<V = any> {
    /**
     * If a MotionValue has an owner, it was created internally within Motion
     * and therefore has no external listeners. It is therefore safe to animate via WAAPI.
     */
    owner?: Owner;
    /**
     * The current state of the `MotionValue`.
     */
    private current;
    /**
     * The previous state of the `MotionValue`.
     */
    private prev;
    /**
     * The previous state of the `MotionValue` at the end of the previous frame.
     */
    private prevFrameValue;
    /**
     * The last time the `MotionValue` was updated.
     */
    updatedAt: number;
    /**
     * The time `prevFrameValue` was updated.
     */
    prevUpdatedAt: number | undefined;
    private stopPassiveEffect?;
    /**
     * Whether the passive effect is active.
     */
    isEffectActive?: boolean;
    /**
     * A reference to the currently-controlling animation.
     */
    animation?: AnimationPlaybackControlsWithThen;
    /**
     * A list of MotionValues whose values are computed from this one.
     * This is a rough start to a proper signal-like dirtying system.
     */
    private dependents;
    /**
     * Tracks whether this value should be removed
     */
    liveStyle?: boolean;
    /**
     * @param init - The initiating value
     * @param config - Optional configuration options
     *
     * -  `transformer`: A function to transform incoming values with.
     */
    constructor(init: V, options?: MotionValueOptions);
    setCurrent(current: V): void;
    setPrevFrameValue(prevFrameValue?: V | undefined): void;
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
    onChange(subscription: Subscriber<V>): () => void;
    /**
     * An object containing a SubscriptionManager for each active event.
     */
    private events;
    on<EventName extends keyof MotionValueEventCallbacks<V>>(eventName: EventName, callback: MotionValueEventCallbacks<V>[EventName]): VoidFunction;
    clearListeners(): void;
    /**
     * Attaches a passive effect to the `MotionValue`.
     */
    attach(passiveEffect: PassiveEffect<V>, stopPassiveEffect: VoidFunction): void;
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
    set(v: V): void;
    setWithVelocity(prev: V, current: V, delta: number): void;
    /**
     * Set the state of the `MotionValue`, stopping any active animations,
     * effects, and resets velocity to `0`.
     */
    jump(v: V, endAnimation?: boolean): void;
    dirty(): void;
    addDependent(dependent: MotionValue): void;
    removeDependent(dependent: MotionValue): void;
    updateAndNotify: (v: V) => void;
    /**
     * Returns the latest state of `MotionValue`
     *
     * @returns - The latest state of `MotionValue`
     *
     * @public
     */
    get(): NonNullable<V>;
    /**
     * @public
     */
    getPrevious(): V | undefined;
    /**
     * Returns the latest velocity of `MotionValue`
     *
     * @returns - The latest velocity of `MotionValue`. Returns `0` if the state is non-numerical.
     *
     * @public
     */
    getVelocity(): number;
    hasAnimated: boolean;
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
    start(startAnimation: StartAnimation): Promise<void>;
    /**
     * Stop the currently active animation.
     *
     * @public
     */
    stop(): void;
    /**
     * Returns `true` if this value is currently animating.
     *
     * @public
     */
    isAnimating(): boolean;
    private clearAnimation;
    /**
     * Destroy and clean up subscribers to this `MotionValue`.
     *
     * The `MotionValue` hooks like `useMotionValue` and `useTransform` automatically
     * handle the lifecycle of the returned `MotionValue`, so this method is only necessary if you've manually
     * created a `MotionValue` via the `motionValue` function.
     *
     * @public
     */
    destroy(): void;
}
declare function motionValue<V>(init: V, options?: MotionValueOptions): MotionValue<V>;

type UnresolvedKeyframes<T extends AnyResolvedKeyframe> = Array<T | null>;
type ResolvedKeyframes<T extends AnyResolvedKeyframe> = Array<T>;
declare function flushKeyframeResolvers(): void;
type OnKeyframesResolved<T extends AnyResolvedKeyframe> = (resolvedKeyframes: ResolvedKeyframes<T>, finalKeyframe: T, forced: boolean) => void;
declare class KeyframeResolver<T extends AnyResolvedKeyframe = any> {
    name?: string;
    element?: WithRender;
    finalKeyframe?: T;
    suspendedScrollY?: number;
    protected unresolvedKeyframes: UnresolvedKeyframes<AnyResolvedKeyframe>;
    private motionValue?;
    private onComplete;
    state: "pending" | "scheduled" | "complete";
    /**
     * Track whether this resolver is async. If it is, it'll be added to the
     * resolver queue and flushed in the next frame. Resolvers that aren't going
     * to trigger read/write thrashing don't need to be async.
     */
    private isAsync;
    /**
     * Track whether this resolver needs to perform a measurement
     * to resolve its keyframes.
     */
    needsMeasurement: boolean;
    constructor(unresolvedKeyframes: UnresolvedKeyframes<AnyResolvedKeyframe>, onComplete: OnKeyframesResolved<T>, name?: string, motionValue?: MotionValue<T>, element?: WithRender, isAsync?: boolean);
    scheduleResolve(): void;
    readKeyframes(): void;
    setFinalKeyframe(): void;
    measureInitialState(): void;
    renderEndStyles(): void;
    measureEndState(): void;
    complete(isForcedComplete?: boolean): void;
    cancel(): void;
    resume(): void;
}

declare class WithPromise {
    protected _finished: Promise<void>;
    resolve: VoidFunction;
    constructor();
    get finished(): Promise<void>;
    protected updateFinished(): void;
    protected notifyFinished(): void;
    /**
     * Allows the animation to be awaited.
     *
     * @deprecated Use `finished` instead.
     */
    then(onResolve: VoidFunction, onReject?: VoidFunction): Promise<void>;
}

type OptionsWithoutKeyframes<T extends AnyResolvedKeyframe> = Omit<ValueAnimationOptions<T>, "keyframes">;
declare class AsyncMotionValueAnimation<T extends AnyResolvedKeyframe> extends WithPromise implements AnimationPlaybackControls {
    private createdAt;
    private resolvedAt;
    private _animation;
    private pendingTimeline;
    private keyframeResolver;
    private stopTimeline;
    constructor({ autoplay, delay, type, repeat, repeatDelay, repeatType, keyframes, name, motionValue, element, ...options }: ValueAnimationOptions<T>);
    onKeyframesResolved(keyframes: ResolvedKeyframes<T>, finalKeyframe: T, options: OptionsWithoutKeyframes<T>, sync: boolean): void;
    get finished(): Promise<any>;
    then(onResolve: VoidFunction, _onReject?: VoidFunction): Promise<void>;
    get animation(): AnimationPlaybackControls;
    get duration(): number;
    get iterationDuration(): number;
    get time(): number;
    set time(newTime: number);
    get speed(): number;
    get state(): AnimationPlayState;
    set speed(newSpeed: number);
    get startTime(): number | null;
    attachTimeline(timeline: TimelineWithFallback): () => void;
    play(): void;
    pause(): void;
    complete(): void;
    cancel(): void;
    /**
     * Bound to support return animation.stop pattern
     */
    stop: () => void;
}

type AcceptedAnimations = AnimationPlaybackControls;
type GroupedAnimations = AcceptedAnimations[];
declare class GroupAnimation implements AnimationPlaybackControls {
    animations: GroupedAnimations;
    constructor(animations: Array<AcceptedAnimations | undefined>);
    get finished(): Promise<any[]>;
    /**
     * TODO: Filter out cancelled or stopped animations before returning
     */
    private getAll;
    private setAll;
    attachTimeline(timeline: TimelineWithFallback): () => void;
    get time(): number;
    set time(time: number);
    get speed(): number;
    set speed(speed: number);
    get state(): any;
    get startTime(): any;
    get duration(): number;
    get iterationDuration(): number;
    private runAll;
    play(): void;
    pause(): void;
    stop: () => void;
    cancel(): void;
    complete(): void;
}

declare class GroupAnimationWithThen extends GroupAnimation implements AnimationPlaybackControlsWithThen {
    then(onResolve: VoidFunction, _onReject?: VoidFunction): Promise<void>;
}

declare class JSAnimation<T extends number | string> extends WithPromise implements AnimationPlaybackControlsWithThen {
    state: AnimationPlayState;
    startTime: number | null;
    /**
     * The driver that's controlling the animation loop. Normally this is a requestAnimationFrame loop
     * but in tests we can pass in a synchronous loop.
     */
    private driver?;
    private isStopped;
    private generator;
    private calculatedDuration;
    private resolvedDuration;
    private totalDuration;
    private options;
    /**
     * The current time of the animation.
     */
    private currentTime;
    /**
     * The time at which the animation was paused.
     */
    private holdTime;
    /**
     * Playback speed as a factor. 0 would be stopped, -1 reverse and 2 double speed.
     */
    private playbackSpeed;
    private mixKeyframes;
    private mirroredGenerator;
    constructor(options: ValueAnimationOptions<T>);
    initAnimation(): void;
    updateTime(timestamp: number): void;
    tick(timestamp: number, sample?: boolean): AnimationState$1<T>;
    /**
     * Allows the returned animation to be awaited or promise-chained. Currently
     * resolves when the animation finishes at all but in a future update could/should
     * reject if its cancels.
     */
    then(resolve: VoidFunction, reject?: VoidFunction): Promise<void>;
    get duration(): number;
    get iterationDuration(): number;
    get time(): number;
    set time(newTime: number);
    get speed(): number;
    set speed(newSpeed: number);
    play(): void;
    pause(): void;
    /**
     * This method is bound to the instance to fix a pattern where
     * animation.stop is returned as a reference from a useEffect.
     */
    stop: () => void;
    complete(): void;
    finish(): void;
    cancel(): void;
    private teardown;
    private stopDriver;
    sample(sampleTime: number): AnimationState$1<T>;
    attachTimeline(timeline: TimelineWithFallback): VoidFunction;
}
declare function animateValue<T extends number | string>(options: ValueAnimationOptions<T>): JSAnimation<T>;

interface NativeAnimationOptions<V extends AnyResolvedKeyframe = number> extends DOMValueAnimationOptions<V> {
    pseudoElement?: string;
    startTime?: number;
}
/**
 * NativeAnimation implements AnimationPlaybackControls for the browser's Web Animations API.
 */
declare class NativeAnimation<T extends AnyResolvedKeyframe> extends WithPromise implements AnimationPlaybackControlsWithThen {
    /**
     * The interfaced Web Animation API animation
     */
    protected animation: Animation;
    protected finishedTime: number | null;
    protected options: NativeAnimationOptions;
    private allowFlatten;
    private isStopped;
    private isPseudoElement;
    /**
     * Tracks a manually-set start time that takes precedence over WAAPI's
     * dynamic startTime. This is cleared when play() or time setter is called,
     * allowing WAAPI to take over timing.
     */
    protected manualStartTime: number | null;
    constructor(options?: NativeAnimationOptions);
    updateMotionValue?(value?: T): void;
    play(): void;
    pause(): void;
    complete(): void;
    cancel(): void;
    stop(): void;
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
    protected commitStyles(): void;
    get duration(): number;
    get iterationDuration(): number;
    get time(): number;
    set time(newTime: number);
    /**
     * The playback speed of the animation.
     * 1 = normal speed, 2 = double speed, 0.5 = half speed.
     */
    get speed(): number;
    set speed(newSpeed: number);
    get state(): AnimationPlayState;
    get startTime(): number;
    set startTime(newStartTime: number);
    /**
     * Attaches a timeline to the animation, for instance the `ScrollTimeline`.
     */
    attachTimeline({ timeline, observe }: TimelineWithFallback): VoidFunction;
}

type NativeAnimationOptionsExtended<T extends AnyResolvedKeyframe> = NativeAnimationOptions & ValueAnimationOptions<T> & NativeAnimationOptions;
declare class NativeAnimationExtended<T extends AnyResolvedKeyframe> extends NativeAnimation<T> {
    options: NativeAnimationOptionsExtended<T>;
    constructor(options: NativeAnimationOptionsExtended<T>);
    /**
     * WAAPI doesn't natively have any interruption capabilities.
     *
     * Rather than read committed styles back out of the DOM, we can
     * create a renderless JS animation and sample it twice to calculate
     * its current value, "previous" value, and therefore allow
     * Motion to calculate velocity for any subsequent animation.
     */
    updateMotionValue(value?: T): void;
}

declare class NativeAnimationWrapper<T extends AnyResolvedKeyframe> extends NativeAnimation<T> {
    constructor(animation: Animation);
}

declare const animationMapKey: (name: string, pseudoElement?: string) => string;
declare function getAnimationMap(element: Element): Map<any, any>;

interface VisualElementAnimationOptions {
    delay?: number;
    transitionOverride?: Transition;
    custom?: any;
    type?: AnimationType;
}

interface AnimationState {
    animateChanges: (type?: AnimationType) => Promise<any>;
    setActive: (type: AnimationType, isActive: boolean, options?: VisualElementAnimationOptions) => Promise<any>;
    setAnimateFunction: (fn: any) => void;
    getState: () => {
        [key: string]: AnimationTypeState;
    };
    reset: () => void;
}
type AnimationList = string[] | TargetAndTransition[];
declare function createAnimationState(visualElement: any): AnimationState;
declare function checkVariantsDidChange(prev: any, next: any): boolean;
interface AnimationTypeState {
    isActive: boolean;
    protectedKeys: {
        [key: string]: true;
    };
    needsAnimating: {
        [key: string]: boolean;
    };
    prevResolvedValues: {
        [key: string]: any;
    };
    prevProp?: VariantLabels | TargetAndTransition;
}

/**
 * Set feature definitions for all VisualElements.
 * This should be called by the framework layer (e.g., framer-motion) during initialization.
 */
declare function setFeatureDefinitions(definitions: Partial<FeatureDefinitions>): void;
/**
 * Get the current feature definitions
 */
declare function getFeatureDefinitions(): Partial<FeatureDefinitions>;
/**
 * Motion style type - a subset of CSS properties that can contain motion values
 */
type MotionStyle = {
    [K: string]: AnyResolvedKeyframe | MotionValue | undefined;
};
/**
 * A VisualElement is an imperative abstraction around UI elements such as
 * HTMLElement, SVGElement, Three.Object3D etc.
 */
declare abstract class VisualElement<Instance = unknown, RenderState = unknown, Options extends {} = {}> {
    /**
     * VisualElements are arranged in trees mirroring that of the React tree.
     * Each type of VisualElement has a unique name, to detect when we're crossing
     * type boundaries within that tree.
     */
    abstract type: string;
    /**
     * An `Array.sort` compatible function that will compare two Instances and
     * compare their respective positions within the tree.
     */
    abstract sortInstanceNodePosition(a: Instance, b: Instance): number;
    /**
     * Measure the viewport-relative bounding box of the Instance.
     */
    abstract measureInstanceViewportBox(instance: Instance, props: MotionNodeOptions & Partial<MotionConfigContextProps>): Box;
    /**
     * When a value has been removed from all animation props we need to
     * pick a target to animate back to. For instance, for HTMLElements
     * we can look in the style prop.
     */
    abstract getBaseTargetFromProps(props: MotionNodeOptions, key: string): AnyResolvedKeyframe | undefined | MotionValue;
    /**
     * When we first animate to a value we need to animate it *from* a value.
     * Often this have been specified via the initial prop but it might be
     * that the value needs to be read from the Instance.
     */
    abstract readValueFromInstance(instance: Instance, key: string, options: Options): AnyResolvedKeyframe | null | undefined;
    /**
     * When a value has been removed from the VisualElement we use this to remove
     * it from the inherting class' unique render state.
     */
    abstract removeValueFromRenderState(key: string, renderState: RenderState): void;
    /**
     * Run before a React or VisualElement render, builds the latest motion
     * values into an Instance-specific format. For example, HTMLVisualElement
     * will use this step to build `style` and `var` values.
     */
    abstract build(renderState: RenderState, latestValues: ResolvedValues$1, props: MotionNodeOptions): void;
    /**
     * Apply the built values to the Instance. For example, HTMLElements will have
     * styles applied via `setProperty` and the style attribute, whereas SVGElements
     * will have values applied to attributes.
     */
    abstract renderInstance(instance: Instance, renderState: RenderState, styleProp?: MotionStyle, projection?: any): void;
    /**
     * This method is called when a transform property is bound to a motion value.
     * It's currently used to measure SVG elements when a new transform property is bound.
     */
    onBindTransform?(): void;
    /**
     * If the component child is provided as a motion value, handle subscriptions
     * with the renderer-specific VisualElement.
     */
    handleChildMotionValue?(): void;
    /**
     * This method takes React props and returns found MotionValues. For example, HTML
     * MotionValues will be found within the style prop, whereas for Three.js within attribute arrays.
     *
     * This isn't an abstract method as it needs calling in the constructor, but it is
     * intended to be one.
     */
    scrapeMotionValuesFromProps(_props: MotionNodeOptions, _prevProps: MotionNodeOptions, _visualElement: VisualElement): {
        [key: string]: MotionValue | AnyResolvedKeyframe;
    };
    /**
     * A reference to the current underlying Instance, e.g. a HTMLElement
     * or Three.Mesh etc.
     */
    current: Instance | null;
    /**
     * A reference to the parent VisualElement (if exists).
     */
    parent: VisualElement | undefined;
    /**
     * A set containing references to this VisualElement's children.
     */
    children: Set<VisualElement<unknown, unknown, {}>>;
    /**
     * A set containing the latest children of this VisualElement. This is flushed
     * at the start of every commit. We use it to calculate the stagger delay
     * for newly-added children.
     */
    enteringChildren?: Set<VisualElement>;
    /**
     * The depth of this VisualElement within the overall VisualElement tree.
     */
    depth: number;
    /**
     * The current render state of this VisualElement. Defined by inherting VisualElements.
     */
    renderState: RenderState;
    /**
     * An object containing the latest static values for each of this VisualElement's
     * MotionValues.
     */
    latestValues: ResolvedValues$1;
    /**
     * Determine what role this visual element should take in the variant tree.
     */
    isVariantNode: boolean;
    isControllingVariants: boolean;
    /**
     * If this component is part of the variant tree, it should track
     * any children that are also part of the tree. This is essentially
     * a shadow tree to simplify logic around how to stagger over children.
     */
    variantChildren?: Set<VisualElement>;
    /**
     * Decides whether this VisualElement should animate in reduced motion
     * mode.
     *
     * TODO: This is currently set on every individual VisualElement but feels
     * like it could be set globally.
     */
    shouldReduceMotion: boolean | null;
    /**
     * Normally, if a component is controlled by a parent's variants, it can
     * rely on that ancestor to trigger animations further down the tree.
     * However, if a component is created after its parent is mounted, the parent
     * won't trigger that mount animation so the child needs to.
     *
     * TODO: This might be better replaced with a method isParentMounted
     */
    manuallyAnimateOnMount: boolean;
    /**
     * This can be set by AnimatePresence to force components that mount
     * at the same time as it to mount as if they have initial={false} set.
     */
    blockInitialAnimation: boolean;
    /**
     * A reference to this VisualElement's projection node, used in layout animations.
     */
    projection?: any;
    /**
     * A map of all motion values attached to this visual element. Motion
     * values are source of truth for any given animated value. A motion
     * value might be provided externally by the component via props.
     */
    values: Map<string, MotionValue<any>>;
    /**
     * The AnimationState, this is hydrated by the animation Feature.
     */
    animationState?: AnimationState;
    KeyframeResolver: typeof KeyframeResolver;
    /**
     * The options used to create this VisualElement. The Options type is defined
     * by the inheriting VisualElement and is passed straight through to the render functions.
     */
    readonly options: Options;
    /**
     * A reference to the latest props provided to the VisualElement's host React component.
     */
    props: MotionNodeOptions;
    prevProps?: MotionNodeOptions;
    presenceContext: PresenceContextProps | null;
    prevPresenceContext?: PresenceContextProps | null;
    /**
     * Cleanup functions for active features (hover/tap/exit etc)
     */
    private features;
    /**
     * A map of every subscription that binds the provided or generated
     * motion values onChange listeners to this visual element.
     */
    private valueSubscriptions;
    /**
     * A reference to the ReducedMotionConfig passed to the VisualElement's host React component.
     */
    private reducedMotionConfig;
    /**
     * On mount, this will be hydrated with a callback to disconnect
     * this visual element from its parent on unmount.
     */
    private removeFromVariantTree;
    /**
     * A reference to the previously-provided motion values as returned
     * from scrapeMotionValuesFromProps. We use the keys in here to determine
     * if any motion values need to be removed after props are updated.
     */
    private prevMotionValues;
    /**
     * When values are removed from all animation props we need to search
     * for a fallback value to animate to. These values are tracked in baseTarget.
     */
    private baseTarget;
    /**
     * Create an object of the values we initially animated from (if initial prop present).
     */
    private initialValues;
    /**
     * An object containing a SubscriptionManager for each active event.
     */
    private events;
    /**
     * An object containing an unsubscribe function for each prop event subscription.
     * For example, every "Update" event can have multiple subscribers via
     * VisualElement.on(), but only one of those can be defined via the onUpdate prop.
     */
    private propEventSubscriptions;
    constructor({ parent, props, presenceContext, reducedMotionConfig, blockInitialAnimation, visualState, }: VisualElementOptions<Instance, RenderState>, options?: Options);
    mount(instance: Instance): void;
    unmount(): void;
    addChild(child: VisualElement): void;
    removeChild(child: VisualElement): void;
    private bindToMotionValue;
    sortNodePosition(other: VisualElement<Instance>): number;
    updateFeatures(): void;
    notifyUpdate: () => void;
    triggerBuild(): void;
    render: () => void;
    private renderScheduledAt;
    scheduleRender: () => void;
    /**
     * Measure the current viewport box with or without transforms.
     * Only measures axis-aligned boxes, rotate and skew must be manually
     * removed with a re-render to work.
     */
    measureViewportBox(): Box;
    getStaticValue(key: string): AnyResolvedKeyframe;
    setStaticValue(key: string, value: AnyResolvedKeyframe): void;
    /**
     * Update the provided props. Ensure any newly-added motion values are
     * added to our map, old ones removed, and listeners updated.
     */
    update(props: MotionNodeOptions, presenceContext: PresenceContextProps | null): void;
    getProps(): MotionNodeOptions;
    /**
     * Returns the variant definition with a given name.
     */
    getVariant(name: string): Variant | undefined;
    /**
     * Returns the defined default transition on this component.
     */
    getDefaultTransition(): Transition | undefined;
    getTransformPagePoint(): any;
    getClosestVariantNode(): VisualElement | undefined;
    /**
     * Add a child visual element to our set of children.
     */
    addVariantChild(child: VisualElement): (() => boolean) | undefined;
    /**
     * Add a motion value and bind it to this visual element.
     */
    addValue(key: string, value: MotionValue): void;
    /**
     * Remove a motion value and unbind any active subscriptions.
     */
    removeValue(key: string): void;
    /**
     * Check whether we have a motion value for this key
     */
    hasValue(key: string): boolean;
    /**
     * Get a motion value for this key. If called with a default
     * value, we'll create one if none exists.
     */
    getValue(key: string): MotionValue | undefined;
    getValue(key: string, defaultValue: AnyResolvedKeyframe | null): MotionValue;
    /**
     * If we're trying to animate to a previously unencountered value,
     * we need to check for it in our state and as a last resort read it
     * directly from the instance (which might have performance implications).
     */
    readValue(key: string, target?: AnyResolvedKeyframe | null): any;
    /**
     * Set the base target to later animate back to. This is currently
     * only hydrated on creation and when we first read a value.
     */
    setBaseTarget(key: string, value: AnyResolvedKeyframe): void;
    /**
     * Find the base target for a value thats been removed from all animation
     * props.
     */
    getBaseTarget(key: string): ResolvedValues$1[string] | undefined | null;
    on<EventName extends keyof VisualElementEventCallbacks>(eventName: EventName, callback: VisualElementEventCallbacks[EventName]): VoidFunction;
    notify<EventName extends keyof VisualElementEventCallbacks>(eventName: EventName, ...args: any): void;
    scheduleRenderMicrotask(): void;
}

declare function calcChildStagger(children: Set<VisualElement>, child: VisualElement, delayChildren?: number | DynamicOption<number>, staggerChildren?: number, staggerDirection?: number): number;

type CSSVariableName = `--${string}`;
type CSSVariableToken = `var(${CSSVariableName})`;
declare const isCSSVariableName: (key?: AnyResolvedKeyframe | null) => key is `--${string}`;
declare const isCSSVariableToken: (value?: string) => value is `var(--${string})`;
/**
 * Check if a value contains a CSS variable anywhere (e.g. inside calc()).
 * Unlike isCSSVariableToken which checks if the value IS a var() token,
 * this checks if the value CONTAINS var() somewhere in the string.
 */
declare function containsCSSVariable(value?: AnyResolvedKeyframe | null): boolean;

declare function parseCSSVariable(current: string): string[] | undefined[];
declare function getVariableValue(current: CSSVariableToken, element: Element, depth?: number): AnyResolvedKeyframe | undefined;

declare const getDefaultTransition: (valueKey: string, { keyframes }: ValueAnimationOptions) => Partial<ValueAnimationOptions>;

declare function getFinalKeyframe<T>(keyframes: T[], { repeat, repeatType }: AnimationPlaybackOptions, finalKeyframe?: T): T;

declare function getValueTransition(transition: any, key: string): any;

/**
 * Decide whether a transition is defined on a given Transition.
 * This filters out orchestration options and returns true
 * if any options are left.
 */
declare function isTransitionDefined({ when, delay: _delay, delayChildren, staggerChildren, staggerDirection, repeat, repeatType, repeatDelay, from, elapsed, ...transition }: Transition & {
    elapsed?: number;
    from?: AnyResolvedKeyframe;
}): boolean;

declare function makeAnimationInstant(options: Partial<{
    duration: ValueAnimationOptions["duration"];
    type: ValueAnimationOptions["type"];
}>): void;

declare const animateMotionValue: <V extends AnyResolvedKeyframe>(name: string, value: MotionValue<V>, target: V | UnresolvedKeyframes<V>, transition?: ValueTransition & {
    elapsed?: number;
}, element?: VisualElement<any>, isHandoff?: boolean) => StartAnimation;

declare function animateVisualElement(visualElement: VisualElement, definition: AnimationDefinition, options?: VisualElementAnimationOptions): Promise<void>;

declare function animateTarget(visualElement: VisualElement, targetAndTransition: TargetAndTransition, { delay, transitionOverride, type }?: VisualElementAnimationOptions): AnimationPlaybackControlsWithThen[];

declare function animateVariant(visualElement: VisualElement, variant: string, options?: VisualElementAnimationOptions): Promise<any>;

declare const optimizedAppearDataId = "framerAppearId";
declare const optimizedAppearDataAttribute: "data-framer-appear-id";

type Process = (data: FrameData) => void;
type Schedule = (process: Process, keepAlive?: boolean, immediate?: boolean) => Process;
interface Step {
    schedule: Schedule;
    cancel: (process: Process) => void;
    process: (data: FrameData) => void;
}
type StepId = "setup" | "read" | "resolveKeyframes" | "preUpdate" | "update" | "preRender" | "render" | "postRender";
type CancelProcess = (process: Process) => void;
type Batcher = {
    [key in StepId]: Schedule;
};
type Steps = {
    [key in StepId]: Step;
};
interface FrameData {
    delta: number;
    timestamp: number;
    isProcessing: boolean;
}

/**
 * Expose only the needed part of the VisualElement interface to
 * ensure React types don't end up in the generic DOM bundle.
 */
interface WithAppearProps {
    props: {
        [optimizedAppearDataAttribute]?: string;
        values?: {
            [key: string]: MotionValue<number> | MotionValue<string>;
        };
    };
}
type HandoffFunction = (storeId: string, valueName: string, frame: Batcher) => number | null;
/**
 * The window global object acts as a bridge between our inline script
 * triggering the optimized appear animations, and Motion.
 */
declare global {
    interface Window {
        MotionHandoffAnimation?: HandoffFunction;
        MotionHandoffMarkAsComplete?: (elementId: string) => void;
        MotionHandoffIsComplete?: (elementId: string) => boolean;
        MotionHasOptimisedAnimation?: (elementId?: string, valueName?: string) => boolean;
        MotionCancelOptimisedAnimation?: (elementId?: string, valueName?: string, frame?: Batcher, canResume?: boolean) => void;
        MotionCheckAppearSync?: (visualElement: WithAppearProps, valueName: string, value: MotionValue) => VoidFunction | void;
        MotionIsMounted?: boolean;
    }
}

declare function getOptimisedAppearId(visualElement: WithAppearProps): string | undefined;

declare function inertia({ keyframes, velocity, power, timeConstant, bounceDamping, bounceStiffness, modifyTarget, min, max, restDelta, restSpeed, }: ValueAnimationOptions<number>): KeyframeGenerator<number>;

declare function defaultEasing(values: any[], easing?: EasingFunction): EasingFunction[];
declare function keyframes<T extends AnyResolvedKeyframe>({ duration, keyframes: keyframeValues, times, ease, }: ValueAnimationOptions<T>): KeyframeGenerator<T>;

declare function spring(optionsOrVisualDuration?: ValueAnimationOptions<number> | number, bounce?: number): KeyframeGenerator<number>;
declare namespace spring {
    var applyToOptions: (options: Transition) => Transition;
}

/**
 * Implement a practical max duration for keyframe generation
 * to prevent infinite loops
 */
declare const maxGeneratorDuration = 20000;
declare function calcGeneratorDuration(generator: KeyframeGenerator<unknown>): number;

/**
 * Create a progress => progress easing function from a generator.
 */
declare function createGeneratorEasing(options: Transition, scale: number | undefined, createGenerator: GeneratorFactory): {
    type: string;
    ease: (progress: number) => number;
    duration: number;
};

declare function isGenerator(type?: AnimationGeneratorType): type is GeneratorFactory;

declare class DOMKeyframesResolver<T extends AnyResolvedKeyframe> extends KeyframeResolver<T> {
    name: string;
    element?: WithRender;
    private removedTransforms?;
    private measuredOrigin?;
    constructor(unresolvedKeyframes: UnresolvedKeyframes<AnyResolvedKeyframe>, onComplete: OnKeyframesResolved<T>, name?: string, motionValue?: MotionValue<T>, element?: WithRender);
    readKeyframes(): void;
    resolveNoneKeyframes(): void;
    measureInitialState(): void;
    measureEndState(): void;
}

declare function defaultOffset(arr: any[]): number[];

declare function fillOffset(offset: number[], remaining: number): void;

declare function convertOffsetToTimes(offset: number[], duration: number): number[];

declare function applyPxDefaults(keyframes: ValueKeyframe[] | UnresolvedValueKeyframe[], name: string): void;

declare function fillWildcards(keyframes: ValueKeyframe[] | UnresolvedValueKeyframe[]): void;

declare const cubicBezierAsString: ([a, b, c, d]: BezierDefinition) => string;

declare function isWaapiSupportedEasing(easing?: Easing | Easing[]): boolean;

declare function mapEasingToNativeEasing(easing: Easing | Easing[] | undefined, duration: number): undefined | string | string[];

declare const supportedWaapiEasing: {
    linear: string;
    ease: string;
    easeIn: string;
    easeOut: string;
    easeInOut: string;
    circIn: string;
    circOut: string;
    backIn: string;
    backOut: string;
};

declare function startWaapiAnimation(element: Element, valueName: string, keyframes: ValueKeyframesDefinition, { delay, duration, repeat, repeatType, ease, times, }?: ValueTransition, pseudoElement?: string | undefined): Animation;

declare const supportsPartialKeyframes: () => boolean;

declare function supportsBrowserAnimation<T extends AnyResolvedKeyframe>(options: ValueAnimationOptionsWithRenderContext<T>): any;

/**
 * A list of values that can be hardware-accelerated.
 */
declare const acceleratedValues: Set<string>;

declare function applyGeneratorOptions({ type, ...options }: ValueTransition): ValueTransition;

declare const generateLinearEasing: (easing: EasingFunction, duration: number, resolution?: number) => string;

declare class MotionValueState {
    latest: {
        [name: string]: AnyResolvedKeyframe;
    };
    private values;
    set(name: string, value: MotionValue, render?: VoidFunction, computed?: MotionValue, useDefaultValueType?: boolean): () => void;
    get(name: string): MotionValue | undefined;
    destroy(): void;
}

declare const addAttrValue: (element: HTMLElement | SVGElement, state: MotionValueState, key: string, value: MotionValue) => () => void;
declare const attrEffect: (subject: ElementOrSelector, values: Record<string, MotionValue<any>>) => () => void;

declare const propEffect: (subject: {
    [key: string]: any;
}, values: Record<string, MotionValue<any>>) => VoidFunction;

declare const addStyleValue: (element: HTMLElement | SVGElement, state: MotionValueState, key: string, value: MotionValue) => () => void;
declare const styleEffect: (subject: ElementOrSelector, values: Record<string, MotionValue<any>>) => () => void;

declare const svgEffect: (subject: ElementOrSelector, values: Record<string, MotionValue<any>>) => () => void;

declare const frame: Batcher;
declare const cancelFrame: (process: Process) => void;
declare const frameData: FrameData;
declare const frameSteps: Steps;

declare function createRenderBatcher(scheduleNextBatch: (callback: Function) => void, allowKeepAlive: boolean): {
    schedule: Batcher;
    cancel: (process: Process) => void;
    state: FrameData;
    steps: Steps;
};

declare const microtask: Batcher;
declare const cancelMicrotask: (process: Process) => void;

/**
 * An eventloop-synchronous alternative to performance.now().
 *
 * Ensures that time measurements remain consistent within a synchronous context.
 * Usually calling performance.now() twice within the same synchronous context
 * will return different values which isn't useful for animations when we're usually
 * trying to sync animations to the same frame.
 */
declare const time: {
    now: () => number;
    set: (newTime: number) => void;
};

declare const isDragging: {
    x: boolean;
    y: boolean;
};
declare function isDragActive(): boolean;

declare function setDragLock(axis: boolean | "x" | "y" | "lockDirection"): (() => void) | null;

type ElementOrSelector = Element | Element[] | NodeListOf<Element> | string | null | undefined;
interface WithQuerySelectorAll {
    querySelectorAll: Element["querySelectorAll"];
}
interface AnimationScope<T = any> {
    readonly current: T;
    animations: any[];
}
interface SelectorCache {
    [key: string]: NodeListOf<Element>;
}
declare function resolveElements(elementOrSelector: ElementOrSelector, scope?: AnimationScope, selectorCache?: SelectorCache): Element[];

/**
 * Options for event listeners.
 *
 * @public
 */
interface EventOptions {
    /**
     * Use passive event listeners. Doing so allows the browser to optimize
     * scrolling performance by not allowing the use of `preventDefault()`.
     *
     * @default true
     */
    passive?: boolean;
    /**
     * Remove the event listener after the first event.
     *
     * @default false
     */
    once?: boolean;
}

/**
 * A function to be called when a hover gesture starts.
 *
 * This function can optionally return a function that will be called
 * when the hover gesture ends.
 *
 * @public
 */
type OnHoverStartEvent = (element: Element, event: PointerEvent) => void | OnHoverEndEvent;
/**
 * A function to be called when a hover gesture ends.
 *
 * @public
 */
type OnHoverEndEvent = (event: PointerEvent) => void;
/**
 * Create a hover gesture. hover() is different to .addEventListener("pointerenter")
 * in that it has an easier syntax, filters out polyfilled touch events, interoperates
 * with drag gestures, and automatically removes the "pointerennd" event listener when the hover ends.
 *
 * @public
 */
declare function hover(elementOrSelector: ElementOrSelector, onHoverStart: OnHoverStartEvent, options?: EventOptions): VoidFunction;

interface PressGestureInfo {
    success: boolean;
}
type OnPressEndEvent = (event: PointerEvent, info: PressGestureInfo) => void;
type OnPressStartEvent = (element: Element, event: PointerEvent) => OnPressEndEvent | void;

interface PointerEventOptions extends EventOptions {
    useGlobalTarget?: boolean;
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
declare function press(targetOrSelector: ElementOrSelector, onPressStart: OnPressStartEvent, options?: PointerEventOptions): VoidFunction;

/**
 * Checks if an element is an interactive form element that should prevent
 * drag gestures from starting when clicked.
 *
 * This specifically targets form controls, buttons, and links - not just any
 * element with tabIndex, since motion elements with tap handlers automatically
 * get tabIndex=0 for keyboard accessibility.
 */
declare function isElementKeyboardAccessible(element: Element): boolean;

/**
 * Recursively traverse up the tree to check whether the provided child node
 * is the parent or a descendant of it.
 *
 * @param parent - Element to find
 * @param child - Element to test against parent
 */
declare const isNodeOrChild: (parent: Element | null, child?: Element | null) => boolean;

declare const isPrimaryPointer: (event: PointerEvent) => boolean;

declare function defaultTransformValue(name: string): number;
declare function parseValueFromTransform(transform: string | undefined, name: string): number;
declare const readTransformValue: (instance: HTMLElement, name: string) => number;

declare function getComputedStyle(element: HTMLElement | SVGElement, name: string): string;

declare function setStyle(element: HTMLElement | SVGElement, name: string, value: AnyResolvedKeyframe): void;

declare const isKeyframesTarget: (v: ValueKeyframesDefinition) => v is UnresolvedValueKeyframe[];

declare const positionalKeys: Set<string>;

/**
 * Generate a list of every possible transform key.
 */
declare const transformPropOrder: string[];
/**
 * A quick lookup for transform props.
 */
declare const transformProps: Set<string>;

interface ResizeInfo {
    width: number;
    height: number;
}
type ResizeHandler<I> = (element: I, info: ResizeInfo) => void;
type WindowResizeHandler = (info: ResizeInfo) => void;

declare function resize(onResize: WindowResizeHandler): VoidFunction;
declare function resize(target: ElementOrSelector, onResize: ResizeHandler<Element>): VoidFunction;

type Update = (progress: number) => void;
declare function observeTimeline(update: Update, timeline: ProgressTimeline): () => void;

declare const stepsOrder: StepId[];
type StepNames = (typeof stepsOrder)[number];

interface Summary {
    min: number;
    max: number;
    avg: number;
}
type FrameloopStatNames = "rate" | StepNames;
interface Stats<T> {
    frameloop: {
        [key in FrameloopStatNames]: T;
    };
    animations: {
        mainThread: T;
        waapi: T;
        layout: T;
    };
    layoutProjection: {
        nodes: T;
        calculatedTargetDeltas: T;
        calculatedProjections: T;
    };
}
type StatsBuffer = number[];
type FrameStats = Stats<number>;
type StatsRecording = Stats<StatsBuffer>;
type StatsSummary = Stats<Summary>;

declare function reportStats(): StatsSummary;
declare function recordStats(): typeof reportStats;

declare const activeAnimations: {
    layout: number;
    mainThread: number;
    waapi: number;
};

type InactiveStatsBuffer = {
    value: null;
    addProjectionMetrics: null;
};
type ActiveStatsBuffer = {
    value: StatsRecording;
    addProjectionMetrics: (metrics: {
        nodes: number;
        calculatedTargetDeltas: number;
        calculatedProjections: number;
    }) => void;
};
declare const statsBuffer: InactiveStatsBuffer | ActiveStatsBuffer;

type Mixer<T> = (p: number) => T;
type MixerFactory<T> = (a: T, b: T) => Mixer<T>;

interface InterpolateOptions<T> {
    clamp?: boolean;
    ease?: EasingFunction | EasingFunction[];
    mixer?: MixerFactory<T>;
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
declare function interpolate<T>(input: number[], output: T[], { clamp: isClamp, ease, mixer }?: InterpolateOptions<T>): (v: number) => T;

/**
 * Checks if an element is an HTML element in a way
 * that works across iframes
 */
declare function isHTMLElement(element: unknown): element is HTMLElement;

/**
 * Checks if an element is an SVG element in a way
 * that works across iframes
 */
declare function isSVGElement(element: unknown): element is SVGElement;

/**
 * Checks if an element is specifically an SVGSVGElement (the root SVG element)
 * in a way that works across iframes
 */
declare function isSVGSVGElement(element: unknown): element is SVGSVGElement;

declare function mix<T>(from: T, to: T): Mixer<T>;
declare function mix(from: number, to: number, p: number): number;

type Transformer = (v: any) => any;
type ValueType = {
    test: (v: any) => boolean;
    parse: (v: any) => any;
    transform?: Transformer;
    createTransformer?: (template: string) => Transformer;
    default?: any;
    getAnimatableNone?: (v: any) => any;
};
type NumberMap = {
    [key: string]: number;
};
type RGBA = {
    red: number;
    green: number;
    blue: number;
    alpha: number;
};
type HSLA = {
    hue: number;
    saturation: number;
    lightness: number;
    alpha: number;
};
type Color = HSLA | RGBA;

declare const mixLinearColor: (from: number, to: number, v: number) => number;
declare const mixColor: (from: Color | string, to: Color | string) => (p: number) => string | Color;

type MixableArray = Array<number | RGBA | HSLA | string>;
interface MixableObject {
    [key: string]: AnyResolvedKeyframe | RGBA | HSLA;
}
declare function getMixer<T>(a: T): ((from: string | Color, to: string | Color) => (p: number) => string | Color) | ((origin: AnyResolvedKeyframe, target: AnyResolvedKeyframe) => Function) | typeof mixArray | typeof mixObject;
declare function mixArray(a: MixableArray, b: MixableArray): (p: number) => (string | number | RGBA | HSLA)[];
declare function mixObject(a: MixableObject, b: MixableObject): (v: number) => {
    [x: string]: AnyResolvedKeyframe | RGBA | HSLA;
};
declare const mixComplex: (origin: AnyResolvedKeyframe, target: AnyResolvedKeyframe) => Function;

declare function mixImmediate<T>(a: T, b: T): (p: number) => T;

declare const mixNumber: (from: number, to: number, progress: number) => number;

declare const invisibleValues: Set<string>;
/**
 * Returns a function that, when provided a progress value between 0 and 1,
 * will return the "none" or "hidden" string only when the progress is that of
 * the origin or target.
 */
declare function mixVisibility(origin: string, target: string): (p: number) => string;

type StaggerOrigin = "first" | "last" | "center" | number;
type StaggerOptions = {
    startDelay?: number;
    from?: StaggerOrigin;
    ease?: Easing;
};
declare function getOriginIndex(from: StaggerOrigin, total: number): number;
declare function stagger(duration?: number, { startDelay, from, ease }?: StaggerOptions): DynamicOption<number>;

/**
 * Add the ability for test suites to manually set support flags
 * to better test more environments.
 */
declare const supportsFlags: Record<string, boolean | undefined>;

declare const supportsLinearEasing: () => boolean;

declare global {
    interface Window {
        ScrollTimeline: ScrollTimeline;
    }
}
declare class ScrollTimeline implements ProgressTimeline {
    constructor(options: ScrollOptions);
    currentTime: null | {
        value: number;
    };
    cancel?: VoidFunction;
}
declare const supportsScrollTimeline: () => boolean;

/**
 * @public
 */
interface TransformOptions<T> {
    /**
     * Clamp values to within the given range. Defaults to `true`
     *
     * @public
     */
    clamp?: boolean;
    /**
     * Easing functions to use on the interpolations between each value in the input and output ranges.
     *
     * If provided as an array, the array must be one item shorter than the input and output ranges, as the easings apply to the transition **between** each.
     *
     * @public
     */
    ease?: EasingFunction | EasingFunction[];
    /**
     * Provide a function that can interpolate between any two values in the provided range.
     *
     * @public
     */
    mixer?: (from: T, to: T) => (v: number) => any;
}
/**
 * Transforms numbers into other values by mapping them from an input range to an output range.
 * Returns the type of the input provided.
 *
 * @remarks
 *
 * Given an input range of `[0, 200]` and an output range of
 * `[0, 1]`, this function will return a value between `0` and `1`.
 * The input range must be a linear series of numbers. The output range
 * can be any supported value type, such as numbers, colors, shadows, arrays, objects and more.
 * Every value in the output range must be of the same type and in the same format.
 *
 * ```jsx
 * export function MyComponent() {
 *    const inputRange = [0, 200]
 *    const outputRange = [0, 1]
 *    const output = transform(100, inputRange, outputRange)
 *
 *    // Returns 0.5
 *    return <div>{output}</div>
 * }
 * ```
 *
 * @param inputValue - A number to transform between the input and output ranges.
 * @param inputRange - A linear series of numbers (either all increasing or decreasing).
 * @param outputRange - A series of numbers, colors, strings, or arrays/objects of those. Must be the same length as `inputRange`.
 * @param options - Clamp: Clamp values to within the given range. Defaults to `true`.
 *
 * @public
 */
declare function transform<T>(inputValue: number, inputRange: number[], outputRange: T[], options?: TransformOptions<T>): T;
/**
 *
 * Transforms numbers into other values by mapping them from an input range to an output range.
 *
 * Given an input range of `[0, 200]` and an output range of
 * `[0, 1]`, this function will return a value between `0` and `1`.
 * The input range must be a linear series of numbers. The output range
 * can be any supported value type, such as numbers, colors, shadows, arrays, objects and more.
 * Every value in the output range must be of the same type and in the same format.
 *
 * ```jsx
 * export function MyComponent() {
 *     const inputRange = [-200, -100, 100, 200]
 *     const outputRange = [0, 1, 1, 0]
 *     const convertRange = transform(inputRange, outputRange)
 *     const output = convertRange(-150)
 *
 *     // Returns 0.5
 *     return <div>{output}</div>
 * }
 *
 * ```
 *
 * @param inputRange - A linear series of numbers (either all increasing or decreasing).
 * @param outputRange - A series of numbers, colors or strings. Must be the same length as `inputRange`.
 * @param options - Clamp: clamp values to within the given range. Defaults to `true`.
 *
 * @public
 */
declare function transform<T>(inputRange: number[], outputRange: T[], options?: TransformOptions<T>): (inputValue: number) => T;

type MapInputRange = number[];
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
declare function mapValue<O>(inputValue: MotionValue<number>, inputRange: MapInputRange, outputRange: O[], options?: TransformOptions<O>): MotionValue<O>;

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
declare function springValue<T extends AnyResolvedKeyframe>(source: T | MotionValue<T>, options?: SpringOptions): MotionValue<T>;
declare function attachSpring<T extends AnyResolvedKeyframe>(value: MotionValue<T>, source: T | MotionValue<T>, options?: SpringOptions): VoidFunction;

type TransformInputRange = number[];
type SingleTransformer<I, O> = (input: I) => O;
type MultiTransformer<I, O> = (input: I[]) => O;
type ValueTransformer<I, O> = SingleTransformer<I, O> | MultiTransformer<I, O>;
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
declare function transformValue<O>(transform: () => O): MotionValue<O>;

declare const color: {
    test: (v: any) => boolean;
    parse: (v: any) => RGBA | HSLA;
    transform: (v: HSLA | RGBA | string) => string;
    getAnimatableNone: (v: string) => string;
};

declare function parseHex(v: string): RGBA;
declare const hex: {
    test: (v: any) => boolean;
    parse: typeof parseHex;
    transform: ({ red, green, blue, alpha }: RGBA) => string;
};

declare const hsla: {
    test: (v: any) => boolean;
    parse: (v: string | Color) => HSLA;
    transform: ({ hue, saturation, lightness, alpha }: HSLA) => string;
};

declare function hslaToRgba({ hue, saturation, lightness, alpha }: HSLA): RGBA;

declare const rgbUnit: {
    transform: (v: number) => number;
    test: (v: number) => boolean;
    parse: typeof parseFloat;
};
declare const rgba: {
    test: (v: any) => boolean;
    parse: (v: string | Color) => RGBA;
    transform: ({ red, green, blue, alpha }: RGBA) => string;
};

declare function test(v: any): boolean;
type ComplexValues = Array<CSSVariableToken | AnyResolvedKeyframe | Color>;
interface ValueIndexes {
    color: number[];
    number: number[];
    var: number[];
}
interface ComplexValueInfo {
    values: ComplexValues;
    split: string[];
    indexes: ValueIndexes;
    types: Array<keyof ValueIndexes>;
}
declare function analyseComplexValue(value: AnyResolvedKeyframe): ComplexValueInfo;
declare function parseComplexValue(v: AnyResolvedKeyframe): ComplexValues;
declare function createTransformer(source: AnyResolvedKeyframe): (v: Array<CSSVariableToken | Color | number | string>) => string;
declare function getAnimatableNone$1(v: AnyResolvedKeyframe): string;
declare const complex: {
    test: typeof test;
    parse: typeof parseComplexValue;
    createTransformer: typeof createTransformer;
    getAnimatableNone: typeof getAnimatableNone$1;
};

/**
 * A list of value types commonly used for dimensions
 */
declare const dimensionValueTypes: ({
    test: (v: number) => boolean;
    parse: typeof parseFloat;
    transform: (v: number) => number;
} | {
    test: (v: AnyResolvedKeyframe) => boolean;
    parse: typeof parseFloat;
    transform: (v: string | number) => string;
} | ValueType)[];
/**
 * Tests a dimensional value against the list of dimension ValueTypes
 */
declare const findDimensionValueType: (v: any) => {
    test: (v: number) => boolean;
    parse: typeof parseFloat;
    transform: (v: number) => number;
} | {
    test: (v: AnyResolvedKeyframe) => boolean;
    parse: typeof parseFloat;
    transform: (v: string | number) => string;
} | ValueType | undefined;

interface ValueTypeMap {
    [key: string]: ValueType;
}

/**
 * A map of default value types for common values
 */
declare const defaultValueTypes: ValueTypeMap;
/**
 * Gets the default ValueType for the provided value key
 */
declare const getDefaultValueType: (key: string) => ValueType;

declare const numberValueTypes: ValueTypeMap;

declare const transformValueTypes: ValueTypeMap;

declare const number: {
    test: (v: number) => boolean;
    parse: typeof parseFloat;
    transform: (v: number) => number;
};
declare const alpha: {
    transform: (v: number) => number;
    test: (v: number) => boolean;
    parse: typeof parseFloat;
};
declare const scale: {
    default: number;
    test: (v: number) => boolean;
    parse: typeof parseFloat;
    transform: (v: number) => number;
};

declare const degrees: {
    test: (v: AnyResolvedKeyframe) => boolean;
    parse: typeof parseFloat;
    transform: (v: number | string) => string;
};
declare const percent: {
    test: (v: AnyResolvedKeyframe) => boolean;
    parse: typeof parseFloat;
    transform: (v: number | string) => string;
};
declare const px: {
    test: (v: AnyResolvedKeyframe) => boolean;
    parse: typeof parseFloat;
    transform: (v: number | string) => string;
};
declare const vh: {
    test: (v: AnyResolvedKeyframe) => boolean;
    parse: typeof parseFloat;
    transform: (v: number | string) => string;
};
declare const vw: {
    test: (v: AnyResolvedKeyframe) => boolean;
    parse: typeof parseFloat;
    transform: (v: number | string) => string;
};
declare const progressPercentage: {
    parse: (v: string) => number;
    transform: (v: number) => string;
    test: (v: AnyResolvedKeyframe) => boolean;
};

/**
 * Tests a provided value against a ValueType
 */
declare const testValueType: (v: any) => (type: ValueType) => boolean;

declare function getAnimatableNone(key: string, value: string): any;

/**
 * Tests a value against the list of ValueTypes
 */
declare const findValueType: (v: any) => {
    test: (v: number) => boolean;
    parse: typeof parseFloat;
    transform: (v: number) => number;
} | {
    test: (v: AnyResolvedKeyframe) => boolean;
    parse: typeof parseFloat;
    transform: (v: string | number) => string;
} | ValueType | {
    test: (v: any) => boolean;
    parse: (v: any) => RGBA | HSLA;
    transform: (v: string | RGBA | HSLA) => string;
    getAnimatableNone: (v: string) => string;
} | {
    test: (v: any) => boolean;
    parse: (v: AnyResolvedKeyframe) => ComplexValues;
    createTransformer: (source: AnyResolvedKeyframe) => (v: (string | number | Color)[]) => string;
    getAnimatableNone: (v: AnyResolvedKeyframe) => string;
} | undefined;

/**
 * Provided a value and a ValueType, returns the value as that value type.
 */
declare const getValueAsType: (value: any, type?: ValueType) => any;

declare const isMotionValue: (value: any) => value is MotionValue<any>;

declare function addValueToWillChange(visualElement: VisualElement, key: string): void;

interface WillChange extends MotionValue<string> {
    add(name: string): void;
}

declare function isWillChangeMotionValue(value: any): value is WillChange;

type ViewTransitionAnimationDefinition = {
    keyframes: DOMKeyframesDefinition;
    options: AnimationOptions;
};
type ViewTransitionTarget = {
    layout?: ViewTransitionAnimationDefinition;
    enter?: ViewTransitionAnimationDefinition;
    exit?: ViewTransitionAnimationDefinition;
    new?: ViewTransitionAnimationDefinition;
    old?: ViewTransitionAnimationDefinition;
};
type ViewTransitionOptions = AnimationOptions & {
    interrupt?: "wait" | "immediate";
};
type ViewTransitionTargetDefinition = string | Element;

declare class ViewTransitionBuilder {
    private currentSubject;
    targets: Map<ViewTransitionTargetDefinition, ViewTransitionTarget>;
    update: () => void | Promise<void>;
    options: ViewTransitionOptions;
    notifyReady: (value: GroupAnimation) => void;
    private readyPromise;
    constructor(update: () => void | Promise<void>, options?: ViewTransitionOptions);
    get(subject: ViewTransitionTargetDefinition): this;
    layout(keyframes: DOMKeyframesDefinition, options?: AnimationOptions): this;
    new(keyframes: DOMKeyframesDefinition, options?: AnimationOptions): this;
    old(keyframes: DOMKeyframesDefinition, options?: AnimationOptions): this;
    enter(keyframes: DOMKeyframesDefinition, options?: AnimationOptions): this;
    exit(keyframes: DOMKeyframesDefinition, options?: AnimationOptions): this;
    crossfade(options?: AnimationOptions): this;
    updateTarget(target: "enter" | "exit" | "layout" | "new" | "old", keyframes: DOMKeyframesDefinition, options?: AnimationOptions): void;
    then(resolve: () => void, reject?: () => void): Promise<void>;
}
declare function animateView(update: () => void | Promise<void>, defaultOptions?: ViewTransitionOptions): ViewTransitionBuilder;

declare function getViewAnimationLayerInfo(pseudoElement: string): {
    layer: string;
    type: string;
} | null;

declare function getViewAnimations(): Animation[];

interface DOMVisualElementOptions {
    /**
     * If `true`, this element will be included in the projection tree.
     *
     * Default: `true`
     *
     * @public
     */
    allowProjection?: boolean;
    /**
     * Allow this element to be GPU-accelerated. We currently enable this by
     * adding a `translateZ(0)`.
     *
     * @public
     */
    enableHardwareAcceleration?: boolean;
}

declare abstract class DOMVisualElement<Instance extends HTMLElement | SVGElement = HTMLElement, State extends HTMLRenderState = HTMLRenderState, Options extends DOMVisualElementOptions = DOMVisualElementOptions> extends VisualElement<Instance, State, Options> {
    sortInstanceNodePosition(a: Instance, b: Instance): number;
    getBaseTargetFromProps(props: MotionNodeOptions, key: string): AnyResolvedKeyframe | MotionValue<any> | undefined;
    removeValueFromRenderState(key: string, { vars, style }: HTMLRenderState): void;
    KeyframeResolver: typeof DOMKeyframesResolver;
    childSubscription?: VoidFunction;
    handleChildMotionValue(): void;
}

/**
 * Feature base class for extending VisualElement functionality.
 * Features are plugins that can be mounted/unmounted to add behavior
 * like gestures, animations, or layout tracking.
 */
declare abstract class Feature<T extends any = any> {
    isMounted: boolean;
    node: VisualElement<T>;
    constructor(node: VisualElement<T>);
    abstract mount(): void;
    abstract unmount(): void;
    update(): void;
}

declare function renderHTML(element: HTMLElement, { style, vars }: HTMLRenderState, styleProp?: MotionStyle, projection?: any): void;

declare class HTMLVisualElement extends DOMVisualElement<HTMLElement, HTMLRenderState, DOMVisualElementOptions> {
    type: string;
    readValueFromInstance(instance: HTMLElement, key: string): AnyResolvedKeyframe | null | undefined;
    measureInstanceViewportBox(instance: HTMLElement, { transformPagePoint }: MotionNodeOptions & Partial<MotionConfigContextProps>): Box;
    build(renderState: HTMLRenderState, latestValues: ResolvedValues$1, props: MotionNodeOptions): void;
    scrapeMotionValuesFromProps(props: MotionNodeOptions, prevProps: MotionNodeOptions, visualElement: VisualElement): {
        [key: string]: any;
    };
    renderInstance: typeof renderHTML;
}

interface ObjectRenderState {
    output: ResolvedValues$1;
}
declare class ObjectVisualElement extends VisualElement<Object, ObjectRenderState> {
    type: string;
    readValueFromInstance(instance: Object, key: string): undefined;
    getBaseTargetFromProps(): undefined;
    removeValueFromRenderState(key: string, renderState: ObjectRenderState): void;
    measureInstanceViewportBox(): motion_utils.Box;
    build(renderState: ObjectRenderState, latestValues: ResolvedValues$1): void;
    renderInstance(instance: Object, { output }: ObjectRenderState): void;
    sortInstanceNodePosition(): number;
}

declare const visualElementStore: WeakMap<any, VisualElement<unknown, unknown, {}>>;

declare class SVGVisualElement extends DOMVisualElement<SVGElement, SVGRenderState, DOMVisualElementOptions> {
    type: string;
    isSVGTag: boolean;
    getBaseTargetFromProps(props: MotionNodeOptions, key: string): AnyResolvedKeyframe | MotionValue<any> | undefined;
    readValueFromInstance(instance: SVGElement, key: string): any;
    measureInstanceViewportBox: () => motion_utils.Box;
    scrapeMotionValuesFromProps(props: MotionNodeOptions, prevProps: MotionNodeOptions, visualElement: VisualElement): {
        [key: string]: any;
    };
    build(renderState: SVGRenderState, latestValues: ResolvedValues$1, props: MotionNodeOptions): void;
    renderInstance(instance: SVGElement, renderState: SVGRenderState, styleProp?: MotionStyle | undefined, projection?: any): void;
    mount(instance: SVGElement): void;
}

type VariantStateContext = {
    initial?: string | string[];
    animate?: string | string[];
    exit?: string | string[];
    whileHover?: string | string[];
    whileDrag?: string | string[];
    whileFocus?: string | string[];
    whileTap?: string | string[];
};
/**
 * Get variant context from a visual element's parent chain.
 * Uses `any` type for visualElement to avoid circular dependencies.
 */
declare function getVariantContext(visualElement?: any): undefined | VariantStateContext;

declare function isAnimationControls(v?: unknown): v is LegacyAnimationControls;

declare function isControllingVariants(props: MotionNodeOptions): boolean;
declare function isVariantNode(props: MotionNodeOptions): boolean;

/**
 * Minimal interface for projection node properties used by scale correctors.
 * This avoids circular dependencies with the full IProjectionNode interface.
 */
interface ScaleCorrectionNode {
    target?: Box;
    treeScale?: Point;
    projectionDelta?: Delta;
}
type ScaleCorrector = (latest: AnyResolvedKeyframe, node: ScaleCorrectionNode) => AnyResolvedKeyframe;
interface ScaleCorrectorDefinition {
    correct: ScaleCorrector;
    applyTo?: string[];
    isCSSVariable?: boolean;
}
interface ScaleCorrectorMap {
    [key: string]: ScaleCorrectorDefinition;
}

declare const scaleCorrectors: ScaleCorrectorMap;
declare function addScaleCorrector(correctors: ScaleCorrectorMap): void;

declare function isForcedMotionValue(key: string, { layout, layoutId }: MotionNodeOptions): boolean;

/**
 * Decides if the supplied variable is variant label
 */
declare function isVariantLabel(v: unknown): v is string | string[];

type MotionStyleLike = Record<string, any>;
/**
 * Updates motion values from props changes.
 * Uses `any` type for element to avoid circular dependencies with VisualElement.
 */
declare function updateMotionValuesFromProps(element: any, next: MotionStyleLike, prev: MotionStyleLike): MotionStyleLike;

/**
 * Resolves a variant if it's a variant resolver.
 * Uses `any` type for visualElement to avoid circular dependencies.
 */
declare function resolveVariant(visualElement: any, definition?: TargetAndTransition | TargetResolver, custom?: any): TargetAndTransition;
declare function resolveVariant(visualElement: any, definition?: AnimationDefinition, custom?: any): TargetAndTransition | undefined;

declare function resolveVariantFromProps(props: MotionNodeOptions, definition: TargetAndTransition | TargetResolver, custom?: any, visualElement?: any): TargetAndTransition;
declare function resolveVariantFromProps(props: MotionNodeOptions, definition?: AnimationDefinition, custom?: any, visualElement?: any): undefined | TargetAndTransition;

declare function setTarget(visualElement: VisualElement, definition: AnimationDefinition): void;

declare const variantPriorityOrder: AnimationType[];
declare const variantProps: string[];

interface ReducedMotionState {
    current: boolean | null;
}
declare const prefersReducedMotion: ReducedMotionState;
declare const hasReducedMotionListener: {
    current: boolean;
};

declare function initPrefersReducedMotion(): void;

/**
 * Bounding boxes tend to be defined as top, left, right, bottom. For various operations
 * it's easier to consider each axis individually. This function returns a bounding box
 * as a map of single-axis min/max values.
 */
declare function convertBoundingBoxToBox({ top, left, right, bottom, }: BoundingBox): Box;
declare function convertBoxToBoundingBox({ x, y }: Box): BoundingBox;
/**
 * Applies a TransformPoint function to a bounding box. TransformPoint is usually a function
 * provided by Framer to allow measured points to be corrected for device scaling. This is used
 * when measuring DOM elements and DOM event points.
 */
declare function transformBoxPoints(point: BoundingBox, transformPoint?: TransformPoint): BoundingBox;

/**
 * Reset an axis to the provided origin box.
 *
 * This is a mutative operation.
 */
declare function copyAxisInto(axis: Axis, originAxis: Axis): void;
/**
 * Reset a box to the provided origin box.
 *
 * This is a mutative operation.
 */
declare function copyBoxInto(box: Box, originBox: Box): void;
/**
 * Reset a delta to the provided origin box.
 *
 * This is a mutative operation.
 */
declare function copyAxisDeltaInto(delta: AxisDelta, originDelta: AxisDelta): void;

/**
 * Scales a point based on a factor and an originPoint
 */
declare function scalePoint(point: number, scale: number, originPoint: number): number;
/**
 * Applies a translate/scale delta to a point
 */
declare function applyPointDelta(point: number, translate: number, scale: number, originPoint: number, boxScale?: number): number;
/**
 * Applies a translate/scale delta to an axis
 */
declare function applyAxisDelta(axis: Axis, translate: number | undefined, scale: number | undefined, originPoint: number, boxScale?: number): void;
/**
 * Applies a translate/scale delta to a box
 */
declare function applyBoxDelta(box: Box, { x, y }: Delta): void;
/**
 * Apply a tree of deltas to a box. We do this to calculate the effect of all the transforms
 * in a tree upon our box before then calculating how to project it into our desired viewport-relative box
 *
 * This is the final nested loop within updateLayoutDelta for future refactoring
 */
declare function applyTreeDeltas(box: Box, treeScale: Point, treePath: any[], isSharedTransition?: boolean): void;
declare function translateAxis(axis: Axis, distance: number): void;
/**
 * Apply a transform to an axis from the latest resolved motion values.
 * This function basically acts as a bridge between a flat motion value map
 * and applyAxisDelta
 */
declare function transformAxis(axis: Axis, axisTranslate?: number, axisScale?: number, boxScale?: number, axisOrigin?: number): void;
/**
 * Apply a transform to a box from the latest resolved motion values.
 */
declare function transformBox(box: Box, transform: ResolvedValues$1): void;

declare function calcLength(axis: Axis): number;
declare function isNear(value: number, target: number, maxDistance: number): boolean;
declare function calcAxisDelta(delta: AxisDelta, source: Axis, target: Axis, origin?: number): void;
declare function calcBoxDelta(delta: Delta, source: Box, target: Box, origin?: ResolvedValues$1): void;
declare function calcRelativeAxis(target: Axis, relative: Axis, parent: Axis): void;
declare function calcRelativeBox(target: Box, relative: Box, parent: Box): void;
declare function calcRelativeAxisPosition(target: Axis, layout: Axis, parent: Axis): void;
declare function calcRelativePosition(target: Box, layout: Box, parent: Box): void;

/**
 * Remove a delta from a point. This is essentially the steps of applyPointDelta in reverse
 */
declare function removePointDelta(point: number, translate: number, scale: number, originPoint: number, boxScale?: number): number;
/**
 * Remove a delta from an axis. This is essentially the steps of applyAxisDelta in reverse
 */
declare function removeAxisDelta(axis: Axis, translate?: number | string, scale?: number, origin?: number, boxScale?: number, originAxis?: Axis, sourceAxis?: Axis): void;
/**
 * Remove a transforms from an axis. This is essentially the steps of applyAxisTransforms in reverse
 * and acts as a bridge between motion values and removeAxisDelta
 */
declare function removeAxisTransforms(axis: Axis, transforms: ResolvedValues$1, [key, scaleKey, originKey]: string[], origin?: Axis, sourceAxis?: Axis): void;
/**
 * Remove a transforms from an box. This is essentially the steps of applyAxisBox in reverse
 * and acts as a bridge between motion values and removeAxisDelta
 */
declare function removeBoxTransforms(box: Box, transforms: ResolvedValues$1, originBox?: Box, sourceBox?: Box): void;

declare const createAxisDelta: () => AxisDelta;
declare const createDelta: () => Delta;
declare const createAxis: () => Axis;
declare const createBox: () => Box;

declare function isDeltaZero(delta: Delta): boolean;
declare function axisEquals(a: Axis, b: Axis): boolean;
declare function boxEquals(a: Box, b: Box): boolean;
declare function axisEqualsRounded(a: Axis, b: Axis): boolean;
declare function boxEqualsRounded(a: Box, b: Box): boolean;
declare function aspectRatio(box: Box): number;
declare function axisDeltaEquals(a: AxisDelta, b: AxisDelta): boolean;

type Callback = (axis: "x" | "y") => void;
declare function eachAxis(callback: Callback): void[];

declare function hasScale({ scale, scaleX, scaleY }: ResolvedValues$1): boolean;
declare function hasTransform(values: ResolvedValues$1): true | AnyResolvedKeyframe;
declare function has2DTranslate(values: ResolvedValues$1): boolean | "" | 0 | undefined;

declare function measureViewportBox(instance: HTMLElement, transformPoint?: TransformPoint): motion_utils.Box;
declare function measurePageBox(element: HTMLElement, rootProjectionNode: any, transformPagePoint?: TransformPoint): motion_utils.Box;

declare function pixelsToPercent(pixels: number, axis: Axis): number;
/**
 * We always correct borderRadius as a percentage rather than pixels to reduce paints.
 * For example, if you are projecting a box that is 100px wide with a 10px borderRadius
 * into a box that is 200px wide with a 20px borderRadius, that is actually a 10%
 * borderRadius in both states. If we animate between the two in pixels that will trigger
 * a paint each time. If we animate between the two in percentage we'll avoid a paint.
 */
declare const correctBorderRadius: ScaleCorrectorDefinition;

declare const correctBoxShadow: ScaleCorrectorDefinition;

declare function buildProjectionTransform(delta: Delta, treeScale: Point, latestTransform?: ResolvedValues$1): string;

declare function mixValues(target: ResolvedValues$1, follow: ResolvedValues$1, lead: ResolvedValues$1, progress: number, shouldCrossfadeOpacity: boolean, isOnlyMember: boolean): void;

declare function animateSingleValue<V extends AnyResolvedKeyframe>(value: MotionValue<V> | V, keyframes: V | UnresolvedValueKeyframe<V>[], options?: ValueAnimationTransition): AnimationPlaybackControlsWithThen;

declare function addDomEvent(target: EventTarget, eventName: string, handler: EventListener, options?: AddEventListenerOptions): () => void;

interface WithDepth {
    depth: number;
}
declare const compareByDepth: (a: VisualElement, b: VisualElement) => number;

declare class FlatTree {
    private children;
    private isDirty;
    add(child: WithDepth): void;
    remove(child: WithDepth): void;
    forEach(callback: (child: WithDepth) => void): void;
}

type DelayedFunction = (overshoot: number) => void;
/**
 * Timeout defined in ms
 */
declare function delay(callback: DelayedFunction, timeout: number): () => void;
declare function delayInSeconds(callback: DelayedFunction, timeout: number): () => void;

/**
 * If the provided value is a MotionValue, this returns the actual value, otherwise just the value itself
 */
declare function resolveMotionValue(value?: AnyResolvedKeyframe | MotionValue): AnyResolvedKeyframe;

interface Measurements {
    animationId: number;
    measuredBox: Box;
    layoutBox: Box;
    latestValues: ResolvedValues$1;
    source: number;
}
type Phase = "snapshot" | "measure";
interface ScrollMeasurements {
    animationId: number;
    phase: Phase;
    offset: Point;
    isRoot: boolean;
    wasRoot: boolean;
}
type LayoutEvents = "willUpdate" | "didUpdate" | "beforeMeasure" | "measure" | "projectionUpdate" | "animationStart" | "animationComplete";
interface IProjectionNode<I = unknown> {
    linkedParentVersion: number;
    layoutVersion: number;
    id: number;
    animationId: number;
    animationCommitId: number;
    parent?: IProjectionNode;
    relativeParent?: IProjectionNode;
    root?: IProjectionNode;
    children: Set<IProjectionNode>;
    path: IProjectionNode[];
    nodes?: FlatTree;
    depth: number;
    instance: I | undefined;
    mount: (node: I, isLayoutDirty?: boolean) => void;
    unmount: () => void;
    options: ProjectionNodeOptions;
    setOptions(options: ProjectionNodeOptions): void;
    layout?: Measurements;
    snapshot?: Measurements;
    target?: Box;
    relativeTarget?: Box;
    relativeTargetOrigin?: Box;
    targetDelta?: Delta;
    targetWithTransforms?: Box;
    scroll?: ScrollMeasurements;
    treeScale?: Point;
    projectionDelta?: Delta;
    projectionDeltaWithTransform?: Delta;
    latestValues: ResolvedValues$1;
    isLayoutDirty: boolean;
    isProjectionDirty: boolean;
    isSharedProjectionDirty: boolean;
    isTransformDirty: boolean;
    resolvedRelativeTargetAt?: number;
    shouldResetTransform: boolean;
    prevTransformTemplateValue: string | undefined;
    isUpdateBlocked(): boolean;
    updateManuallyBlocked: boolean;
    updateBlockedByResize: boolean;
    blockUpdate(): void;
    unblockUpdate(): void;
    isUpdating: boolean;
    needsReset: boolean;
    startUpdate(): void;
    willUpdate(notifyListeners?: boolean): void;
    didUpdate(): void;
    measure(removeTransform?: boolean): Measurements;
    measurePageBox(): Box;
    updateLayout(): void;
    updateSnapshot(): void;
    clearSnapshot(): void;
    updateScroll(phase?: Phase): void;
    scheduleUpdateProjection(): void;
    scheduleCheckAfterUnmount(): void;
    checkUpdateFailed(): void;
    sharedNodes: Map<string, NodeStack>;
    registerSharedNode(id: string, node: IProjectionNode): void;
    getStack(): NodeStack | undefined;
    isVisible: boolean;
    hide(): void;
    show(): void;
    scheduleRender(notifyAll?: boolean): void;
    getClosestProjectingParent(): IProjectionNode | undefined;
    setTargetDelta(delta: Delta): void;
    resetTransform(): void;
    resetSkewAndRotation(): void;
    applyTransform(box: Box, transformOnly?: boolean): Box;
    resolveTargetDelta(force?: boolean): void;
    calcProjection(): void;
    applyProjectionStyles(targetStyle: CSSStyleDeclaration, styleProp?: MotionStyle): void;
    clearMeasurements(): void;
    resetTree(): void;
    isProjecting(): boolean;
    animationValues?: ResolvedValues$1;
    currentAnimation?: JSAnimation<number>;
    isTreeAnimating?: boolean;
    isAnimationBlocked?: boolean;
    isTreeAnimationBlocked: () => boolean;
    setAnimationOrigin(delta: Delta): void;
    startAnimation(transition: ValueTransition): void;
    finishAnimation(): void;
    hasCheckedOptimisedAppear: boolean;
    isLead(): boolean;
    promote(options?: {
        needsReset?: boolean;
        transition?: Transition;
        preserveFollowOpacity?: boolean;
    }): void;
    relegate(): boolean;
    resumeFrom?: IProjectionNode;
    resumingFrom?: IProjectionNode;
    isPresent?: boolean;
    addEventListener(name: LayoutEvents, handler: any): VoidFunction;
    notifyListeners(name: LayoutEvents, ...args: any): void;
    hasListeners(name: LayoutEvents): boolean;
    hasTreeAnimated: boolean;
    preserveOpacity?: boolean;
}
interface LayoutUpdateData {
    layout: Box;
    snapshot: Measurements;
    delta: Delta;
    layoutDelta: Delta;
    hasLayoutChanged: boolean;
    hasRelativeLayoutChanged: boolean;
}
type LayoutUpdateHandler = (data: LayoutUpdateData) => void;
interface ProjectionNodeConfig<I> {
    defaultParent?: () => IProjectionNode;
    attachResizeListener?: (instance: I, notifyResize: VoidFunction) => VoidFunction;
    measureScroll: (instance: I) => Point;
    checkIsScrollRoot: (instance: I) => boolean;
    resetTransform?: (instance: I, value?: string) => void;
}
/**
 * Configuration for initial promotion of shared layout elements.
 * This was originally in React's SwitchLayoutGroupContext but is now
 * framework-agnostic to support vanilla JS usage.
 */
interface InitialPromotionConfig {
    /**
     * The initial transition to use when the elements in this group mount (and automatically promoted).
     * Subsequent updates should provide a transition in the promote method.
     */
    transition?: Transition;
    /**
     * If the follow tree should preserve its opacity when the lead is promoted on mount
     */
    shouldPreserveFollowOpacity?: (member: IProjectionNode) => boolean;
}
interface ProjectionNodeOptions {
    animate?: boolean;
    layoutScroll?: boolean;
    layoutRoot?: boolean;
    alwaysMeasureLayout?: boolean;
    onExitComplete?: VoidFunction;
    animationType?: "size" | "position" | "both" | "preserve-aspect";
    layoutId?: string;
    layout?: boolean | string;
    visualElement?: VisualElement;
    crossfade?: boolean;
    transition?: Transition;
    initialPromotionConfig?: InitialPromotionConfig;
}
type ProjectionEventName = "layoutUpdate" | "projectionUpdate";

declare class NodeStack {
    lead?: IProjectionNode;
    prevLead?: IProjectionNode;
    members: IProjectionNode[];
    add(node: IProjectionNode): void;
    remove(node: IProjectionNode): void;
    relegate(node: IProjectionNode): boolean;
    promote(node: IProjectionNode, preserveFollowOpacity?: boolean): void;
    exitAnimationComplete(): void;
    scheduleRender(): void;
    /**
     * Clear any leads that have been removed this render to prevent them from being
     * used in future animations and to prevent memory leaks
     */
    removeLeadSnapshot(): void;
}

declare function createProjectionNode<I>({ attachResizeListener, defaultParent, measureScroll, checkIsScrollRoot, resetTransform, }: ProjectionNodeConfig<I>): {
    new (latestValues?: ResolvedValues$1, parent?: IProjectionNode | undefined): {
        /**
         * A unique ID generated for every projection node.
         */
        id: number;
        /**
         * An id that represents a unique session instigated by startUpdate.
         */
        animationId: number;
        animationCommitId: number;
        /**
         * A reference to the platform-native node (currently this will be a HTMLElement).
         */
        instance: I | undefined;
        /**
         * A reference to the root projection node. There'll only ever be one tree and one root.
         */
        root: IProjectionNode;
        /**
         * A reference to this node's parent.
         */
        parent?: IProjectionNode<unknown> | undefined;
        /**
         * A path from this node to the root node. This provides a fast way to iterate
         * back up the tree.
         */
        path: IProjectionNode[];
        /**
         * A Set containing all this component's children. This is used to iterate
         * through the children.
         *
         * TODO: This could be faster to iterate as a flat array stored on the root node.
         */
        children: Set<IProjectionNode<unknown>>;
        /**
         * Options for the node. We use this to configure what kind of layout animations
         * we should perform (if any).
         */
        options: ProjectionNodeOptions;
        /**
         * A snapshot of the element's state just before the current update. This is
         * hydrated when this node's `willUpdate` method is called and scrubbed at the
         * end of the tree's `didUpdate` method.
         */
        snapshot: Measurements | undefined;
        /**
         * A box defining the element's layout relative to the page. This will have been
         * captured with all parent scrolls and projection transforms unset.
         */
        layout: Measurements | undefined;
        /**
         * The layout used to calculate the previous layout animation. We use this to compare
         * layouts between renders and decide whether we need to trigger a new layout animation
         * or just let the current one play out.
         */
        targetLayout?: Box | undefined;
        /**
         * A mutable data structure we use to apply all parent transforms currently
         * acting on the element's layout. It's from here we can calculate the projectionDelta
         * required to get the element from its layout into its calculated target box.
         */
        layoutCorrected: Box;
        /**
         * An ideal projection transform we want to apply to the element. This is calculated,
         * usually when an element's layout has changed, and we want the element to look as though
         * its in its previous layout on the next frame. From there, we animated it down to 0
         * to animate the element to its new layout.
         */
        targetDelta?: Delta | undefined;
        /**
         * A mutable structure representing the visual bounding box on the page where we want
         * and element to appear. This can be set directly but is currently derived once a frame
         * from apply targetDelta to layout.
         */
        target?: Box | undefined;
        /**
         * A mutable structure describing a visual bounding box relative to the element's
         * projected parent. If defined, target will be derived from this rather than targetDelta.
         * If not defined, we'll attempt to calculate on the first layout animation frame
         * based on the targets calculated from targetDelta. This will transfer a layout animation
         * from viewport-relative to parent-relative.
         */
        relativeTarget?: Box | undefined;
        relativeTargetOrigin?: Box | undefined;
        relativeParent?: IProjectionNode<unknown> | undefined;
        /**
         * We use this to detect when its safe to shut down part of a projection tree.
         * We have to keep projecting children for scale correction and relative projection
         * until all their parents stop performing layout animations.
         */
        isTreeAnimating: boolean;
        isAnimationBlocked: boolean;
        /**
         * If true, attempt to resolve relativeTarget.
         */
        attemptToResolveRelativeTarget?: boolean | undefined;
        /**
         * A mutable structure that represents the target as transformed by the element's
         * latest user-set transforms (ie scale, x)
         */
        targetWithTransforms?: Box | undefined;
        /**
         * The previous projection delta, which we can compare with the newly calculated
         * projection delta to see if we need to render.
         */
        prevProjectionDelta?: Delta | undefined;
        /**
         * A calculated transform that will project an element from its layoutCorrected
         * into the target. This will be used by children to calculate their own layoutCorrect boxes.
         */
        projectionDelta?: Delta | undefined;
        /**
         * A calculated transform that will project an element from its layoutCorrected
         * into the targetWithTransforms.
         */
        projectionDeltaWithTransform?: Delta | undefined;
        /**
         * If we're tracking the scroll of this element, we store it here.
         */
        scroll?: ScrollMeasurements | undefined;
        /**
         * Flag to true if we think this layout has been changed. We can't always know this,
         * currently we set it to true every time a component renders, or if it has a layoutDependency
         * if that has changed between renders. Additionally, components can be grouped by LayoutGroup
         * and if one node is dirtied, they all are.
         */
        isLayoutDirty: boolean;
        /**
         * Flag to true if we think the projection calculations for this node needs
         * recalculating as a result of an updated transform or layout animation.
         */
        isProjectionDirty: boolean;
        /**
         * Flag to true if the layout *or* transform has changed. This then gets propagated
         * throughout the projection tree, forcing any element below to recalculate on the next frame.
         */
        isSharedProjectionDirty: boolean;
        /**
         * Flag transform dirty. This gets propagated throughout the whole tree but is only
         * respected by shared nodes.
         */
        isTransformDirty: boolean;
        /**
         * Block layout updates for instant layout transitions throughout the tree.
         */
        updateManuallyBlocked: boolean;
        updateBlockedByResize: boolean;
        /**
         * Set to true between the start of the first `willUpdate` call and the end of the `didUpdate`
         * call.
         */
        isUpdating: boolean;
        /**
         * If this is an SVG element we currently disable projection transforms
         */
        isSVG: boolean;
        /**
         * Flag to true (during promotion) if a node doing an instant layout transition needs to reset
         * its projection styles.
         */
        needsReset: boolean;
        /**
         * Flags whether this node should have its transform reset prior to measuring.
         */
        shouldResetTransform: boolean;
        /**
         * Store whether this node has been checked for optimised appear animations. As
         * effects fire bottom-up, and we want to look up the tree for appear animations,
         * this makes sure we only check each path once, stopping at nodes that
         * have already been checked.
         */
        hasCheckedOptimisedAppear: boolean;
        /**
         * An object representing the calculated contextual/accumulated/tree scale.
         * This will be used to scale calculcated projection transforms, as these are
         * calculated in screen-space but need to be scaled for elements to layoutly
         * make it to their calculated destinations.
         *
         * TODO: Lazy-init
         */
        treeScale: Point;
        /**
         * Is hydrated with a projection node if an element is animating from another.
         */
        resumeFrom?: IProjectionNode<unknown> | undefined;
        /**
         * Is hydrated with a projection node if an element is animating from another.
         */
        resumingFrom?: IProjectionNode<unknown> | undefined;
        /**
         * A reference to the element's latest animated values. This is a reference shared
         * between the element's VisualElement and the ProjectionNode.
         */
        latestValues: ResolvedValues$1;
        /**
         *
         */
        eventHandlers: Map<LayoutEvents, SubscriptionManager<any>>;
        nodes?: FlatTree | undefined;
        depth: number;
        /**
         * If transformTemplate generates a different value before/after the
         * update, we need to reset the transform.
         */
        prevTransformTemplateValue: string | undefined;
        preserveOpacity?: boolean | undefined;
        hasTreeAnimated: boolean;
        layoutVersion: number;
        addEventListener(name: LayoutEvents, handler: any): VoidFunction;
        notifyListeners(name: LayoutEvents, ...args: any): void;
        hasListeners(name: LayoutEvents): boolean;
        /**
         * Lifecycles
         */
        mount(instance: I): void;
        unmount(): void;
        blockUpdate(): void;
        unblockUpdate(): void;
        isUpdateBlocked(): boolean;
        isTreeAnimationBlocked(): boolean;
        startUpdate(): void;
        getTransformTemplate(): TransformTemplate | undefined;
        willUpdate(shouldNotifyListeners?: boolean): void;
        updateScheduled: boolean;
        update(): void;
        scheduleUpdate: () => void;
        didUpdate(): void;
        clearAllSnapshots(): void;
        projectionUpdateScheduled: boolean;
        scheduleUpdateProjection(): void;
        scheduleCheckAfterUnmount(): void;
        checkUpdateFailed: () => void;
        /**
         * This is a multi-step process as shared nodes might be of different depths. Nodes
         * are sorted by depth order, so we need to resolve the entire tree before moving to
         * the next step.
         */
        updateProjection: () => void;
        /**
         * Update measurements
         */
        updateSnapshot(): void;
        updateLayout(): void;
        updateScroll(phase?: Phase): void;
        resetTransform(): void;
        measure(removeTransform?: boolean): {
            animationId: number;
            measuredBox: Box;
            layoutBox: Box;
            latestValues: {};
            source: number;
        };
        measurePageBox(): Box;
        removeElementScroll(box: Box): Box;
        applyTransform(box: Box, transformOnly?: boolean): Box;
        removeTransform(box: Box): Box;
        setTargetDelta(delta: Delta): void;
        setOptions(options: ProjectionNodeOptions): void;
        clearMeasurements(): void;
        forceRelativeParentToResolveTarget(): void;
        /**
         * Frame calculations
         */
        resolvedRelativeTargetAt: number;
        resolveTargetDelta(forceRecalculation?: boolean): void;
        getClosestProjectingParent(): IProjectionNode<unknown> | undefined;
        isProjecting(): boolean;
        linkedParentVersion: number;
        createRelativeTarget(relativeParent: IProjectionNode, layout: Box, parentLayout: Box): void;
        removeRelativeTarget(): void;
        hasProjected: boolean;
        calcProjection(): void;
        isVisible: boolean;
        hide(): void;
        show(): void;
        scheduleRender(notifyAll?: boolean): void;
        createProjectionDeltas(): void;
        /**
         * Animation
         */
        animationValues?: ResolvedValues$1 | undefined;
        pendingAnimation?: Process | undefined;
        currentAnimation?: JSAnimation<number> | undefined;
        mixTargetDelta: (progress: number) => void;
        animationProgress: number;
        setAnimationOrigin(delta: Delta, hasOnlyRelativeTargetChanged?: boolean): void;
        motionValue?: MotionValue<number> | undefined;
        startAnimation(options: ValueAnimationOptions<number>): void;
        completeAnimation(): void;
        finishAnimation(): void;
        applyTransformsToTarget(): void;
        /**
         * Shared layout
         */
        sharedNodes: Map<string, NodeStack>;
        registerSharedNode(layoutId: string, node: IProjectionNode): void;
        isLead(): boolean;
        getLead(): IProjectionNode<unknown> | any;
        getPrevLead(): IProjectionNode<unknown> | undefined;
        getStack(): NodeStack | undefined;
        promote({ needsReset, transition, preserveFollowOpacity, }?: {
            needsReset?: boolean | undefined;
            transition?: Transition | undefined;
            preserveFollowOpacity?: boolean | undefined;
        }): void;
        relegate(): boolean;
        resetSkewAndRotation(): void;
        applyProjectionStyles(targetStyle: any, styleProp?: MotionStyle): void;
        clearSnapshot(): void;
        resetTree(): void;
    };
};
declare function propagateDirtyNodes(node: IProjectionNode): void;
declare function cleanDirtyNodes(node: IProjectionNode): void;

declare const DocumentProjectionNode: {
    new (latestValues?: ResolvedValues$1, parent?: IProjectionNode<unknown> | undefined): {
        id: number;
        animationId: number;
        animationCommitId: number;
        instance: Window | undefined;
        root: IProjectionNode<unknown>;
        parent?: IProjectionNode<unknown> | undefined;
        path: IProjectionNode<unknown>[];
        children: Set<IProjectionNode<unknown>>;
        options: ProjectionNodeOptions;
        snapshot: Measurements | undefined;
        layout: Measurements | undefined;
        targetLayout?: motion_utils.Box | undefined;
        layoutCorrected: motion_utils.Box;
        targetDelta?: motion_utils.Delta | undefined;
        target?: motion_utils.Box | undefined;
        relativeTarget?: motion_utils.Box | undefined;
        relativeTargetOrigin?: motion_utils.Box | undefined;
        relativeParent?: IProjectionNode<unknown> | undefined;
        isTreeAnimating: boolean;
        isAnimationBlocked: boolean;
        attemptToResolveRelativeTarget?: boolean | undefined;
        targetWithTransforms?: motion_utils.Box | undefined;
        prevProjectionDelta?: motion_utils.Delta | undefined;
        projectionDelta?: motion_utils.Delta | undefined;
        projectionDeltaWithTransform?: motion_utils.Delta | undefined;
        scroll?: ScrollMeasurements | undefined;
        isLayoutDirty: boolean;
        isProjectionDirty: boolean;
        isSharedProjectionDirty: boolean;
        isTransformDirty: boolean;
        updateManuallyBlocked: boolean;
        updateBlockedByResize: boolean;
        isUpdating: boolean;
        isSVG: boolean;
        needsReset: boolean;
        shouldResetTransform: boolean;
        hasCheckedOptimisedAppear: boolean;
        treeScale: motion_utils.Point;
        resumeFrom?: IProjectionNode<unknown> | undefined;
        resumingFrom?: IProjectionNode<unknown> | undefined;
        latestValues: ResolvedValues$1;
        eventHandlers: Map<LayoutEvents, motion_utils.SubscriptionManager<any>>;
        nodes?: FlatTree | undefined;
        depth: number;
        prevTransformTemplateValue: string | undefined;
        preserveOpacity?: boolean | undefined;
        hasTreeAnimated: boolean;
        layoutVersion: number;
        addEventListener(name: LayoutEvents, handler: any): VoidFunction;
        notifyListeners(name: LayoutEvents, ...args: any): void;
        hasListeners(name: LayoutEvents): boolean;
        mount(instance: Window): void;
        unmount(): void;
        blockUpdate(): void;
        unblockUpdate(): void;
        isUpdateBlocked(): boolean;
        isTreeAnimationBlocked(): boolean;
        startUpdate(): void;
        getTransformTemplate(): TransformTemplate | undefined;
        willUpdate(shouldNotifyListeners?: boolean): void;
        updateScheduled: boolean;
        update(): void;
        scheduleUpdate: () => void;
        didUpdate(): void;
        clearAllSnapshots(): void;
        projectionUpdateScheduled: boolean;
        scheduleUpdateProjection(): void;
        scheduleCheckAfterUnmount(): void;
        checkUpdateFailed: () => void;
        updateProjection: () => void;
        updateSnapshot(): void;
        updateLayout(): void;
        updateScroll(phase?: Phase): void;
        resetTransform(): void;
        measure(removeTransform?: boolean): {
            animationId: number;
            measuredBox: motion_utils.Box;
            layoutBox: motion_utils.Box;
            latestValues: {};
            source: number;
        };
        measurePageBox(): motion_utils.Box;
        removeElementScroll(box: motion_utils.Box): motion_utils.Box;
        applyTransform(box: motion_utils.Box, transformOnly?: boolean): motion_utils.Box;
        removeTransform(box: motion_utils.Box): motion_utils.Box;
        setTargetDelta(delta: motion_utils.Delta): void;
        setOptions(options: ProjectionNodeOptions): void;
        clearMeasurements(): void;
        forceRelativeParentToResolveTarget(): void;
        resolvedRelativeTargetAt: number;
        resolveTargetDelta(forceRecalculation?: boolean): void;
        getClosestProjectingParent(): IProjectionNode<unknown> | undefined;
        isProjecting(): boolean;
        linkedParentVersion: number;
        createRelativeTarget(relativeParent: IProjectionNode<unknown>, layout: motion_utils.Box, parentLayout: motion_utils.Box): void;
        removeRelativeTarget(): void;
        hasProjected: boolean;
        calcProjection(): void;
        isVisible: boolean;
        hide(): void;
        show(): void;
        scheduleRender(notifyAll?: boolean): void;
        createProjectionDeltas(): void;
        animationValues?: ResolvedValues$1 | undefined;
        pendingAnimation?: Process | undefined;
        currentAnimation?: JSAnimation<number> | undefined;
        mixTargetDelta: (progress: number) => void;
        animationProgress: number;
        setAnimationOrigin(delta: motion_utils.Delta, hasOnlyRelativeTargetChanged?: boolean): void;
        motionValue?: MotionValue<number> | undefined;
        startAnimation(options: ValueAnimationOptions<number>): void;
        completeAnimation(): void;
        finishAnimation(): void;
        applyTransformsToTarget(): void;
        sharedNodes: Map<string, NodeStack>;
        registerSharedNode(layoutId: string, node: IProjectionNode<unknown>): void;
        isLead(): boolean;
        getLead(): IProjectionNode<unknown> | any;
        getPrevLead(): IProjectionNode<unknown> | undefined;
        getStack(): NodeStack | undefined;
        promote({ needsReset, transition, preserveFollowOpacity, }?: {
            needsReset?: boolean | undefined;
            transition?: Transition | undefined;
            preserveFollowOpacity?: boolean | undefined;
        }): void;
        relegate(): boolean;
        resetSkewAndRotation(): void;
        applyProjectionStyles(targetStyle: any, styleProp?: MotionStyle | undefined): void;
        clearSnapshot(): void;
        resetTree(): void;
    };
};

interface NodeGroup {
    add: (node: IProjectionNode) => void;
    remove: (node: IProjectionNode) => void;
    dirty: VoidFunction;
}
declare function nodeGroup(): NodeGroup;

declare const rootProjectionNode: {
    current: IProjectionNode | undefined;
};
declare const HTMLProjectionNode: {
    new (latestValues?: ResolvedValues$1, parent?: IProjectionNode<unknown> | undefined): {
        id: number;
        animationId: number;
        animationCommitId: number;
        instance: HTMLElement | undefined;
        root: IProjectionNode<unknown>;
        parent?: IProjectionNode<unknown> | undefined;
        path: IProjectionNode<unknown>[];
        children: Set<IProjectionNode<unknown>>;
        options: ProjectionNodeOptions;
        snapshot: Measurements | undefined;
        layout: Measurements | undefined;
        targetLayout?: motion_utils.Box | undefined;
        layoutCorrected: motion_utils.Box;
        targetDelta?: motion_utils.Delta | undefined;
        target?: motion_utils.Box | undefined;
        relativeTarget?: motion_utils.Box | undefined;
        relativeTargetOrigin?: motion_utils.Box | undefined;
        relativeParent?: IProjectionNode<unknown> | undefined;
        isTreeAnimating: boolean;
        isAnimationBlocked: boolean;
        attemptToResolveRelativeTarget?: boolean | undefined;
        targetWithTransforms?: motion_utils.Box | undefined;
        prevProjectionDelta?: motion_utils.Delta | undefined;
        projectionDelta?: motion_utils.Delta | undefined;
        projectionDeltaWithTransform?: motion_utils.Delta | undefined;
        scroll?: ScrollMeasurements | undefined;
        isLayoutDirty: boolean;
        isProjectionDirty: boolean;
        isSharedProjectionDirty: boolean;
        isTransformDirty: boolean;
        updateManuallyBlocked: boolean;
        updateBlockedByResize: boolean;
        isUpdating: boolean;
        isSVG: boolean;
        needsReset: boolean;
        shouldResetTransform: boolean;
        hasCheckedOptimisedAppear: boolean;
        treeScale: motion_utils.Point;
        resumeFrom?: IProjectionNode<unknown> | undefined;
        resumingFrom?: IProjectionNode<unknown> | undefined;
        latestValues: ResolvedValues$1;
        eventHandlers: Map<LayoutEvents, motion_utils.SubscriptionManager<any>>;
        nodes?: FlatTree | undefined;
        depth: number;
        prevTransformTemplateValue: string | undefined;
        preserveOpacity?: boolean | undefined;
        hasTreeAnimated: boolean;
        layoutVersion: number;
        addEventListener(name: LayoutEvents, handler: any): VoidFunction;
        notifyListeners(name: LayoutEvents, ...args: any): void;
        hasListeners(name: LayoutEvents): boolean;
        mount(instance: HTMLElement): void;
        unmount(): void;
        blockUpdate(): void;
        unblockUpdate(): void;
        isUpdateBlocked(): boolean;
        isTreeAnimationBlocked(): boolean;
        startUpdate(): void;
        getTransformTemplate(): TransformTemplate | undefined;
        willUpdate(shouldNotifyListeners?: boolean): void;
        updateScheduled: boolean;
        update(): void;
        scheduleUpdate: () => void;
        didUpdate(): void;
        clearAllSnapshots(): void;
        projectionUpdateScheduled: boolean;
        scheduleUpdateProjection(): void;
        scheduleCheckAfterUnmount(): void;
        checkUpdateFailed: () => void;
        updateProjection: () => void;
        updateSnapshot(): void;
        updateLayout(): void;
        updateScroll(phase?: Phase): void;
        resetTransform(): void;
        measure(removeTransform?: boolean): {
            animationId: number;
            measuredBox: motion_utils.Box;
            layoutBox: motion_utils.Box;
            latestValues: {};
            source: number;
        };
        measurePageBox(): motion_utils.Box;
        removeElementScroll(box: motion_utils.Box): motion_utils.Box;
        applyTransform(box: motion_utils.Box, transformOnly?: boolean): motion_utils.Box;
        removeTransform(box: motion_utils.Box): motion_utils.Box;
        setTargetDelta(delta: motion_utils.Delta): void;
        setOptions(options: ProjectionNodeOptions): void;
        clearMeasurements(): void;
        forceRelativeParentToResolveTarget(): void;
        resolvedRelativeTargetAt: number;
        resolveTargetDelta(forceRecalculation?: boolean): void;
        getClosestProjectingParent(): IProjectionNode<unknown> | undefined;
        isProjecting(): boolean;
        linkedParentVersion: number;
        createRelativeTarget(relativeParent: IProjectionNode<unknown>, layout: motion_utils.Box, parentLayout: motion_utils.Box): void;
        removeRelativeTarget(): void;
        hasProjected: boolean;
        calcProjection(): void;
        isVisible: boolean;
        hide(): void;
        show(): void;
        scheduleRender(notifyAll?: boolean): void;
        createProjectionDeltas(): void;
        animationValues?: ResolvedValues$1 | undefined;
        pendingAnimation?: Process | undefined;
        currentAnimation?: JSAnimation<number> | undefined;
        mixTargetDelta: (progress: number) => void;
        animationProgress: number;
        setAnimationOrigin(delta: motion_utils.Delta, hasOnlyRelativeTargetChanged?: boolean): void;
        motionValue?: MotionValue<number> | undefined;
        startAnimation(options: ValueAnimationOptions<number>): void;
        completeAnimation(): void;
        finishAnimation(): void;
        applyTransformsToTarget(): void;
        sharedNodes: Map<string, NodeStack>;
        registerSharedNode(layoutId: string, node: IProjectionNode<unknown>): void;
        isLead(): boolean;
        getLead(): IProjectionNode<unknown> | any;
        getPrevLead(): IProjectionNode<unknown> | undefined;
        getStack(): NodeStack | undefined;
        promote({ needsReset, transition, preserveFollowOpacity, }?: {
            needsReset?: boolean | undefined;
            transition?: Transition | undefined;
            preserveFollowOpacity?: boolean | undefined;
        }): void;
        relegate(): boolean;
        resetSkewAndRotation(): void;
        applyProjectionStyles(targetStyle: any, styleProp?: MotionStyle | undefined): void;
        clearSnapshot(): void;
        resetTree(): void;
    };
};

/**
 * This should only ever be modified on the client otherwise it'll
 * persist through server requests. If we need instanced states we
 * could lazy-init via root.
 */
declare const globalProjectionState: {
    /**
     * Global flag as to whether the tree has animated since the last time
     * we resized the window
     */
    hasAnimatedSinceResize: boolean;
    /**
     * We set this to true once, on the first update. Any nodes added to the tree beyond that
     * update will be given a `data-projection-id` attribute.
     */
    hasEverUpdated: boolean;
};

declare function camelToDash(str: string): string;

declare function buildHTMLStyles(state: HTMLRenderState, latestValues: ResolvedValues$1, transformTemplate?: MotionNodeOptions["transformTemplate"]): void;

/**
 * Build a CSS transform style from individual x/y/scale etc properties.
 *
 * This outputs with a default order of transforms/scales/rotations, this can be customised by
 * providing a transformTemplate function.
 */
declare function buildTransform(latestValues: ResolvedValues$1, transform: HTMLRenderState["transform"], transformTemplate?: MotionNodeOptions["transformTemplate"]): string;

declare function scrapeMotionValuesFromProps$1(props: MotionNodeOptions, prevProps: MotionNodeOptions, visualElement?: VisualElement): {
    [key: string]: any;
};

/**
 * Build SVG visual attributes, like cx and style.transform
 */
declare function buildSVGAttrs(state: SVGRenderState, { attrX, attrY, attrScale, pathLength, pathSpacing, pathOffset, ...latest }: ResolvedValues$1, isSVGTag: boolean, transformTemplate?: MotionNodeOptions["transformTemplate"], styleProp?: Record<string, any>): void;

/**
 * A set of attribute names that are always read/written as camel case.
 */
declare const camelCaseAttributes: Set<string>;

declare const isSVGTag: (tag: unknown) => boolean;

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
declare function buildSVGPath(attrs: ResolvedValues$1, length: number, spacing?: number, offset?: number, useDashCase?: boolean): void;

declare function renderSVG(element: SVGElement, renderState: SVGRenderState, _styleProp?: MotionStyle, projection?: any): void;

declare function scrapeMotionValuesFromProps(props: MotionNodeOptions, prevProps: MotionNodeOptions, visualElement?: VisualElement): {
    [key: string]: any;
};

declare class LayoutAnimationBuilder implements PromiseLike<GroupAnimation> {
    private scope;
    private updateDom;
    private defaultOptions?;
    private sharedTransitions;
    private notifyReady;
    private readyPromise;
    private executed;
    constructor(scope: Element | Document, updateDom: () => void, defaultOptions?: AnimationOptions);
    shared(id: string, options: AnimationOptions): this;
    then<TResult1 = GroupAnimation, TResult2 = never>(onfulfilled?: ((value: GroupAnimation) => TResult1 | PromiseLike<TResult1>) | null, onrejected?: ((reason: any) => TResult2 | PromiseLike<TResult2>) | null): Promise<TResult1 | TResult2>;
    private execute;
    private getBuildOptions;
}
/**
 * Parse arguments for animateLayout overloads
 */
declare function parseAnimateLayoutArgs(scopeOrUpdateDom: ElementOrSelector | (() => void), updateDomOrOptions?: (() => void) | AnimationOptions, options?: AnimationOptions): {
    scope: Element | Document;
    updateDom: () => void;
    defaultOptions?: AnimationOptions;
};

/**
 * @deprecated
 *
 * Import as `frame` instead.
 */
declare const sync: Batcher;
/**
 * @deprecated
 *
 * Use cancelFrame(callback) instead.
 */
declare const cancelSync: Record<string, (process: Process) => void>;

export { type AcceptedAnimations, type ActiveStatsBuffer, type AnimationDefinition, type AnimationGeneratorName, type AnimationGeneratorType, type AnimationList, type AnimationOptions, type AnimationOrchestrationOptions, type AnimationPlaybackControls, type AnimationPlaybackControlsWithThen, type AnimationPlaybackLifecycles, type AnimationPlaybackOptions, type AnimationScope, type AnimationState, type AnimationType, type AnimationTypeState, type AnyResolvedKeyframe, AsyncMotionValueAnimation, type Batcher, type CSSStyleDeclarationWithTransform, type CSSVariableName, type CSSVariableToken, type CancelProcess, type Color, type ComplexValueInfo, type ComplexValues, type DOMKeyframesDefinition, DOMKeyframesResolver, type DOMValueAnimationOptions, DOMVisualElement, type DOMVisualElementOptions, type DecayOptions, type DelayedFunction, DocumentProjectionNode, type DragElastic, type DragHandler, type DraggableProps, type DurationSpringOptions, type DynamicOption, type ElementOrSelector, type EventInfo, type EventOptions, Feature, type FeatureClass, FlatTree, type FrameData, type FrameStats, type GeneratorFactory, type GeneratorFactoryFunction, GroupAnimation, GroupAnimationWithThen, type GroupedAnimations, type HSLA, HTMLProjectionNode, type HTMLRenderState, HTMLVisualElement, type HandoffFunction, type IProjectionNode, type InactiveStatsBuffer, type InertiaOptions, type InitialPromotionConfig, type InterpolateOptions, JSAnimation, type KeyframeGenerator, type KeyframeOptions, KeyframeResolver, LayoutAnimationBuilder, type LayoutEvents, type LayoutLifecycles, type LayoutUpdateData, type LayoutUpdateHandler, type LegacyAnimationControls, type MapInputRange, type Measurements, type Mixer, type MixerFactory, type MotionConfigContextProps, type MotionNodeAdvancedOptions, type MotionNodeAnimationOptions, type MotionNodeDragHandlers, type MotionNodeDraggableOptions, type MotionNodeEventOptions, type MotionNodeFocusHandlers, type MotionNodeHoverHandlers, type MotionNodeLayoutOptions, type MotionNodeOptions, type MotionNodePanHandlers, type MotionNodeTapHandlers, type MotionNodeViewportOptions, type MotionStyle, MotionValue, type MotionValueEventCallbacks, type MotionValueOptions, type MultiTransformer, NativeAnimation, NativeAnimationExtended, type NativeAnimationOptions, type NativeAnimationOptionsExtended, NativeAnimationWrapper, type NodeGroup, NodeStack, type NumberMap, ObjectVisualElement, type OnHoverEndEvent, type OnHoverStartEvent, type OnKeyframesResolved, type OnPressEndEvent, type OnPressStartEvent, type Owner, type PanHandler, type PanInfo, type PassiveEffect, type Phase, type PointerEventOptions, type PresenceContextProps, type PressGestureInfo, type Process, type ProgressTimeline, type ProjectionEventName, type ProjectionNodeConfig, type ProjectionNodeOptions, type RGBA, type ReducedMotionConfig, type RepeatType, type ResolvedConstraints, type ResolvedElastic, type ResolvedKeyframes, type ResolvedValueKeyframe, type ResolvedValues$1 as ResolvedValues, type SVGAttributes, type SVGForcedAttrKeyframesDefinition, type SVGForcedAttrProperties, type SVGForcedAttrTransitions, type SVGKeyframesDefinition, type SVGPathKeyframesDefinition, type SVGPathProperties, type SVGPathTransitions, type SVGRenderState, type SVGTransitions, SVGVisualElement, type ScaleCorrectionNode, type ScaleCorrector, type ScaleCorrectorDefinition, type ScaleCorrectorMap, type Schedule, type ScrapeMotionValuesFromProps, type ScrollMeasurements, type SelectorCache, type SingleTransformer, type Spring, type SpringOptions, type StaggerOptions, type StaggerOrigin, type StartAnimation, type Stats, type StatsBuffer, type StatsRecording, type StatsSummary, type Step, type StepId, type Steps, type StyleKeyframesDefinition, type StyleTransitions, type Subscriber, type Summary, type TapHandlers, type TapInfo, type Target, type TargetAndTransition, type TargetResolver, type TimelineWithFallback, type TransformInputRange, type TransformOptions, type TransformOrigin, type TransformProperties, type TransformTemplate, type Transformer, type Transition, type TransitionWithValueOverrides, type Tween, type UnresolvedKeyframes, type UnresolvedValueKeyframe, type UseRenderState, type ValueAnimationOptions, type ValueAnimationOptionsWithRenderContext, type ValueAnimationTransition, type ValueAnimationWithDynamicDelay, type ValueIndexes, type ValueKeyframe, type ValueKeyframesDefinition, type ValueTransformer, type ValueTransition, type ValueType, type ValueTypeMap, type VariableKeyframesDefinition, type VariableTransitions, type Variant, type VariantLabels, type Variants, type VelocityOptions, type ViewTransitionAnimationDefinition, ViewTransitionBuilder, type ViewTransitionOptions, type ViewTransitionTarget, type ViewTransitionTargetDefinition, type ViewportEventHandler, type ViewportOptions, VisualElement, type VisualElementAnimationOptions, type VisualElementEventCallbacks, type VisualElementOptions, type VisualState, type WillChange, type WithAppearProps, type WithDepth, type WithQuerySelectorAll, acceleratedValues, activeAnimations, addAttrValue, addDomEvent, addScaleCorrector, addStyleValue, addValueToWillChange, alpha, analyseComplexValue, animateMotionValue, animateSingleValue, animateTarget, animateValue, animateVariant, animateView, animateVisualElement, animationMapKey, applyAxisDelta, applyBoxDelta, applyGeneratorOptions, applyPointDelta, applyPxDefaults, applyTreeDeltas, aspectRatio, attachSpring, attrEffect, axisDeltaEquals, axisEquals, axisEqualsRounded, boxEquals, boxEqualsRounded, buildHTMLStyles, buildProjectionTransform, buildSVGAttrs, buildSVGPath, buildTransform, calcAxisDelta, calcBoxDelta, calcChildStagger, calcGeneratorDuration, calcLength, calcRelativeAxis, calcRelativeAxisPosition, calcRelativeBox, calcRelativePosition, camelCaseAttributes, camelToDash, cancelFrame, cancelMicrotask, cancelSync, checkVariantsDidChange, cleanDirtyNodes, collectMotionValues, color, compareByDepth, complex, containsCSSVariable, convertBoundingBoxToBox, convertBoxToBoundingBox, convertOffsetToTimes, copyAxisDeltaInto, copyAxisInto, copyBoxInto, correctBorderRadius, correctBoxShadow, createAnimationState, createAxis, createAxisDelta, createBox, createDelta, createGeneratorEasing, createProjectionNode, createRenderBatcher, cubicBezierAsString, defaultEasing, defaultOffset, defaultTransformValue, defaultValueTypes, degrees, delay, delayInSeconds, dimensionValueTypes, eachAxis, fillOffset, fillWildcards, findDimensionValueType, findValueType, flushKeyframeResolvers, frame, frameData, frameSteps, generateLinearEasing, getAnimatableNone, getAnimationMap, getComputedStyle, getDefaultTransition, getDefaultValueType, getFeatureDefinitions, getFinalKeyframe, getMixer, getOptimisedAppearId, getOriginIndex, getValueAsType, getValueTransition, getVariableValue, getVariantContext, getViewAnimationLayerInfo, getViewAnimations, globalProjectionState, has2DTranslate, hasReducedMotionListener, hasScale, hasTransform, hex, hover, hsla, hslaToRgba, inertia, initPrefersReducedMotion, interpolate, invisibleValues, isAnimationControls, isCSSVariableName, isCSSVariableToken, isControllingVariants, isDeltaZero, isDragActive, isDragging, isElementKeyboardAccessible, isForcedMotionValue, isGenerator, isHTMLElement, isKeyframesTarget, isMotionValue, isNear, isNodeOrChild, isPrimaryPointer, isSVGElement, isSVGSVGElement, isSVGTag, isTransitionDefined, isVariantLabel, isVariantNode, isWaapiSupportedEasing, isWillChangeMotionValue, keyframes, makeAnimationInstant, mapEasingToNativeEasing, mapValue, maxGeneratorDuration, measurePageBox, measureViewportBox, microtask, mix, mixArray, mixColor, mixComplex, mixImmediate, mixLinearColor, mixNumber, mixObject, mixValues, mixVisibility, motionValue, nodeGroup, number, numberValueTypes, observeTimeline, optimizedAppearDataAttribute, optimizedAppearDataId, parseAnimateLayoutArgs, parseCSSVariable, parseValueFromTransform, percent, pixelsToPercent, positionalKeys, prefersReducedMotion, press, progressPercentage, propEffect, propagateDirtyNodes, px, readTransformValue, recordStats, removeAxisDelta, removeAxisTransforms, removeBoxTransforms, removePointDelta, renderHTML, renderSVG, resize, resolveElements, resolveMotionValue, resolveVariant, resolveVariantFromProps, rgbUnit, rgba, rootProjectionNode, scale, scaleCorrectors, scalePoint, scrapeMotionValuesFromProps$1 as scrapeHTMLMotionValuesFromProps, scrapeMotionValuesFromProps as scrapeSVGMotionValuesFromProps, setDragLock, setFeatureDefinitions, setStyle, setTarget, spring, springValue, stagger, startWaapiAnimation, statsBuffer, styleEffect, supportedWaapiEasing, supportsBrowserAnimation, supportsFlags, supportsLinearEasing, supportsPartialKeyframes, supportsScrollTimeline, svgEffect, sync, testValueType, time, transform, transformAxis, transformBox, transformBoxPoints, transformPropOrder, transformProps, transformValue, transformValueTypes, translateAxis, updateMotionValuesFromProps, variantPriorityOrder, variantProps, vh, visualElementStore, vw };
