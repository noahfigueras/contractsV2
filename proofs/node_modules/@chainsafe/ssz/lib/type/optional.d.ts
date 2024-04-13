import { Gindex, Node, Tree } from "@chainsafe/persistent-merkle-tree";
import { Require } from "../util/types";
import { Type, ByteViews, JsonPath, JsonPathProp } from "./abstract";
import { CompositeType } from "./composite";
export declare type OptionalOpts = {
    typeName?: string;
};
declare type ValueOfType<ElementType extends Type<unknown>> = ElementType extends Type<infer T> ? T | null : never;
/**
 * Optional: optional type containing either None or a type
 * - Notation: Optional[type], e.g. optional[uint64]
 * - merklizes as list of length 0 or 1, essentially acts like
 *   - like Union[none,type] or
 *   - list [], [type]
 */
export declare class OptionalType<ElementType extends Type<unknown>> extends CompositeType<ValueOfType<ElementType>, ValueOfType<ElementType>, ValueOfType<ElementType>> {
    readonly elementType: ElementType;
    readonly typeName: string;
    readonly depth: number;
    readonly maxChunkCount: number;
    readonly fixedSize: null;
    readonly minSize: number;
    readonly maxSize: number;
    readonly isList = true;
    readonly isViewMutable = true;
    constructor(elementType: ElementType, opts?: OptionalOpts);
    static named<ElementType extends Type<unknown>>(elementType: ElementType, opts: Require<OptionalOpts, "typeName">): OptionalType<ElementType>;
    defaultValue(): ValueOfType<ElementType>;
    getView(tree: Tree): ValueOfType<ElementType>;
    getViewDU(node: Node): ValueOfType<ElementType>;
    commitView(view: ValueOfType<ElementType>): Node;
    commitViewDU(view: ValueOfType<ElementType>): Node;
    cacheOfViewDU(): unknown;
    value_serializedSize(value: ValueOfType<ElementType>): number;
    value_serializeToBytes(output: ByteViews, offset: number, value: ValueOfType<ElementType>): number;
    value_deserializeFromBytes(data: ByteViews, start: number, end: number): ValueOfType<ElementType>;
    tree_serializedSize(node: Node): number;
    tree_serializeToBytes(output: ByteViews, offset: number, node: Node): number;
    tree_deserializeFromBytes(data: ByteViews, start: number, end: number): Node;
    hashTreeRoot(value: ValueOfType<ElementType>): Uint8Array;
    protected getRoots(value: ValueOfType<ElementType>): Uint8Array[];
    getPropertyGindex(prop: JsonPathProp): Gindex | null;
    getPropertyType(prop: JsonPathProp): Type<unknown>;
    getIndexProperty(index: number): JsonPathProp | null;
    tree_createProofGindexes(node: Node, jsonPaths: JsonPath[]): Gindex[];
    tree_getLeafGindices(rootGindex: bigint, rootNode?: Node): Gindex[];
    fromJson(json: unknown): ValueOfType<ElementType>;
    toJson(value: ValueOfType<ElementType>): unknown | Record<string, unknown>;
    clone(value: ValueOfType<ElementType>): ValueOfType<ElementType>;
    equals(a: ValueOfType<ElementType>, b: ValueOfType<ElementType>): boolean;
}
export {};
//# sourceMappingURL=optional.d.ts.map