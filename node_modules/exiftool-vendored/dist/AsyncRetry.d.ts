export declare function retryOnReject<T>(f: () => T | Promise<T>, maxRetries: number): Promise<T>;
