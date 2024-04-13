/**
 * Ethereum Beacon API requires the query with format:
 * - arrayFormat: repeat `topic=topic1&topic=topic2`
 */
export declare function stringifyQuery(query: unknown): string;
/**
 * TODO: Optimize, two regex is a bit wasteful
 */
export declare function urlJoin(...args: string[]): string;
//# sourceMappingURL=format.d.ts.map