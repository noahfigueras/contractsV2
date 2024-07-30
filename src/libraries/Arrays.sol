// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

library Arrays {

  /// @dev Returns array concatenating all items of arr1 and arr2
  function concat(uint256[] memory arr1, uint256[] memory arr2) internal pure returns(uint256[] memory tmp) {
    uint256 length = arr1.length + arr2.length;
    tmp = new uint256[](length);
    for(uint256 i = 0; i < arr1.length; i++) {
      tmp[i] = arr1[i];
    } 
    for(uint256 i = 0; i < arr2.length; i++) {
      tmp[arr1.length + i] = arr2[i];
    } 
  }

  /// @dev Returns array with new item at last position
  function push(uint256[] memory arr, uint256 item) internal pure returns(uint256[] memory tmp) {
    tmp = new uint256[](arr.length + 1);
    for(uint256 i = 0; i < arr.length; i++) {
      tmp[i] = arr[i];
    } 
    tmp[tmp.length - 1] = item;
  }

  /// @dev Returns array without last item 
  function pop(uint256[] memory arr) internal pure returns(uint256[] memory tmp) {
    require(arr.length > 0, "Empty Array");
    tmp = new uint256[](arr.length - 1);
    for(uint256 i = 0; i < arr.length - 1; i++) {
      tmp[i] = arr[i];
    } 
  }

  /// @dev Returns array without duplicates
  function difference(uint256[] memory arr1, uint256[] memory arr2) internal pure returns(uint256[] memory tmp) {
    for(uint256 i = 0; i < arr1.length; i++) {
      bool dup = false;
      for(uint256 x = 0; x < arr2.length; x++) {
        if(arr1[i] == arr2[x]) {
          dup = true;
          break;
        }
      } 
      for(uint256 y = i+1; y < arr1.length; y++) {
        if(arr1[i] == arr1[y]) {
          dup = true;
          break;
        }
      } 
      if(!dup) {
        tmp = push(tmp, arr1[i]);  
      }
    } 
  }

  /// @dev Returns array sorted from bigger to lesser 
  function sortReverse(uint256[] memory array) internal pure returns (uint256[] memory) {
    return sort(array, _reverse);
  }

  /// @dev Reverse sort comparator 
  function _reverse(uint256 a, uint256 b) private pure returns (bool) {
    return a > b;
  }

  /// @dev Sort an array of uint256 (in memory) following the provided comparator function.

  /// This function does the sorting "in place", meaning that it overrides the input. The object is returned for
  /// convenience, but that returned value can be discarded safely if the caller has a memory pointer to the array.

  /// NOTE: this function's cost is `O(n · log(n))` in average and `O(n²)` in the worst case, with n the length of the
  /// array. Using it in view functions that are executed through `eth_call` is safe, but one should be very careful
  /// when executing this as part of a transaction. If the array being sorted is too large, the sort operation may
  /// consume more gas than is available in a block, leading to potential DoS.
  function sort(
    uint256[] memory array,
    function(uint256, uint256) pure returns (bool) comp
  ) internal pure returns (uint256[] memory) {
    _quickSort(_begin(array), _end(array), comp);
    return array;
  }

  /// @dev Performs a quick sort of a segment of memory. The segment sorted starts at `begin` (inclusive), and stops
  /// at end (exclusive). Sorting follows the `comp` comparator.

  /// Invariant: `begin <= end`. This is the case when initially called by {sort} and is preserved in subcalls.
  
  /// IMPORTANT: Memory locations between `begin` and `end` are not validated/zeroed. This function should
  /// be used only if the limits are within a memory array.
  function _quickSort(uint256 begin, uint256 end, function(uint256, uint256) pure returns (bool) comp) private pure {
    unchecked {
      if (end - begin < 0x40) return;

      // Use first element as pivot
      uint256 pivot = _mload(begin);
      // Position where the pivot should be at the end of the loop
      uint256 pos = begin;

      for (uint256 it = begin + 0x20; it < end; it += 0x20) {
        if (comp(_mload(it), pivot)) {
          // If the value stored at the iterator's position comes before the pivot, we increment the
          // position of the pivot and move the value there.
          pos += 0x20;
          _swap(pos, it);
        }
      }

      _swap(begin, pos); // Swap pivot into place
      _quickSort(begin, pos, comp); // Sort the left side of the pivot
      _quickSort(pos + 0x20, end, comp); // Sort the right side of the pivot
    }
  }

  /// @dev Pointer to the memory location of the first element of `array`.
  function _begin(uint256[] memory array) private pure returns (uint256 ptr) {
    /// @solidity memory-safe-assembly
    assembly {
      ptr := add(array, 0x20)
    }
  }

  /// @dev Pointer to the memory location of the first memory word (32bytes) after `array`. This is the memory word
  /// that comes just after the last element of the array.
  function _end(uint256[] memory array) private pure returns (uint256 ptr) {
    unchecked {
      return _begin(array) + array.length * 0x20;
    }
  }

  /// @dev Load memory word (as a uint256) at location `ptr`.
  function _mload(uint256 ptr) private pure returns (uint256 value) {
    assembly {
      value := mload(ptr)
    }
  }

  /// @dev Swaps the elements memory location `ptr1` and `ptr2`.
  function _swap(uint256 ptr1, uint256 ptr2) private pure {
    assembly {
      let value1 := mload(ptr1)
      let value2 := mload(ptr2)
      mstore(ptr1, value2)
      mstore(ptr2, value1)
    }
  }
}
