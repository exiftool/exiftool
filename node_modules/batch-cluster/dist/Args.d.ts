export type Args<T> = T extends (...args: infer A) => void ? A : never;
