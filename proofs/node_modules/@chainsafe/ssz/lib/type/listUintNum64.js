"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ListUintNum64Type = void 0;
const persistent_merkle_tree_1 = require("@chainsafe/persistent-merkle-tree");
const listBasic_1 = require("./listBasic");
const uint_1 = require("./uint");
const arrayBasic_1 = require("./arrayBasic");
/**
 * Specific implementation of ListBasicType for UintNumberType with some optimizations.
 */
class ListUintNum64Type extends listBasic_1.ListBasicType {
    constructor(limit, opts) {
        super(new uint_1.UintNumberType(8), limit, opts);
    }
    /**
     * Return a ListBasicTreeViewDU with nodes populated
     */
    toViewDU(value) {
        // no need to serialize and deserialize like in the abstract class
        const { treeNode, leafNodes } = this.packedUintNum64sToNode(value);
        // cache leaf nodes in the ViewDU
        return this.getViewDU(treeNode, {
            nodes: leafNodes,
            length: value.length,
            nodesPopulated: true,
        });
    }
    /**
     * No need to serialize and deserialize like in the abstract class
     */
    value_toTree(value) {
        const { treeNode } = this.packedUintNum64sToNode(value);
        return treeNode;
    }
    packedUintNum64sToNode(value) {
        if (value.length > this.limit) {
            throw new Error(`Exceeds limit: ${value.length} > ${this.limit}`);
        }
        const leafNodes = persistent_merkle_tree_1.packedUintNum64sToLeafNodes(value);
        // subtreeFillToContents mutates the leafNodes array
        const rootNode = persistent_merkle_tree_1.subtreeFillToContents([...leafNodes], this.chunkDepth);
        const treeNode = arrayBasic_1.addLengthNode(rootNode, value.length);
        return { treeNode, leafNodes };
    }
}
exports.ListUintNum64Type = ListUintNum64Type;
//# sourceMappingURL=listUintNum64.js.map