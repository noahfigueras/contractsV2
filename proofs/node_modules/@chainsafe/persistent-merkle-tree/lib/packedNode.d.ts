import { Node, LeafNode } from "./node";
export declare function packedRootsBytesToNode(depth: number, dataView: DataView, start: number, end: number): Node;
/**
 * Pack a list of uint64 numbers into a list of LeafNodes.
 * Each value is UintNum64, which is 8 bytes long, which is 2 h values.
 * Each 4 of them forms a LeafNode.
 *
 *      v0            v1           v2          v3
 * |-------------|-------------|-------------|-------------|
 *
 *    h0     h1     h2     h3     h4     h5     h6     h7
 * |------|------|------|------|------|------|------|------|
 */
export declare function packedUintNum64sToLeafNodes(values: number[]): LeafNode[];
/**
 * Optimized deserialization of linear bytes to consecutive leaf nodes
 */
export declare function packedRootsBytesToLeafNodes(dataView: DataView, start: number, end: number): Node[];
/**
 * Optimized serialization of consecutive leave nodes to linear bytes
 */
export declare function packedNodeRootsToBytes(dataView: DataView, start: number, size: number, nodes: Node[]): void;
