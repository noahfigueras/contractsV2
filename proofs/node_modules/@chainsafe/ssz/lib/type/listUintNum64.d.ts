import { Node } from "@chainsafe/persistent-merkle-tree";
import { ListBasicTreeViewDU } from "../viewDU/listBasic";
import { ListBasicOpts, ListBasicType } from "./listBasic";
import { UintNumberType } from "./uint";
/**
 * Specific implementation of ListBasicType for UintNumberType with some optimizations.
 */
export declare class ListUintNum64Type extends ListBasicType<UintNumberType> {
    constructor(limit: number, opts?: ListBasicOpts);
    /**
     * Return a ListBasicTreeViewDU with nodes populated
     */
    toViewDU(value: number[]): ListBasicTreeViewDU<UintNumberType>;
    /**
     * No need to serialize and deserialize like in the abstract class
     */
    value_toTree(value: number[]): Node;
    private packedUintNum64sToNode;
}
//# sourceMappingURL=listUintNum64.d.ts.map