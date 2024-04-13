"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.OptionalType = void 0;
const persistent_merkle_tree_1 = require("@chainsafe/persistent-merkle-tree");
const merkleize_1 = require("../util/merkleize");
const named_1 = require("../util/named");
const composite_1 = require("./composite");
const arrayBasic_1 = require("./arrayBasic");
const VALUE_GINDEX = BigInt(2);
const SELECTOR_GINDEX = BigInt(3);
/**
 * Optional: optional type containing either None or a type
 * - Notation: Optional[type], e.g. optional[uint64]
 * - merklizes as list of length 0 or 1, essentially acts like
 *   - like Union[none,type] or
 *   - list [], [type]
 */
class OptionalType extends composite_1.CompositeType {
    constructor(elementType, opts) {
        super();
        this.elementType = elementType;
        this.fixedSize = null;
        this.isList = true;
        this.isViewMutable = true;
        this.typeName = opts?.typeName ?? `Optional[${elementType.typeName}]`;
        this.maxChunkCount = 1;
        // Depth includes the extra level for the true/false node
        this.depth = elementType.depth + 1;
        this.minSize = 0;
        // Max size includes prepended 0x01 byte
        this.maxSize = elementType.maxSize + 1;
    }
    static named(elementType, opts) {
        return new (named_1.namedClass(OptionalType, opts.typeName))(elementType, opts);
    }
    defaultValue() {
        return null;
    }
    // TODO add an OptionalView
    getView(tree) {
        return this.tree_toValue(tree.rootNode);
    }
    // TODO add an OptionalViewDU
    getViewDU(node) {
        return this.tree_toValue(node);
    }
    // TODO add an OptionalView
    commitView(view) {
        return this.value_toTree(view);
    }
    // TODO add an OptionalViewDU
    commitViewDU(view) {
        return this.value_toTree(view);
    }
    // TODO add an OptionalViewDU
    cacheOfViewDU() {
        return;
    }
    value_serializedSize(value) {
        return value !== null ? 1 + this.elementType.value_serializedSize(value) : 0;
    }
    value_serializeToBytes(output, offset, value) {
        if (value !== null) {
            output.uint8Array[offset] = 1;
            return this.elementType.value_serializeToBytes(output, offset + 1, value);
        }
        else {
            return offset;
        }
    }
    value_deserializeFromBytes(data, start, end) {
        if (start === end) {
            return null;
        }
        else {
            const selector = data.uint8Array[start];
            if (selector !== 1) {
                throw new Error(`Invalid selector for Optional type: ${selector}`);
            }
            return this.elementType.value_deserializeFromBytes(data, start + 1, end);
        }
    }
    tree_serializedSize(node) {
        const selector = arrayBasic_1.getLengthFromRootNode(node);
        if (selector === 0) {
            return 0;
        }
        else if (selector === 1) {
            return 1 + this.elementType.value_serializedSize(node.left);
        }
        else {
            throw new Error(`Invalid selector for Optional type: ${selector}`);
        }
    }
    tree_serializeToBytes(output, offset, node) {
        const selector = arrayBasic_1.getLengthFromRootNode(node);
        if (selector === 0) {
            return offset;
        }
        else if (selector === 1) {
            output.uint8Array[offset] = 1;
            return this.elementType.tree_serializeToBytes(output, offset + 1, node.left);
        }
        else {
            throw new Error(`Invalid selector for Optional type: ${selector}`);
        }
    }
    tree_deserializeFromBytes(data, start, end) {
        let valueNode;
        let selector;
        if (start === end) {
            selector = 0;
            valueNode = persistent_merkle_tree_1.zeroNode(0);
        }
        else {
            selector = data.uint8Array[start];
            if (selector !== 1) {
                throw new Error(`Invalid selector for Optional type: ${selector}`);
            }
            valueNode = this.elementType.tree_deserializeFromBytes(data, start + 1, end);
        }
        return arrayBasic_1.addLengthNode(valueNode, selector);
    }
    // Merkleization
    hashTreeRoot(value) {
        const selector = value === null ? 0 : 1;
        return merkleize_1.mixInLength(super.hashTreeRoot(value), selector);
    }
    getRoots(value) {
        const valueRoot = value === null ? new Uint8Array(32) : this.elementType.hashTreeRoot(value);
        return [valueRoot];
    }
    // Proofs
    getPropertyGindex(prop) {
        if (composite_1.isCompositeType(this.elementType)) {
            const propIndex = this.elementType.getPropertyGindex(prop);
            return propIndex === null ? propIndex : persistent_merkle_tree_1.concatGindices([VALUE_GINDEX, propIndex]);
        }
        else {
            throw new Error("not applicable for Optional basic type");
        }
    }
    getPropertyType(prop) {
        if (composite_1.isCompositeType(this.elementType)) {
            return this.elementType.getPropertyType(prop);
        }
        else {
            throw new Error("not applicable for Optional basic type");
        }
    }
    getIndexProperty(index) {
        if (composite_1.isCompositeType(this.elementType)) {
            return this.elementType.getIndexProperty(index);
        }
        else {
            throw new Error("not applicable for Optional basic type");
        }
    }
    tree_createProofGindexes(node, jsonPaths) {
        if (composite_1.isCompositeType(this.elementType)) {
            return super.tree_createProofGindexes(node, jsonPaths);
        }
        else {
            throw new Error("not applicable for Optional basic type");
        }
    }
    tree_getLeafGindices(rootGindex, rootNode) {
        if (!rootNode) {
            throw new Error("Optional type requires rootNode argument to get leaves");
        }
        const selector = arrayBasic_1.getLengthFromRootNode(rootNode);
        if (composite_1.isCompositeType(this.elementType) && selector === 1) {
            return [
                //
                ...this.elementType.tree_getLeafGindices(persistent_merkle_tree_1.concatGindices([rootGindex, VALUE_GINDEX]), rootNode.left),
                persistent_merkle_tree_1.concatGindices([rootGindex, SELECTOR_GINDEX]),
            ];
        }
        else if (selector === 0 || selector === 1) {
            return [
                //
                persistent_merkle_tree_1.concatGindices([rootGindex, VALUE_GINDEX]),
                persistent_merkle_tree_1.concatGindices([rootGindex, SELECTOR_GINDEX]),
            ];
        }
        else {
            throw new Error(`Invalid selector for Optional type: ${selector}`);
        }
    }
    // JSON
    fromJson(json) {
        return (json === null ? null : this.elementType.fromJson(json));
    }
    toJson(value) {
        return value === null ? null : this.elementType.toJson(value);
    }
    clone(value) {
        return (value === null ? null : this.elementType.clone(value));
    }
    equals(a, b) {
        if (a === null && b === null) {
            return true;
        }
        else if (a === null || b === null) {
            return false;
        }
        return this.elementType.equals(a, b);
    }
}
exports.OptionalType = OptionalType;
//# sourceMappingURL=optional.js.map