// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 ^0.8.0 ^0.8.1 ^0.8.2;

// contracts/compound/EIP20Interface.sol

/**
 * @title ERC 20 Token Standard Interface
 *  https://eips.ethereum.org/EIPS/eip-20
 */
interface EIP20Interface {
  function name() external view returns (string memory);

  function symbol() external view returns (string memory);

  function decimals() external view returns (uint8);

  /**
   * @notice Get the total number of tokens in circulation
   * @return uint256 The supply of tokens
   */
  function totalSupply() external view returns (uint256);

  /**
   * @notice Gets the balance of the specified address
   * @param owner The address from which the balance will be retrieved
   * @return balance uint256 The balance
   */
  function balanceOf(address owner) external view returns (uint256 balance);

  /**
   * @notice Transfer `amount` tokens from `msg.sender` to `dst`
   * @param dst The address of the destination account
   * @param amount The number of tokens to transfer
   * @return success bool Whether or not the transfer succeeded
   */
  function transfer(address dst, uint256 amount) external returns (bool success);

  /**
   * @notice Transfer `amount` tokens from `src` to `dst`
   * @param src The address of the source account
   * @param dst The address of the destination account
   * @param amount The number of tokens to transfer
   * @return success bool Whether or not the transfer succeeded
   */
  function transferFrom(
    address src,
    address dst,
    uint256 amount
  ) external returns (bool success);

  /**
   * @notice Approve `spender` to transfer up to `amount` from `src`
   * @dev This will overwrite the approval amount for `spender`
   *  and is subject to issues noted [here](https://eips.ethereum.org/EIPS/eip-20#approve)
   * @param spender The address of the account which may transfer tokens
   * @param amount The number of tokens that are approved (-1 means infinite)
   * @return success bool Whether or not the approval succeeded
   */
  function approve(address spender, uint256 amount) external returns (bool success);

  /**
   * @notice Get the current allowance from `owner` for `spender`
   * @param owner The address of the account which owns the tokens to be spent
   * @param spender The address of the account which may transfer tokens
   * @return remaining uint256 The number of tokens allowed to be spent (-1 means infinite)
   */
  function allowance(address owner, address spender) external view returns (uint256 remaining);

  event Transfer(address indexed from, address indexed to, uint256 amount);
  event Approval(address indexed owner, address indexed spender, uint256 amount);
}

// contracts/compound/InterestRateModel.sol

/**
 * @title Compound's InterestRateModel Interface
 * @author Compound
 */
abstract contract InterestRateModel {
  /// @notice Indicator that this is an InterestRateModel contract (for inspection)
  bool public constant isInterestRateModel = true;

  /**
   * @notice Calculates the current borrow interest rate per block
   * @param cash The total amount of cash the market has
   * @param borrows The total amount of borrows the market has outstanding
   * @param reserves The total amount of reserves the market has
   * @return The borrow rate per block (as a percentage, and scaled by 1e18)
   */
  function getBorrowRate(
    uint256 cash,
    uint256 borrows,
    uint256 reserves
  ) public view virtual returns (uint256);

  /**
   * @notice Calculates the current supply interest rate per block
   * @param cash The total amount of cash the market has
   * @param borrows The total amount of borrows the market has outstanding
   * @param reserves The total amount of reserves the market has
   * @param reserveFactorMantissa The current reserve factor the market has
   * @return The supply rate per block (as a percentage, and scaled by 1e18)
   */
  function getSupplyRate(
    uint256 cash,
    uint256 borrows,
    uint256 reserves,
    uint256 reserveFactorMantissa
  ) public view virtual returns (uint256);
}

// contracts/ionic/DiamondExtension.sol

/**
 * @notice a base contract for logic extensions that use the diamond pattern storage
 * to map the functions when looking up the extension contract to delegate to.
 */
abstract contract DiamondExtension {
  /**
   * @return a list of all the function selectors that this logic extension exposes
   */
  function _getExtensionFunctions() external pure virtual returns (bytes4[] memory);
}

// When no function exists for function called
error FunctionNotFound(bytes4 _functionSelector);

// When no extension exists for function called
error ExtensionNotFound(bytes4 _functionSelector);

// When the function is already added
error FunctionAlreadyAdded(bytes4 _functionSelector, address _currentImpl);

abstract contract DiamondBase {
  /**
   * @dev register a logic extension
   * @param extensionToAdd the extension whose functions are to be added
   * @param extensionToReplace the extension whose functions are to be removed/replaced
   */
  function _registerExtension(DiamondExtension extensionToAdd, DiamondExtension extensionToReplace) external virtual;

  function _listExtensions() public view returns (address[] memory) {
    return LibDiamond.listExtensions();
  }

  fallback() external {
    address extension = LibDiamond.getExtensionForFunction(msg.sig);
    if (extension == address(0)) revert FunctionNotFound(msg.sig);
    // Execute external function from extension using delegatecall and return any value.
    assembly {
      // copy function selector and any arguments
      calldatacopy(0, 0, calldatasize())
      // execute function call using the extension
      let result := delegatecall(gas(), extension, 0, calldatasize(), 0, 0)
      // get any return value
      returndatacopy(0, 0, returndatasize())
      // return any return value or error back to the caller
      switch result
      case 0 {
        revert(0, returndatasize())
      }
      default {
        return(0, returndatasize())
      }
    }
  }
}

/**
 * @notice a library to use in a contract, whose logic is extended with diamond extension
 */
library LibDiamond {
  bytes32 constant DIAMOND_STORAGE_POSITION = keccak256("diamond.extensions.diamond.storage");

  struct Function {
    address extension;
    bytes4 selector;
  }

  struct LogicStorage {
    Function[] functions;
    address[] extensions;
  }

  function getExtensionForFunction(bytes4 msgSig) internal view returns (address) {
    return getExtensionForSelector(msgSig, diamondStorage());
  }

  function diamondStorage() internal pure returns (LogicStorage storage ds) {
    bytes32 position = DIAMOND_STORAGE_POSITION;
    assembly {
      ds.slot := position
    }
  }

  function listExtensions() internal view returns (address[] memory) {
    return diamondStorage().extensions;
  }

  function registerExtension(DiamondExtension extensionToAdd, DiamondExtension extensionToReplace) internal {
    if (address(extensionToReplace) != address(0)) {
      removeExtension(extensionToReplace);
    }
    addExtension(extensionToAdd);
  }

  function removeExtension(DiamondExtension extension) internal {
    LogicStorage storage ds = diamondStorage();
    // remove all functions of the extension to replace
    removeExtensionFunctions(extension);
    for (uint8 i = 0; i < ds.extensions.length; i++) {
      if (ds.extensions[i] == address(extension)) {
        ds.extensions[i] = ds.extensions[ds.extensions.length - 1];
        ds.extensions.pop();
      }
    }
  }

  function addExtension(DiamondExtension extension) internal {
    LogicStorage storage ds = diamondStorage();
    for (uint8 i = 0; i < ds.extensions.length; i++) {
      require(ds.extensions[i] != address(extension), "extension already added");
    }
    addExtensionFunctions(extension);
    ds.extensions.push(address(extension));
  }

  function removeExtensionFunctions(DiamondExtension extension) internal {
    bytes4[] memory fnsToRemove = extension._getExtensionFunctions();
    LogicStorage storage ds = diamondStorage();
    for (uint16 i = 0; i < fnsToRemove.length; i++) {
      bytes4 selectorToRemove = fnsToRemove[i];
      // must never fail
      assert(address(extension) == getExtensionForSelector(selectorToRemove, ds));
      // swap with the last element in the selectorAtIndex array and remove the last element
      uint16 indexToKeep = getIndexForSelector(selectorToRemove, ds);
      ds.functions[indexToKeep] = ds.functions[ds.functions.length - 1];
      ds.functions.pop();
    }
  }

  function addExtensionFunctions(DiamondExtension extension) internal {
    bytes4[] memory fnsToAdd = extension._getExtensionFunctions();
    LogicStorage storage ds = diamondStorage();
    uint16 functionsCount = uint16(ds.functions.length);
    for (uint256 functionsIndex = 0; functionsIndex < fnsToAdd.length; functionsIndex++) {
      bytes4 selector = fnsToAdd[functionsIndex];
      address oldImplementation = getExtensionForSelector(selector, ds);
      if (oldImplementation != address(0)) revert FunctionAlreadyAdded(selector, oldImplementation);
      ds.functions.push(Function(address(extension), selector));
      functionsCount++;
    }
  }

  function getExtensionForSelector(bytes4 selector, LogicStorage storage ds) internal view returns (address) {
    uint256 fnsLen = ds.functions.length;
    for (uint256 i = 0; i < fnsLen; i++) {
      if (ds.functions[i].selector == selector) return ds.functions[i].extension;
    }

    return address(0);
  }

  function getIndexForSelector(bytes4 selector, LogicStorage storage ds) internal view returns (uint16) {
    uint16 fnsLen = uint16(ds.functions.length);
    for (uint16 i = 0; i < fnsLen; i++) {
      if (ds.functions[i].selector == selector) return i;
    }

    return type(uint16).max;
  }
}

// lib/openzeppelin-contracts/contracts/interfaces/draft-IERC1822.sol

// OpenZeppelin Contracts (last updated v4.5.0) (interfaces/draft-IERC1822.sol)

/**
 * @dev ERC1822: Universal Upgradeable Proxy Standard (UUPS) documents a method for upgradeability through a simplified
 * proxy whose upgrades are fully controlled by the current implementation.
 */
interface IERC1822Proxiable {
    /**
     * @dev Returns the storage slot that the proxiable contract assumes is being used to store the implementation
     * address.
     *
     * IMPORTANT: A proxy pointing at a proxiable contract should not be considered proxiable itself, because this risks
     * bricking a proxy that upgrades to it, by delegating to itself until out of gas. Thus it is critical that this
     * function revert if invoked through a proxy.
     */
    function proxiableUUID() external view returns (bytes32);
}

// lib/openzeppelin-contracts/contracts/proxy/Proxy.sol

// OpenZeppelin Contracts (last updated v4.6.0) (proxy/Proxy.sol)

/**
 * @dev This abstract contract provides a fallback function that delegates all calls to another contract using the EVM
 * instruction `delegatecall`. We refer to the second contract as the _implementation_ behind the proxy, and it has to
 * be specified by overriding the virtual {_implementation} function.
 *
 * Additionally, delegation to the implementation can be triggered manually through the {_fallback} function, or to a
 * different contract through the {_delegate} function.
 *
 * The success and return data of the delegated call will be returned back to the caller of the proxy.
 */
abstract contract Proxy {
    /**
     * @dev Delegates the current call to `implementation`.
     *
     * This function does not return to its internal call site, it will return directly to the external caller.
     */
    function _delegate(address implementation) internal virtual {
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())

            // Call the implementation.
            // out and outsize are 0 because we don't know the size yet.
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)

            // Copy the returned data.
            returndatacopy(0, 0, returndatasize())

            switch result
            // delegatecall returns 0 on error.
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    /**
     * @dev This is a virtual function that should be overridden so it returns the address to which the fallback function
     * and {_fallback} should delegate.
     */
    function _implementation() internal view virtual returns (address);

    /**
     * @dev Delegates the current call to the address returned by `_implementation()`.
     *
     * This function does not return to its internal call site, it will return directly to the external caller.
     */
    function _fallback() internal virtual {
        _beforeFallback();
        _delegate(_implementation());
    }

    /**
     * @dev Fallback function that delegates calls to the address returned by `_implementation()`. Will run if no other
     * function in the contract matches the call data.
     */
    fallback() external payable virtual {
        _fallback();
    }

    /**
     * @dev Fallback function that delegates calls to the address returned by `_implementation()`. Will run if call data
     * is empty.
     */
    receive() external payable virtual {
        _fallback();
    }

    /**
     * @dev Hook that is called before falling back to the implementation. Can happen as part of a manual `_fallback`
     * call, or as part of the Solidity `fallback` or `receive` functions.
     *
     * If overridden should call `super._beforeFallback()`.
     */
    function _beforeFallback() internal virtual {}
}

// lib/openzeppelin-contracts/contracts/proxy/beacon/IBeacon.sol

// OpenZeppelin Contracts v4.4.1 (proxy/beacon/IBeacon.sol)

/**
 * @dev This is the interface that {BeaconProxy} expects of its beacon.
 */
interface IBeacon {
    /**
     * @dev Must return an address that can be used as a delegate call target.
     *
     * {BeaconProxy} will check that this address is a contract.
     */
    function implementation() external view returns (address);
}

// lib/openzeppelin-contracts/contracts/utils/Address.sol

// OpenZeppelin Contracts (last updated v4.7.0) (utils/Address.sol)

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and revert (either by bubbling
     * the revert reason or using the provided one) in case of unsuccessful call or if target was not a contract.
     *
     * _Available since v4.8._
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        if (success) {
            if (returndata.length == 0) {
                // only check isContract if the call was successful and the return data is empty
                // otherwise we already know that it was a contract
                require(isContract(target), "Address: call to non-contract");
            }
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason or using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    function _revert(bytes memory returndata, string memory errorMessage) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert(errorMessage);
        }
    }
}

// lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol

// OpenZeppelin Contracts (last updated v4.7.0) (utils/StorageSlot.sol)

/**
 * @dev Library for reading and writing primitive types to specific storage slots.
 *
 * Storage slots are often used to avoid storage conflict when dealing with upgradeable contracts.
 * This library helps with reading and writing to such slots without the need for inline assembly.
 *
 * The functions in this library return Slot structs that contain a `value` member that can be used to read or write.
 *
 * Example usage to set ERC1967 implementation slot:
 * ```
 * contract ERC1967 {
 *     bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
 *
 *     function _getImplementation() internal view returns (address) {
 *         return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
 *     }
 *
 *     function _setImplementation(address newImplementation) internal {
 *         require(Address.isContract(newImplementation), "ERC1967: new implementation is not a contract");
 *         StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
 *     }
 * }
 * ```
 *
 * _Available since v4.1 for `address`, `bool`, `bytes32`, and `uint256`._
 */
library StorageSlot {
    struct AddressSlot {
        address value;
    }

    struct BooleanSlot {
        bool value;
    }

    struct Bytes32Slot {
        bytes32 value;
    }

    struct Uint256Slot {
        uint256 value;
    }

    /**
     * @dev Returns an `AddressSlot` with member `value` located at `slot`.
     */
    function getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `BooleanSlot` with member `value` located at `slot`.
     */
    function getBooleanSlot(bytes32 slot) internal pure returns (BooleanSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `Bytes32Slot` with member `value` located at `slot`.
     */
    function getBytes32Slot(bytes32 slot) internal pure returns (Bytes32Slot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `Uint256Slot` with member `value` located at `slot`.
     */
    function getUint256Slot(bytes32 slot) internal pure returns (Uint256Slot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }
}

// lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol

// OpenZeppelin Contracts (last updated v4.7.0) (utils/structs/EnumerableSet.sol)
// This file was procedurally generated from scripts/generate/templates/EnumerableSet.js.

/**
 * @dev Library for managing
 * https://en.wikipedia.org/wiki/Set_(abstract_data_type)[sets] of primitive
 * types.
 *
 * Sets have the following properties:
 *
 * - Elements are added, removed, and checked for existence in constant time
 * (O(1)).
 * - Elements are enumerated in O(n). No guarantees are made on the ordering.
 *
 * ```
 * contract Example {
 *     // Add the library methods
 *     using EnumerableSet for EnumerableSet.AddressSet;
 *
 *     // Declare a set state variable
 *     EnumerableSet.AddressSet private mySet;
 * }
 * ```
 *
 * As of v3.3.0, sets of type `bytes32` (`Bytes32Set`), `address` (`AddressSet`)
 * and `uint256` (`UintSet`) are supported.
 *
 * [WARNING]
 * ====
 * Trying to delete such a structure from storage will likely result in data corruption, rendering the structure
 * unusable.
 * See https://github.com/ethereum/solidity/pull/11843[ethereum/solidity#11843] for more info.
 *
 * In order to clean an EnumerableSet, you can either remove all elements one by one or create a fresh instance using an
 * array of EnumerableSet.
 * ====
 */
library EnumerableSet {
    // To implement this library for multiple types with as little code
    // repetition as possible, we write it in terms of a generic Set type with
    // bytes32 values.
    // The Set implementation uses private functions, and user-facing
    // implementations (such as AddressSet) are just wrappers around the
    // underlying Set.
    // This means that we can only create new EnumerableSets for types that fit
    // in bytes32.

    struct Set {
        // Storage of set values
        bytes32[] _values;
        // Position of the value in the `values` array, plus 1 because index 0
        // means a value is not in the set.
        mapping(bytes32 => uint256) _indexes;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function _add(Set storage set, bytes32 value) private returns (bool) {
        if (!_contains(set, value)) {
            set._values.push(value);
            // The value is stored at length-1, but we add 1 to all indexes
            // and use 0 as a sentinel value
            set._indexes[value] = set._values.length;
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function _remove(Set storage set, bytes32 value) private returns (bool) {
        // We read and store the value's index to prevent multiple reads from the same storage slot
        uint256 valueIndex = set._indexes[value];

        if (valueIndex != 0) {
            // Equivalent to contains(set, value)
            // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
            // the array, and then remove the last element (sometimes called as 'swap and pop').
            // This modifies the order of the array, as noted in {at}.

            uint256 toDeleteIndex = valueIndex - 1;
            uint256 lastIndex = set._values.length - 1;

            if (lastIndex != toDeleteIndex) {
                bytes32 lastValue = set._values[lastIndex];

                // Move the last value to the index where the value to delete is
                set._values[toDeleteIndex] = lastValue;
                // Update the index for the moved value
                set._indexes[lastValue] = valueIndex; // Replace lastValue's index to valueIndex
            }

            // Delete the slot where the moved value was stored
            set._values.pop();

            // Delete the index for the deleted slot
            delete set._indexes[value];

            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function _contains(Set storage set, bytes32 value) private view returns (bool) {
        return set._indexes[value] != 0;
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function _length(Set storage set) private view returns (uint256) {
        return set._values.length;
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function _at(Set storage set, uint256 index) private view returns (bytes32) {
        return set._values[index];
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function _values(Set storage set) private view returns (bytes32[] memory) {
        return set._values;
    }

    // Bytes32Set

    struct Bytes32Set {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _add(set._inner, value);
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _remove(set._inner, value);
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(Bytes32Set storage set, bytes32 value) internal view returns (bool) {
        return _contains(set._inner, value);
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(Bytes32Set storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(Bytes32Set storage set, uint256 index) internal view returns (bytes32) {
        return _at(set._inner, index);
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(Bytes32Set storage set) internal view returns (bytes32[] memory) {
        bytes32[] memory store = _values(set._inner);
        bytes32[] memory result;

        /// @solidity memory-safe-assembly
        assembly {
            result := store
        }

        return result;
    }

    // AddressSet

    struct AddressSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(AddressSet storage set, address value) internal returns (bool) {
        return _add(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(AddressSet storage set, address value) internal returns (bool) {
        return _remove(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(AddressSet storage set, address value) internal view returns (bool) {
        return _contains(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(AddressSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(AddressSet storage set, uint256 index) internal view returns (address) {
        return address(uint160(uint256(_at(set._inner, index))));
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(AddressSet storage set) internal view returns (address[] memory) {
        bytes32[] memory store = _values(set._inner);
        address[] memory result;

        /// @solidity memory-safe-assembly
        assembly {
            result := store
        }

        return result;
    }

    // UintSet

    struct UintSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(UintSet storage set, uint256 value) internal returns (bool) {
        return _add(set._inner, bytes32(value));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(UintSet storage set, uint256 value) internal returns (bool) {
        return _remove(set._inner, bytes32(value));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(UintSet storage set, uint256 value) internal view returns (bool) {
        return _contains(set._inner, bytes32(value));
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(UintSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(UintSet storage set, uint256 index) internal view returns (uint256) {
        return uint256(_at(set._inner, index));
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(UintSet storage set) internal view returns (uint256[] memory) {
        bytes32[] memory store = _values(set._inner);
        uint256[] memory result;

        /// @solidity memory-safe-assembly
        assembly {
            result := store
        }

        return result;
    }
}

// lib/openzeppelin-contracts-upgradeable/contracts/utils/AddressUpgradeable.sol

// OpenZeppelin Contracts (last updated v4.7.0) (utils/Address.sol)

/**
 * @dev Collection of functions related to the address type
 */
library AddressUpgradeable {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and revert (either by bubbling
     * the revert reason or using the provided one) in case of unsuccessful call or if target was not a contract.
     *
     * _Available since v4.8._
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        if (success) {
            if (returndata.length == 0) {
                // only check isContract if the call was successful and the return data is empty
                // otherwise we already know that it was a contract
                require(isContract(target), "Address: call to non-contract");
            }
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason or using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    function _revert(bytes memory returndata, string memory errorMessage) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert(errorMessage);
        }
    }
}

// lib/solmate/src/auth/Auth.sol

/// @notice Provides a flexible and updatable auth pattern which is completely separate from application logic.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/auth/Auth.sol)
/// @author Modified from Dappsys (https://github.com/dapphub/ds-auth/blob/master/src/auth.sol)
abstract contract Auth {
    event OwnerUpdated(address indexed user, address indexed newOwner);

    event AuthorityUpdated(address indexed user, Authority indexed newAuthority);

    address public owner;

    Authority public authority;

    constructor(address _owner, Authority _authority) {
        owner = _owner;
        authority = _authority;

        emit OwnerUpdated(msg.sender, _owner);
        emit AuthorityUpdated(msg.sender, _authority);
    }

    modifier requiresAuth() virtual {
        require(isAuthorized(msg.sender, msg.sig), "UNAUTHORIZED");

        _;
    }

    function isAuthorized(address user, bytes4 functionSig) internal view virtual returns (bool) {
        Authority auth = authority; // Memoizing authority saves us a warm SLOAD, around 100 gas.

        // Checking if the caller is the owner only after calling the authority saves gas in most cases, but be
        // aware that this makes protected functions uncallable even to the owner if the authority is out of order.
        return (address(auth) != address(0) && auth.canCall(user, address(this), functionSig)) || user == owner;
    }

    function setAuthority(Authority newAuthority) public virtual {
        // We check if the caller is the owner first because we want to ensure they can
        // always swap out the authority even if it's reverting or using up a lot of gas.
        require(msg.sender == owner || authority.canCall(msg.sender, address(this), msg.sig));

        authority = newAuthority;

        emit AuthorityUpdated(msg.sender, newAuthority);
    }

    function setOwner(address newOwner) public virtual requiresAuth {
        owner = newOwner;

        emit OwnerUpdated(msg.sender, newOwner);
    }
}

/// @notice A generic interface for a contract which provides authorization data to an Auth instance.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/auth/Auth.sol)
/// @author Modified from Dappsys (https://github.com/dapphub/ds-auth/blob/master/src/auth.sol)
interface Authority {
    function canCall(
        address user,
        address target,
        bytes4 functionSig
    ) external view returns (bool);
}

// lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol

// OpenZeppelin Contracts (last updated v4.7.0) (proxy/utils/Initializable.sol)

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since proxied contracts do not make use of a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * The initialization functions use a version number. Once a version number is used, it is consumed and cannot be
 * reused. This mechanism prevents re-execution of each "step" but allows the creation of new initialization steps in
 * case an upgrade adds a module that needs to be initialized.
 *
 * For example:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * contract MyToken is ERC20Upgradeable {
 *     function initialize() initializer public {
 *         __ERC20_init("MyToken", "MTK");
 *     }
 * }
 * contract MyTokenV2 is MyToken, ERC20PermitUpgradeable {
 *     function initializeV2() reinitializer(2) public {
 *         __ERC20Permit_init("MyToken");
 *     }
 * }
 * ```
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 *
 * [CAUTION]
 * ====
 * Avoid leaving a contract uninitialized.
 *
 * An uninitialized contract can be taken over by an attacker. This applies to both a proxy and its implementation
 * contract, which may impact the proxy. To prevent the implementation contract from being used, you should invoke
 * the {_disableInitializers} function in the constructor to automatically lock it when it is deployed:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() {
 *     _disableInitializers();
 * }
 * ```
 * ====
 */
abstract contract Initializable {
    /**
     * @dev Indicates that the contract has been initialized.
     * @custom:oz-retyped-from bool
     */
    uint8 private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Triggered when the contract has been initialized or reinitialized.
     */
    event Initialized(uint8 version);

    /**
     * @dev A modifier that defines a protected initializer function that can be invoked at most once. In its scope,
     * `onlyInitializing` functions can be used to initialize parent contracts.
     *
     * Similar to `reinitializer(1)`, except that functions marked with `initializer` can be nested in the context of a
     * constructor.
     *
     * Emits an {Initialized} event.
     */
    modifier initializer() {
        bool isTopLevelCall = !_initializing;
        require(
            (isTopLevelCall && _initialized < 1) || (!AddressUpgradeable.isContract(address(this)) && _initialized == 1),
            "Initializable: contract is already initialized"
        );
        _initialized = 1;
        if (isTopLevelCall) {
            _initializing = true;
        }
        _;
        if (isTopLevelCall) {
            _initializing = false;
            emit Initialized(1);
        }
    }

    /**
     * @dev A modifier that defines a protected reinitializer function that can be invoked at most once, and only if the
     * contract hasn't been initialized to a greater version before. In its scope, `onlyInitializing` functions can be
     * used to initialize parent contracts.
     *
     * A reinitializer may be used after the original initialization step. This is essential to configure modules that
     * are added through upgrades and that require initialization.
     *
     * When `version` is 1, this modifier is similar to `initializer`, except that functions marked with `reinitializer`
     * cannot be nested. If one is invoked in the context of another, execution will revert.
     *
     * Note that versions can jump in increments greater than 1; this implies that if multiple reinitializers coexist in
     * a contract, executing them in the right order is up to the developer or operator.
     *
     * WARNING: setting the version to 255 will prevent any future reinitialization.
     *
     * Emits an {Initialized} event.
     */
    modifier reinitializer(uint8 version) {
        require(!_initializing && _initialized < version, "Initializable: contract is already initialized");
        _initialized = version;
        _initializing = true;
        _;
        _initializing = false;
        emit Initialized(version);
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} and {reinitializer} modifiers, directly or indirectly.
     */
    modifier onlyInitializing() {
        require(_initializing, "Initializable: contract is not initializing");
        _;
    }

    /**
     * @dev Locks the contract, preventing any future reinitialization. This cannot be part of an initializer call.
     * Calling this in the constructor of a contract will prevent that contract from being initialized or reinitialized
     * to any version. It is recommended to use this to lock implementation contracts that are designed to be called
     * through proxies.
     *
     * Emits an {Initialized} event the first time it is successfully executed.
     */
    function _disableInitializers() internal virtual {
        require(!_initializing, "Initializable: contract is initializing");
        if (_initialized < type(uint8).max) {
            _initialized = type(uint8).max;
            emit Initialized(type(uint8).max);
        }
    }

    /**
     * @dev Internal function that returns the initialized version. Returns `_initialized`
     */
    function _getInitializedVersion() internal view returns (uint8) {
        return _initialized;
    }

    /**
     * @dev Internal function that returns the initialized version. Returns `_initializing`
     */
    function _isInitializing() internal view returns (bool) {
        return _initializing;
    }
}

// lib/solmate/src/auth/authorities/RolesAuthority.sol

/// @notice Role based Authority that supports up to 256 roles.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/auth/authorities/RolesAuthority.sol)
/// @author Modified from Dappsys (https://github.com/dapphub/ds-roles/blob/master/src/roles.sol)
contract RolesAuthority is Auth, Authority {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event UserRoleUpdated(address indexed user, uint8 indexed role, bool enabled);

    event PublicCapabilityUpdated(address indexed target, bytes4 indexed functionSig, bool enabled);

    event RoleCapabilityUpdated(uint8 indexed role, address indexed target, bytes4 indexed functionSig, bool enabled);

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _owner, Authority _authority) Auth(_owner, _authority) {}

    /*//////////////////////////////////////////////////////////////
                            ROLE/USER STORAGE
    //////////////////////////////////////////////////////////////*/

    mapping(address => bytes32) public getUserRoles;

    mapping(address => mapping(bytes4 => bool)) public isCapabilityPublic;

    mapping(address => mapping(bytes4 => bytes32)) public getRolesWithCapability;

    function doesUserHaveRole(address user, uint8 role) public view virtual returns (bool) {
        return (uint256(getUserRoles[user]) >> role) & 1 != 0;
    }

    function doesRoleHaveCapability(
        uint8 role,
        address target,
        bytes4 functionSig
    ) public view virtual returns (bool) {
        return (uint256(getRolesWithCapability[target][functionSig]) >> role) & 1 != 0;
    }

    /*//////////////////////////////////////////////////////////////
                           AUTHORIZATION LOGIC
    //////////////////////////////////////////////////////////////*/

    function canCall(
        address user,
        address target,
        bytes4 functionSig
    ) public view virtual override returns (bool) {
        return
            isCapabilityPublic[target][functionSig] ||
            bytes32(0) != getUserRoles[user] & getRolesWithCapability[target][functionSig];
    }

    /*//////////////////////////////////////////////////////////////
                   ROLE CAPABILITY CONFIGURATION LOGIC
    //////////////////////////////////////////////////////////////*/

    function setPublicCapability(
        address target,
        bytes4 functionSig,
        bool enabled
    ) public virtual requiresAuth {
        isCapabilityPublic[target][functionSig] = enabled;

        emit PublicCapabilityUpdated(target, functionSig, enabled);
    }

    function setRoleCapability(
        uint8 role,
        address target,
        bytes4 functionSig,
        bool enabled
    ) public virtual requiresAuth {
        if (enabled) {
            getRolesWithCapability[target][functionSig] |= bytes32(1 << role);
        } else {
            getRolesWithCapability[target][functionSig] &= ~bytes32(1 << role);
        }

        emit RoleCapabilityUpdated(role, target, functionSig, enabled);
    }

    /*//////////////////////////////////////////////////////////////
                       USER ROLE ASSIGNMENT LOGIC
    //////////////////////////////////////////////////////////////*/

    function setUserRole(
        address user,
        uint8 role,
        bool enabled
    ) public virtual requiresAuth {
        if (enabled) {
            getUserRoles[user] |= bytes32(1 << role);
        } else {
            getUserRoles[user] &= ~bytes32(1 << role);
        }

        emit UserRoleUpdated(user, role, enabled);
    }
}

// lib/openzeppelin-contracts-upgradeable/contracts/utils/ContextUpgradeable.sol

// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal onlyInitializing {
    }

    function __Context_init_unchained() internal onlyInitializing {
    }
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}

// lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol

// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract OwnableUpgradeable is Initializable, ContextUpgradeable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    function __Ownable_init() internal onlyInitializing {
        __Ownable_init_unchained();
    }

    function __Ownable_init_unchained() internal onlyInitializing {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

// contracts/ionic/SafeOwnableUpgradeable.sol

/**
 * @dev Ownable extension that requires a two-step process of setting the pending owner and the owner accepting it.
 * @notice Existing OwnableUpgradeable contracts cannot be upgraded due to the extra storage variable
 * that will shift the other.
 */
abstract contract SafeOwnableUpgradeable is OwnableUpgradeable {
  /**
   * @notice Pending owner of this contract
   */
  address public pendingOwner;

  function __SafeOwnable_init(address owner_) internal onlyInitializing {
    __Ownable_init();
    _transferOwnership(owner_);
  }

  struct AddressSlot {
    address value;
  }

  modifier onlyOwnerOrAdmin() {
    bool isOwner = owner() == _msgSender();
    if (!isOwner) {
      address admin = _getProxyAdmin();
      bool isAdmin = admin == _msgSender();
      require(isAdmin, "Ownable: caller is neither the owner nor the admin");
    }
    _;
  }

  /**
   * @notice Emitted when pendingOwner is changed
   */
  event NewPendingOwner(address oldPendingOwner, address newPendingOwner);

  /**
   * @notice Emitted when pendingOwner is accepted, which means owner is updated
   */
  event NewOwner(address oldOwner, address newOwner);

  /**
   * @notice Begins transfer of owner rights. The newPendingOwner must call `_acceptOwner` to finalize the transfer.
   * @dev Owner function to begin change of owner. The newPendingOwner must call `_acceptOwner` to finalize the transfer.
   * @param newPendingOwner New pending owner.
   */
  function _setPendingOwner(address newPendingOwner) public onlyOwner {
    // Save current value, if any, for inclusion in log
    address oldPendingOwner = pendingOwner;

    // Store pendingOwner with value newPendingOwner
    pendingOwner = newPendingOwner;

    // Emit NewPendingOwner(oldPendingOwner, newPendingOwner)
    emit NewPendingOwner(oldPendingOwner, newPendingOwner);
  }

  /**
   * @notice Accepts transfer of owner rights. msg.sender must be pendingOwner
   * @dev Owner function for pending owner to accept role and update owner
   */
  function _acceptOwner() public {
    // Check caller is pendingOwner and pendingOwner ≠ address(0)
    require(msg.sender == pendingOwner, "not the pending owner");

    // Save current values for inclusion in log
    address oldOwner = owner();
    address oldPendingOwner = pendingOwner;

    // Store owner with value pendingOwner
    _transferOwnership(pendingOwner);

    // Clear the pending value
    pendingOwner = address(0);

    emit NewOwner(oldOwner, pendingOwner);
    emit NewPendingOwner(oldPendingOwner, pendingOwner);
  }

  function renounceOwnership() public override onlyOwner {
    // do not remove this overriding fn
    revert("not used anymore");
  }

  function transferOwnership(address newOwner) public override onlyOwner {
    emit NewPendingOwner(pendingOwner, newOwner);
    pendingOwner = newOwner;
  }

  function _getProxyAdmin() internal view returns (address admin) {
    bytes32 _ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
    AddressSlot storage adminSlot;
    assembly {
      adminSlot.slot := _ADMIN_SLOT
    }
    admin = adminSlot.value;
  }
}

// lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Upgrade.sol

// OpenZeppelin Contracts (last updated v4.5.0) (proxy/ERC1967/ERC1967Upgrade.sol)

/**
 * @dev This abstract contract provides getters and event emitting update functions for
 * https://eips.ethereum.org/EIPS/eip-1967[EIP1967] slots.
 *
 * _Available since v4.1._
 *
 * @custom:oz-upgrades-unsafe-allow delegatecall
 */
abstract contract ERC1967Upgrade {
    // This is the keccak-256 hash of "eip1967.proxy.rollback" subtracted by 1
    bytes32 private constant _ROLLBACK_SLOT = 0x4910fdfa16fed3260ed0e7147f7cc6da11a60208b5b9406d12a635614ffd9143;

    /**
     * @dev Storage slot with the address of the current implementation.
     * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1, and is
     * validated in the constructor.
     */
    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /**
     * @dev Emitted when the implementation is upgraded.
     */
    event Upgraded(address indexed implementation);

    /**
     * @dev Returns the current implementation address.
     */
    function _getImplementation() internal view returns (address) {
        return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 implementation slot.
     */
    function _setImplementation(address newImplementation) private {
        require(Address.isContract(newImplementation), "ERC1967: new implementation is not a contract");
        StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
    }

    /**
     * @dev Perform implementation upgrade
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeTo(address newImplementation) internal {
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);
    }

    /**
     * @dev Perform implementation upgrade with additional setup call.
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeToAndCall(
        address newImplementation,
        bytes memory data,
        bool forceCall
    ) internal {
        _upgradeTo(newImplementation);
        if (data.length > 0 || forceCall) {
            Address.functionDelegateCall(newImplementation, data);
        }
    }

    /**
     * @dev Perform implementation upgrade with security checks for UUPS proxies, and additional setup call.
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeToAndCallUUPS(
        address newImplementation,
        bytes memory data,
        bool forceCall
    ) internal {
        // Upgrades from old implementations will perform a rollback test. This test requires the new
        // implementation to upgrade back to the old, non-ERC1822 compliant, implementation. Removing
        // this special case will break upgrade paths from old UUPS implementation to new ones.
        if (StorageSlot.getBooleanSlot(_ROLLBACK_SLOT).value) {
            _setImplementation(newImplementation);
        } else {
            try IERC1822Proxiable(newImplementation).proxiableUUID() returns (bytes32 slot) {
                require(slot == _IMPLEMENTATION_SLOT, "ERC1967Upgrade: unsupported proxiableUUID");
            } catch {
                revert("ERC1967Upgrade: new implementation is not UUPS");
            }
            _upgradeToAndCall(newImplementation, data, forceCall);
        }
    }

    /**
     * @dev Storage slot with the admin of the contract.
     * This is the keccak-256 hash of "eip1967.proxy.admin" subtracted by 1, and is
     * validated in the constructor.
     */
    bytes32 internal constant _ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    /**
     * @dev Emitted when the admin account has changed.
     */
    event AdminChanged(address previousAdmin, address newAdmin);

    /**
     * @dev Returns the current admin.
     */
    function _getAdmin() internal view returns (address) {
        return StorageSlot.getAddressSlot(_ADMIN_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 admin slot.
     */
    function _setAdmin(address newAdmin) private {
        require(newAdmin != address(0), "ERC1967: new admin is the zero address");
        StorageSlot.getAddressSlot(_ADMIN_SLOT).value = newAdmin;
    }

    /**
     * @dev Changes the admin of the proxy.
     *
     * Emits an {AdminChanged} event.
     */
    function _changeAdmin(address newAdmin) internal {
        emit AdminChanged(_getAdmin(), newAdmin);
        _setAdmin(newAdmin);
    }

    /**
     * @dev The storage slot of the UpgradeableBeacon contract which defines the implementation for this proxy.
     * This is bytes32(uint256(keccak256('eip1967.proxy.beacon')) - 1)) and is validated in the constructor.
     */
    bytes32 internal constant _BEACON_SLOT = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;

    /**
     * @dev Emitted when the beacon is upgraded.
     */
    event BeaconUpgraded(address indexed beacon);

    /**
     * @dev Returns the current beacon.
     */
    function _getBeacon() internal view returns (address) {
        return StorageSlot.getAddressSlot(_BEACON_SLOT).value;
    }

    /**
     * @dev Stores a new beacon in the EIP1967 beacon slot.
     */
    function _setBeacon(address newBeacon) private {
        require(Address.isContract(newBeacon), "ERC1967: new beacon is not a contract");
        require(
            Address.isContract(IBeacon(newBeacon).implementation()),
            "ERC1967: beacon implementation is not a contract"
        );
        StorageSlot.getAddressSlot(_BEACON_SLOT).value = newBeacon;
    }

    /**
     * @dev Perform beacon upgrade with additional setup call. Note: This upgrades the address of the beacon, it does
     * not upgrade the implementation contained in the beacon (see {UpgradeableBeacon-_setImplementation} for that).
     *
     * Emits a {BeaconUpgraded} event.
     */
    function _upgradeBeaconToAndCall(
        address newBeacon,
        bytes memory data,
        bool forceCall
    ) internal {
        _setBeacon(newBeacon);
        emit BeaconUpgraded(newBeacon);
        if (data.length > 0 || forceCall) {
            Address.functionDelegateCall(IBeacon(newBeacon).implementation(), data);
        }
    }
}

// contracts/ionic/AddressesProvider.sol

/**
 * @title AddressesProvider
 * @notice The Addresses Provider serves as a central storage of system internal and external
 *         contract addresses that change between deploys and across chains
 * @author Veliko Minkov <veliko@midascapital.xyz>
 */
contract AddressesProvider is SafeOwnableUpgradeable {
  mapping(string => address) private _addresses;
  mapping(address => Contract) public plugins;
  mapping(address => Contract) public flywheelRewards;
  mapping(address => RedemptionStrategy) public redemptionStrategiesConfig;
  mapping(address => FundingStrategy) public fundingStrategiesConfig;
  JarvisPool[] public jarvisPoolsConfig;
  CurveSwapPool[] public curveSwapPoolsConfig;
  mapping(address => mapping(address => address)) public balancerPoolForTokens;

  /// @dev Initializer to set the admin that can set and change contracts addresses
  function initialize(address owner) public initializer {
    __SafeOwnable_init(owner);
  }

  /**
   * @dev The contract address and a string that uniquely identifies the contract's interface
   */
  struct Contract {
    address addr;
    string contractInterface;
  }

  struct RedemptionStrategy {
    address addr;
    string contractInterface;
    address outputToken;
  }

  struct FundingStrategy {
    address addr;
    string contractInterface;
    address inputToken;
  }

  struct JarvisPool {
    address syntheticToken;
    address collateralToken;
    address liquidityPool;
    uint256 expirationTime;
  }

  struct CurveSwapPool {
    address poolAddress;
    address[] coins;
  }

  /**
   * @dev sets the address and contract interface ID of the flywheel for the reward token
   * @param rewardToken the reward token address
   * @param flywheelRewardsModule the flywheel rewards module address
   * @param contractInterface a string that uniquely identifies the contract's interface
   */
  function setFlywheelRewards(
    address rewardToken,
    address flywheelRewardsModule,
    string calldata contractInterface
  ) public onlyOwner {
    flywheelRewards[rewardToken] = Contract(flywheelRewardsModule, contractInterface);
  }

  /**
   * @dev sets the address and contract interface ID of the ERC4626 plugin for the asset
   * @param asset the asset address
   * @param plugin the ERC4626 plugin address
   * @param contractInterface a string that uniquely identifies the contract's interface
   */
  function setPlugin(
    address asset,
    address plugin,
    string calldata contractInterface
  ) public onlyOwner {
    plugins[asset] = Contract(plugin, contractInterface);
  }

  /**
   * @dev sets the address and contract interface ID of the redemption strategy for the asset
   * @param asset the asset address
   * @param strategy redemption strategy address
   * @param contractInterface a string that uniquely identifies the contract's interface
   */
  function setRedemptionStrategy(
    address asset,
    address strategy,
    string calldata contractInterface,
    address outputToken
  ) public onlyOwner {
    redemptionStrategiesConfig[asset] = RedemptionStrategy(strategy, contractInterface, outputToken);
  }

  function getRedemptionStrategy(address asset) public view returns (RedemptionStrategy memory) {
    return redemptionStrategiesConfig[asset];
  }

  /**
   * @dev sets the address and contract interface ID of the funding strategy for the asset
   * @param asset the asset address
   * @param strategy funding strategy address
   * @param contractInterface a string that uniquely identifies the contract's interface
   */
  function setFundingStrategy(
    address asset,
    address strategy,
    string calldata contractInterface,
    address inputToken
  ) public onlyOwner {
    fundingStrategiesConfig[asset] = FundingStrategy(strategy, contractInterface, inputToken);
  }

  function getFundingStrategy(address asset) public view returns (FundingStrategy memory) {
    return fundingStrategiesConfig[asset];
  }

  /**
   * @dev configures the Jarvis pool of a Jarvis synthetic token
   * @param syntheticToken the synthetic token address
   * @param collateralToken the collateral token address
   * @param liquidityPool the liquidity pool address
   * @param expirationTime the operation expiration time
   */
  function setJarvisPool(
    address syntheticToken,
    address collateralToken,
    address liquidityPool,
    uint256 expirationTime
  ) public onlyOwner {
    jarvisPoolsConfig.push(JarvisPool(syntheticToken, collateralToken, liquidityPool, expirationTime));
  }

  function setCurveSwapPool(address poolAddress, address[] calldata coins) public onlyOwner {
    curveSwapPoolsConfig.push(CurveSwapPool(poolAddress, coins));
  }

  /**
   * @dev Sets an address for an id replacing the address saved in the addresses map
   * @param id The id
   * @param newAddress The address to set
   */
  function setAddress(string calldata id, address newAddress) external onlyOwner {
    _addresses[id] = newAddress;
  }

  /**
   * @dev Returns an address by id
   * @return The address
   */
  function getAddress(string calldata id) public view returns (address) {
    return _addresses[id];
  }

  function getCurveSwapPools() public view returns (CurveSwapPool[] memory) {
    return curveSwapPoolsConfig;
  }

  function getJarvisPools() public view returns (JarvisPool[] memory) {
    return jarvisPoolsConfig;
  }

  function setBalancerPoolForTokens(
    address inputToken,
    address outputToken,
    address pool
  ) external onlyOwner {
    balancerPoolForTokens[inputToken][outputToken] = pool;
  }

  function getBalancerPoolForTokens(address inputToken, address outputToken) external view returns (address) {
    return balancerPoolForTokens[inputToken][outputToken];
  }
}

// lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol

// OpenZeppelin Contracts (last updated v4.7.0) (proxy/ERC1967/ERC1967Proxy.sol)

/**
 * @dev This contract implements an upgradeable proxy. It is upgradeable because calls are delegated to an
 * implementation address that can be changed. This address is stored in storage in the location specified by
 * https://eips.ethereum.org/EIPS/eip-1967[EIP1967], so that it doesn't conflict with the storage layout of the
 * implementation behind the proxy.
 */
contract ERC1967Proxy is Proxy, ERC1967Upgrade {
    /**
     * @dev Initializes the upgradeable proxy with an initial implementation specified by `_logic`.
     *
     * If `_data` is nonempty, it's used as data in a delegate call to `_logic`. This will typically be an encoded
     * function call, and allows initializing the storage of the proxy like a Solidity constructor.
     */
    constructor(address _logic, bytes memory _data) payable {
        _upgradeToAndCall(_logic, _data, false);
    }

    /**
     * @dev Returns the current implementation address.
     */
    function _implementation() internal view virtual override returns (address impl) {
        return ERC1967Upgrade._getImplementation();
    }
}

// lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol

// OpenZeppelin Contracts (last updated v4.7.0) (proxy/transparent/TransparentUpgradeableProxy.sol)

/**
 * @dev This contract implements a proxy that is upgradeable by an admin.
 *
 * To avoid https://medium.com/nomic-labs-blog/malicious-backdoors-in-ethereum-proxies-62629adf3357[proxy selector
 * clashing], which can potentially be used in an attack, this contract uses the
 * https://blog.openzeppelin.com/the-transparent-proxy-pattern/[transparent proxy pattern]. This pattern implies two
 * things that go hand in hand:
 *
 * 1. If any account other than the admin calls the proxy, the call will be forwarded to the implementation, even if
 * that call matches one of the admin functions exposed by the proxy itself.
 * 2. If the admin calls the proxy, it can access the admin functions, but its calls will never be forwarded to the
 * implementation. If the admin tries to call a function on the implementation it will fail with an error that says
 * "admin cannot fallback to proxy target".
 *
 * These properties mean that the admin account can only be used for admin actions like upgrading the proxy or changing
 * the admin, so it's best if it's a dedicated account that is not used for anything else. This will avoid headaches due
 * to sudden errors when trying to call a function from the proxy implementation.
 *
 * Our recommendation is for the dedicated account to be an instance of the {ProxyAdmin} contract. If set up this way,
 * you should think of the `ProxyAdmin` instance as the real administrative interface of your proxy.
 */
contract TransparentUpgradeableProxy is ERC1967Proxy {
    /**
     * @dev Initializes an upgradeable proxy managed by `_admin`, backed by the implementation at `_logic`, and
     * optionally initialized with `_data` as explained in {ERC1967Proxy-constructor}.
     */
    constructor(
        address _logic,
        address admin_,
        bytes memory _data
    ) payable ERC1967Proxy(_logic, _data) {
        _changeAdmin(admin_);
    }

    /**
     * @dev Modifier used internally that will delegate the call to the implementation unless the sender is the admin.
     */
    modifier ifAdmin() {
        if (msg.sender == _getAdmin()) {
            _;
        } else {
            _fallback();
        }
    }

    /**
     * @dev Returns the current admin.
     *
     * NOTE: Only the admin can call this function. See {ProxyAdmin-getProxyAdmin}.
     *
     * TIP: To get this value clients can read directly from the storage slot shown below (specified by EIP1967) using the
     * https://eth.wiki/json-rpc/API#eth_getstorageat[`eth_getStorageAt`] RPC call.
     * `0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103`
     */
    function admin() external ifAdmin returns (address admin_) {
        admin_ = _getAdmin();
    }

    /**
     * @dev Returns the current implementation.
     *
     * NOTE: Only the admin can call this function. See {ProxyAdmin-getProxyImplementation}.
     *
     * TIP: To get this value clients can read directly from the storage slot shown below (specified by EIP1967) using the
     * https://eth.wiki/json-rpc/API#eth_getstorageat[`eth_getStorageAt`] RPC call.
     * `0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc`
     */
    function implementation() external ifAdmin returns (address implementation_) {
        implementation_ = _implementation();
    }

    /**
     * @dev Changes the admin of the proxy.
     *
     * Emits an {AdminChanged} event.
     *
     * NOTE: Only the admin can call this function. See {ProxyAdmin-changeProxyAdmin}.
     */
    function changeAdmin(address newAdmin) external virtual ifAdmin {
        _changeAdmin(newAdmin);
    }

    /**
     * @dev Upgrade the implementation of the proxy.
     *
     * NOTE: Only the admin can call this function. See {ProxyAdmin-upgrade}.
     */
    function upgradeTo(address newImplementation) external ifAdmin {
        _upgradeToAndCall(newImplementation, bytes(""), false);
    }

    /**
     * @dev Upgrade the implementation of the proxy, and then call a function from the new implementation as specified
     * by `data`, which should be an encoded function call. This is useful to initialize new storage variables in the
     * proxied contract.
     *
     * NOTE: Only the admin can call this function. See {ProxyAdmin-upgradeAndCall}.
     */
    function upgradeToAndCall(address newImplementation, bytes calldata data) external payable ifAdmin {
        _upgradeToAndCall(newImplementation, data, true);
    }

    /**
     * @dev Returns the current admin.
     */
    function _admin() internal view virtual returns (address) {
        return _getAdmin();
    }

    /**
     * @dev Makes sure the admin cannot access the fallback function. See {Proxy-_beforeFallback}.
     */
    function _beforeFallback() internal virtual override {
        require(msg.sender != _getAdmin(), "TransparentUpgradeableProxy: admin cannot fallback to proxy target");
        super._beforeFallback();
    }
}

// contracts/compound/CTokenInterfaces.sol

abstract contract CTokenAdminStorage {
  /*
   * Administrator for Ionic
   */
  address payable public ionicAdmin;
}

abstract contract CErc20Storage is CTokenAdminStorage {
  /**
   * @dev Guard variable for re-entrancy checks
   */
  bool internal _notEntered;

  /**
   * @notice EIP-20 token name for this token
   */
  string public name;

  /**
   * @notice EIP-20 token symbol for this token
   */
  string public symbol;

  /**
   * @notice EIP-20 token decimals for this token
   */
  uint8 public decimals;

  /*
   * Maximum borrow rate that can ever be applied (.0005% / block)
   */
  uint256 internal constant borrowRateMaxMantissa = 0.0005e16;

  /*
   * Maximum fraction of interest that can be set aside for reserves + fees
   */
  uint256 internal constant reserveFactorPlusFeesMaxMantissa = 1e18;

  /**
   * @notice Contract which oversees inter-cToken operations
   */
  IonicComptroller public comptroller;

  /**
   * @notice Model which tells what the current interest rate should be
   */
  InterestRateModel public interestRateModel;

  /*
   * Initial exchange rate used when minting the first CTokens (used when totalSupply = 0)
   */
  uint256 internal initialExchangeRateMantissa;

  /**
   * @notice Fraction of interest currently set aside for admin fees
   */
  uint256 public adminFeeMantissa;

  /**
   * @notice Fraction of interest currently set aside for Ionic fees
   */
  uint256 public ionicFeeMantissa;

  /**
   * @notice Fraction of interest currently set aside for reserves
   */
  uint256 public reserveFactorMantissa;

  /**
   * @notice Block number that interest was last accrued at
   */
  uint256 public accrualBlockNumber;

  /**
   * @notice Accumulator of the total earned interest rate since the opening of the market
   */
  uint256 public borrowIndex;

  /**
   * @notice Total amount of outstanding borrows of the underlying in this market
   */
  uint256 public totalBorrows;

  /**
   * @notice Total amount of reserves of the underlying held in this market
   */
  uint256 public totalReserves;

  /**
   * @notice Total amount of admin fees of the underlying held in this market
   */
  uint256 public totalAdminFees;

  /**
   * @notice Total amount of Ionic fees of the underlying held in this market
   */
  uint256 public totalIonicFees;

  /**
   * @notice Total number of tokens in circulation
   */
  uint256 public totalSupply;

  /*
   * Official record of token balances for each account
   */
  mapping(address => uint256) internal accountTokens;

  /*
   * Approved token transfer amounts on behalf of others
   */
  mapping(address => mapping(address => uint256)) internal transferAllowances;

  /**
   * @notice Container for borrow balance information
   * @member principal Total balance (with accrued interest), after applying the most recent balance-changing action
   * @member interestIndex Global borrowIndex as of the most recent balance-changing action
   */
  struct BorrowSnapshot {
    uint256 principal;
    uint256 interestIndex;
  }

  /*
   * Mapping of account addresses to outstanding borrow balances
   */
  mapping(address => BorrowSnapshot) internal accountBorrows;

  /*
   * Share of seized collateral that is added to reserves
   */
  uint256 public constant protocolSeizeShareMantissa = 2.8e16; //2.8%

  /*
   * Share of seized collateral taken as fees
   */
  uint256 public constant feeSeizeShareMantissa = 1e17; //10%

  /**
   * @notice Underlying asset for this CToken
   */
  address public underlying;

  /**
   * @notice Addresses Provider
   */
  AddressesProvider public ap;
}

abstract contract CTokenBaseEvents {
  /* ERC20 */

  /**
   * @notice EIP20 Transfer event
   */
  event Transfer(address indexed from, address indexed to, uint256 amount);

  /*** Admin Events ***/

  /**
   * @notice Event emitted when interestRateModel is changed
   */
  event NewMarketInterestRateModel(InterestRateModel oldInterestRateModel, InterestRateModel newInterestRateModel);

  /**
   * @notice Event emitted when the reserve factor is changed
   */
  event NewReserveFactor(uint256 oldReserveFactorMantissa, uint256 newReserveFactorMantissa);

  /**
   * @notice Event emitted when the admin fee is changed
   */
  event NewAdminFee(uint256 oldAdminFeeMantissa, uint256 newAdminFeeMantissa);

  /**
   * @notice Event emitted when the Ionic fee is changed
   */
  event NewIonicFee(uint256 oldIonicFeeMantissa, uint256 newIonicFeeMantissa);

  /**
   * @notice EIP20 Approval event
   */
  event Approval(address indexed owner, address indexed spender, uint256 amount);

  /**
   * @notice Event emitted when interest is accrued
   */
  event AccrueInterest(uint256 cashPrior, uint256 interestAccumulated, uint256 borrowIndex, uint256 totalBorrows);
}

abstract contract CTokenFirstExtensionEvents is CTokenBaseEvents {
  event Flash(address receiver, uint256 amount);
}

abstract contract CTokenSecondExtensionEvents is CTokenBaseEvents {
  /*** Market Events ***/

  /**
   * @notice Event emitted when tokens are minted
   */
  event Mint(address minter, uint256 mintAmount, uint256 mintTokens);

  /**
   * @notice Event emitted when tokens are redeemed
   */
  event Redeem(address redeemer, uint256 redeemAmount, uint256 redeemTokens);

  /**
   * @notice Event emitted when underlying is borrowed
   */
  event Borrow(address borrower, uint256 borrowAmount, uint256 accountBorrows, uint256 totalBorrows);

  /**
   * @notice Event emitted when a borrow is repaid
   */
  event RepayBorrow(address payer, address borrower, uint256 repayAmount, uint256 accountBorrows, uint256 totalBorrows);

  /**
   * @notice Event emitted when a borrow is liquidated
   */
  event LiquidateBorrow(
    address liquidator,
    address borrower,
    uint256 repayAmount,
    address cTokenCollateral,
    uint256 seizeTokens
  );

  /**
   * @notice Event emitted when the reserves are added
   */
  event ReservesAdded(address benefactor, uint256 addAmount, uint256 newTotalReserves);

  /**
   * @notice Event emitted when the reserves are reduced
   */
  event ReservesReduced(address admin, uint256 reduceAmount, uint256 newTotalReserves);
}

interface CTokenFirstExtensionInterface {
  /*** User Interface ***/

  function transfer(address dst, uint256 amount) external returns (bool);

  function transferFrom(
    address src,
    address dst,
    uint256 amount
  ) external returns (bool);

  function approve(address spender, uint256 amount) external returns (bool);

  function allowance(address owner, address spender) external view returns (uint256);

  function balanceOf(address owner) external view returns (uint256);

  /*** Admin Functions ***/

  function _setReserveFactor(uint256 newReserveFactorMantissa) external returns (uint256);

  function _setAdminFee(uint256 newAdminFeeMantissa) external returns (uint256);

  function _setInterestRateModel(InterestRateModel newInterestRateModel) external returns (uint256);

  function getAccountSnapshot(address account)
    external
    view
    returns (
      uint256,
      uint256,
      uint256,
      uint256
    );

  function borrowRatePerBlock() external view returns (uint256);

  function supplyRatePerBlock() external view returns (uint256);

  function exchangeRateCurrent() external view returns (uint256);

  function accrueInterest() external returns (uint256);

  function totalBorrowsCurrent() external view returns (uint256);

  function borrowBalanceCurrent(address account) external view returns (uint256);

  function getTotalUnderlyingSupplied() external view returns (uint256);

  function balanceOfUnderlying(address owner) external view returns (uint256);

  function multicall(bytes[] calldata data) external payable returns (bytes[] memory results);

  function flash(uint256 amount, bytes calldata data) external;

  function supplyRatePerBlockAfterDeposit(uint256 mintAmount) external view returns (uint256);

  function supplyRatePerBlockAfterWithdraw(uint256 withdrawAmount) external view returns (uint256);

  function borrowRatePerBlockAfterBorrow(uint256 borrowAmount) external view returns (uint256);

  function registerInSFS() external returns (uint256);
}

interface CTokenSecondExtensionInterface {
  function mint(uint256 mintAmount) external returns (uint256);

  function redeem(uint256 redeemTokens) external returns (uint256);

  function redeemUnderlying(uint256 redeemAmount) external returns (uint256);

  function borrow(uint256 borrowAmount) external returns (uint256);

  function repayBorrow(uint256 repayAmount) external returns (uint256);

  function repayBorrowBehalf(address borrower, uint256 repayAmount) external returns (uint256);

  function liquidateBorrow(
    address borrower,
    uint256 repayAmount,
    address cTokenCollateral
  ) external returns (uint256);

  function getCash() external view returns (uint256);

  function seize(
    address liquidator,
    address borrower,
    uint256 seizeTokens
  ) external returns (uint256);

  /*** Admin Functions ***/

  function _withdrawAdminFees(uint256 withdrawAmount) external returns (uint256);

  function _withdrawIonicFees(uint256 withdrawAmount) external returns (uint256);

  function selfTransferOut(address to, uint256 amount) external;

  function selfTransferIn(address from, uint256 amount) external returns (uint256);
}

interface CDelegatorInterface {
  function implementation() external view returns (address);

  /**
   * @notice Called by the admin to update the implementation of the delegator
   * @param implementation_ The address of the new implementation for delegation
   * @param becomeImplementationData The encoded bytes data to be passed to _becomeImplementation
   */
  function _setImplementationSafe(address implementation_, bytes calldata becomeImplementationData) external;

  /**
   * @dev upgrades the implementation if necessary
   */
  function _upgrade() external;
}

interface CDelegateInterface {
  /**
   * @notice Called by the delegator on a delegate to initialize it for duty
   * @dev Should revert if any issues arise which make it unfit for delegation
   * @param data The encoded bytes data for any initialization
   */
  function _becomeImplementation(bytes calldata data) external;

  function delegateType() external pure returns (uint8);

  function contractType() external pure returns (string memory);
}

abstract contract CErc20AdminBase is CErc20Storage {
  /**
   * @notice Returns a boolean indicating if the sender has admin rights
   */
  function hasAdminRights() internal view returns (bool) {
    ComptrollerV3Storage comptrollerStorage = ComptrollerV3Storage(address(comptroller));
    return
      (msg.sender == comptrollerStorage.admin() && comptrollerStorage.adminHasRights()) ||
      (msg.sender == address(ionicAdmin) && comptrollerStorage.ionicAdminHasRights());
  }
}

abstract contract CErc20FirstExtensionBase is
  CErc20AdminBase,
  CTokenFirstExtensionEvents,
  CTokenFirstExtensionInterface
{}

abstract contract CTokenSecondExtensionBase is
  CErc20AdminBase,
  CTokenSecondExtensionEvents,
  CTokenSecondExtensionInterface,
  CDelegateInterface
{}

abstract contract CErc20DelegatorBase is CErc20AdminBase, CTokenSecondExtensionEvents, CDelegatorInterface {}

interface CErc20StorageInterface {
  function admin() external view returns (address);

  function adminHasRights() external view returns (bool);

  function ionicAdmin() external view returns (address);

  function ionicAdminHasRights() external view returns (bool);

  function comptroller() external view returns (IonicComptroller);

  function name() external view returns (string memory);

  function symbol() external view returns (string memory);

  function decimals() external view returns (uint8);

  function totalSupply() external view returns (uint256);

  function adminFeeMantissa() external view returns (uint256);

  function ionicFeeMantissa() external view returns (uint256);

  function reserveFactorMantissa() external view returns (uint256);

  function protocolSeizeShareMantissa() external view returns (uint256);

  function feeSeizeShareMantissa() external view returns (uint256);

  function totalReserves() external view returns (uint256);

  function totalAdminFees() external view returns (uint256);

  function totalIonicFees() external view returns (uint256);

  function totalBorrows() external view returns (uint256);

  function accrualBlockNumber() external view returns (uint256);

  function underlying() external view returns (address);

  function borrowIndex() external view returns (uint256);

  function interestRateModel() external view returns (address);
}

interface CErc20PluginStorageInterface is CErc20StorageInterface {
  function plugin() external view returns (address);
}

interface CErc20PluginRewardsInterface is CErc20PluginStorageInterface {
  function approve(address, address) external;
}

interface ICErc20 is
  CErc20StorageInterface,
  CTokenSecondExtensionInterface,
  CTokenFirstExtensionInterface,
  CDelegatorInterface,
  CDelegateInterface
{}

interface ICErc20Plugin is CErc20PluginStorageInterface, ICErc20 {
  function _updatePlugin(address _plugin) external;
}

interface ICErc20PluginRewards is CErc20PluginRewardsInterface, ICErc20 {}

// contracts/compound/ComptrollerInterface.sol

interface ComptrollerInterface {
  function isDeprecated(ICErc20 cToken) external view returns (bool);

  function _becomeImplementation() external;

  function _deployMarket(
    uint8 delegateType,
    bytes memory constructorData,
    bytes calldata becomeImplData,
    uint256 collateralFactorMantissa
  ) external returns (uint256);

  function getAssetsIn(address account) external view returns (ICErc20[] memory);

  function checkMembership(address account, ICErc20 cToken) external view returns (bool);

  function _setPriceOracle(BasePriceOracle newOracle) external returns (uint256);

  function _setCloseFactor(uint256 newCloseFactorMantissa) external returns (uint256);

  function _setCollateralFactor(ICErc20 market, uint256 newCollateralFactorMantissa) external returns (uint256);

  function _setLiquidationIncentive(uint256 newLiquidationIncentiveMantissa) external returns (uint256);

  function _setWhitelistEnforcement(bool enforce) external returns (uint256);

  function _setWhitelistStatuses(address[] calldata _suppliers, bool[] calldata statuses) external returns (uint256);

  function _addRewardsDistributor(address distributor) external returns (uint256);

  function getHypotheticalAccountLiquidity(
    address account,
    address cTokenModify,
    uint256 redeemTokens,
    uint256 borrowAmount,
    uint256 repayAmount
  )
    external
    view
    returns (
      uint256,
      uint256,
      uint256,
      uint256
    );

  function getMaxRedeemOrBorrow(
    address account,
    ICErc20 cToken,
    bool isBorrow
  ) external view returns (uint256);

  /*** Assets You Are In ***/

  function enterMarkets(address[] calldata cTokens) external returns (uint256[] memory);

  function exitMarket(address cToken) external returns (uint256);

  /*** Policy Hooks ***/

  function mintAllowed(
    address cToken,
    address minter,
    uint256 mintAmount
  ) external returns (uint256);

  function redeemAllowed(
    address cToken,
    address redeemer,
    uint256 redeemTokens
  ) external returns (uint256);

  function redeemVerify(
    address cToken,
    address redeemer,
    uint256 redeemAmount,
    uint256 redeemTokens
  ) external;

  function borrowAllowed(
    address cToken,
    address borrower,
    uint256 borrowAmount
  ) external returns (uint256);

  function borrowWithinLimits(address cToken, uint256 accountBorrowsNew) external view returns (uint256);

  function repayBorrowAllowed(
    address cToken,
    address payer,
    address borrower,
    uint256 repayAmount
  ) external returns (uint256);

  function liquidateBorrowAllowed(
    address cTokenBorrowed,
    address cTokenCollateral,
    address liquidator,
    address borrower,
    uint256 repayAmount
  ) external returns (uint256);

  function seizeAllowed(
    address cTokenCollateral,
    address cTokenBorrowed,
    address liquidator,
    address borrower,
    uint256 seizeTokens
  ) external returns (uint256);

  function transferAllowed(
    address cToken,
    address src,
    address dst,
    uint256 transferTokens
  ) external returns (uint256);

  function mintVerify(
    address cToken,
    address minter,
    uint256 actualMintAmount,
    uint256 mintTokens
  ) external;

  /*** Liquidity/Liquidation Calculations ***/

  function getAccountLiquidity(address account)
    external
    view
    returns (
      uint256 error,
      uint256 collateralValue,
      uint256 liquidity,
      uint256 shortfall
    );

  function liquidateCalculateSeizeTokens(
    address cTokenBorrowed,
    address cTokenCollateral,
    uint256 repayAmount
  ) external view returns (uint256, uint256);

  /*** Pool-Wide/Cross-Asset Reentrancy Prevention ***/

  function _beforeNonReentrant() external;

  function _afterNonReentrant() external;
}

interface ComptrollerStorageInterface {
  function admin() external view returns (address);

  function adminHasRights() external view returns (bool);

  function ionicAdmin() external view returns (address);

  function ionicAdminHasRights() external view returns (bool);

  function pendingAdmin() external view returns (address);

  function oracle() external view returns (BasePriceOracle);

  function pauseGuardian() external view returns (address);

  function closeFactorMantissa() external view returns (uint256);

  function liquidationIncentiveMantissa() external view returns (uint256);

  function isUserOfPool(address user) external view returns (bool);

  function whitelist(address account) external view returns (bool);

  function enforceWhitelist() external view returns (bool);

  function borrowCapForCollateral(address borrowed, address collateral) external view returns (uint256);

  function borrowingAgainstCollateralBlacklist(address borrowed, address collateral) external view returns (bool);

  function suppliers(address account) external view returns (bool);

  function cTokensByUnderlying(address) external view returns (address);

  function supplyCaps(address cToken) external view returns (uint256);

  function borrowCaps(address cToken) external view returns (uint256);

  function markets(address cToken) external view returns (bool, uint256);

  function accountAssets(address, uint256) external view returns (address);

  function borrowGuardianPaused(address cToken) external view returns (bool);

  function mintGuardianPaused(address cToken) external view returns (bool);

  function rewardsDistributors(uint256) external view returns (address);
}

interface SFSRegister {
  function register(address _recipient) external returns (uint256 tokenId);
}

interface ComptrollerExtensionInterface {
  function getWhitelistedSuppliersSupply(address cToken) external view returns (uint256 supplied);

  function getWhitelistedBorrowersBorrows(address cToken) external view returns (uint256 borrowed);

  function getAllMarkets() external view returns (ICErc20[] memory);

  function getAllBorrowers() external view returns (address[] memory);

  function getAllBorrowersCount() external view returns (uint256);

  function getPaginatedBorrowers(uint256 page, uint256 pageSize)
    external
    view
    returns (uint256 _totalPages, address[] memory _pageOfBorrowers);

  function getRewardsDistributors() external view returns (address[] memory);

  function getAccruingFlywheels() external view returns (address[] memory);

  function _supplyCapWhitelist(
    address cToken,
    address account,
    bool whitelisted
  ) external;

  function _setBorrowCapForCollateral(
    address cTokenBorrow,
    address cTokenCollateral,
    uint256 borrowCap
  ) external;

  function _setBorrowCapForCollateralWhitelist(
    address cTokenBorrow,
    address cTokenCollateral,
    address account,
    bool whitelisted
  ) external;

  function isBorrowCapForCollateralWhitelisted(
    address cTokenBorrow,
    address cTokenCollateral,
    address account
  ) external view returns (bool);

  function _blacklistBorrowingAgainstCollateral(
    address cTokenBorrow,
    address cTokenCollateral,
    bool blacklisted
  ) external;

  function _blacklistBorrowingAgainstCollateralWhitelist(
    address cTokenBorrow,
    address cTokenCollateral,
    address account,
    bool whitelisted
  ) external;

  function isBlacklistBorrowingAgainstCollateralWhitelisted(
    address cTokenBorrow,
    address cTokenCollateral,
    address account
  ) external view returns (bool);

  function isSupplyCapWhitelisted(address cToken, address account) external view returns (bool);

  function _borrowCapWhitelist(
    address cToken,
    address account,
    bool whitelisted
  ) external;

  function isBorrowCapWhitelisted(address cToken, address account) external view returns (bool);

  function _removeFlywheel(address flywheelAddress) external returns (bool);

  function getWhitelist() external view returns (address[] memory);

  function addNonAccruingFlywheel(address flywheelAddress) external returns (bool);

  function _setMarketSupplyCaps(ICErc20[] calldata cTokens, uint256[] calldata newSupplyCaps) external;

  function _setMarketBorrowCaps(ICErc20[] calldata cTokens, uint256[] calldata newBorrowCaps) external;

  function _setBorrowCapGuardian(address newBorrowCapGuardian) external;

  function _setPauseGuardian(address newPauseGuardian) external returns (uint256);

  function _setMintPaused(ICErc20 cToken, bool state) external returns (bool);

  function _setBorrowPaused(ICErc20 cToken, bool state) external returns (bool);

  function _setTransferPaused(bool state) external returns (bool);

  function _setSeizePaused(bool state) external returns (bool);

  function _unsupportMarket(ICErc20 cToken) external returns (uint256);

  function getAssetAsCollateralValueCap(
    ICErc20 collateral,
    ICErc20 cTokenModify,
    bool redeeming,
    address account
  ) external view returns (uint256);

  function registerInSFS() external returns (uint256);
}

interface UnitrollerInterface {
  function comptrollerImplementation() external view returns (address);

  function _upgrade() external;

  function _acceptAdmin() external returns (uint256);

  function _setPendingAdmin(address newPendingAdmin) external returns (uint256);

  function _toggleAdminRights(bool hasRights) external returns (uint256);
}

interface IComptrollerExtension is ComptrollerExtensionInterface, ComptrollerStorageInterface {}

//interface IComptrollerBase is ComptrollerInterface, ComptrollerStorageInterface {}

interface IonicComptroller is
  ComptrollerInterface,
  ComptrollerExtensionInterface,
  UnitrollerInterface,
  ComptrollerStorageInterface
{

}

contract UnitrollerAdminStorage {
  /*
   * Administrator for Ionic
   */
  address payable public ionicAdmin;

  /**
   * @notice Administrator for this contract
   */
  address public admin;

  /**
   * @notice Pending administrator for this contract
   */
  address public pendingAdmin;

  /**
   * @notice Whether or not the Ionic admin has admin rights
   */
  bool public ionicAdminHasRights = true;

  /**
   * @notice Whether or not the admin has admin rights
   */
  bool public adminHasRights = true;

  /**
   * @notice Returns a boolean indicating if the sender has admin rights
   */
  function hasAdminRights() internal view returns (bool) {
    return (msg.sender == admin && adminHasRights) || (msg.sender == address(ionicAdmin) && ionicAdminHasRights);
  }
}

contract ComptrollerV1Storage is UnitrollerAdminStorage {
  /**
   * @notice Oracle which gives the price of any given asset
   */
  BasePriceOracle public oracle;

  /**
   * @notice Multiplier used to calculate the maximum repayAmount when liquidating a borrow
   */
  uint256 public closeFactorMantissa;

  /**
   * @notice Multiplier representing the discount on collateral that a liquidator receives
   */
  uint256 public liquidationIncentiveMantissa;

  /*
   * UNUSED AFTER UPGRADE: Max number of assets a single account can participate in (borrow or use as collateral)
   */
  uint256 internal maxAssets;

  /**
   * @notice Per-account mapping of "assets you are in", capped by maxAssets
   */
  mapping(address => ICErc20[]) public accountAssets;
}

contract ComptrollerV2Storage is ComptrollerV1Storage {
  struct Market {
    // Whether or not this market is listed
    bool isListed;
    // Multiplier representing the most one can borrow against their collateral in this market.
    // For instance, 0.9 to allow borrowing 90% of collateral value.
    // Must be between 0 and 1, and stored as a mantissa.
    uint256 collateralFactorMantissa;
    // Per-market mapping of "accounts in this asset"
    mapping(address => bool) accountMembership;
  }

  /**
   * @notice Official mapping of cTokens -> Market metadata
   * @dev Used e.g. to determine if a market is supported
   */
  mapping(address => Market) public markets;

  /// @notice A list of all markets
  ICErc20[] public allMarkets;

  /**
   * @dev Maps borrowers to booleans indicating if they have entered any markets
   */
  mapping(address => bool) internal borrowers;

  /// @notice A list of all borrowers who have entered markets
  address[] public allBorrowers;

  // Indexes of borrower account addresses in the `allBorrowers` array
  mapping(address => uint256) internal borrowerIndexes;

  /**
   * @dev Maps suppliers to booleans indicating if they have ever supplied to any markets
   */
  mapping(address => bool) public suppliers;

  /// @notice All cTokens addresses mapped by their underlying token addresses
  mapping(address => ICErc20) public cTokensByUnderlying;

  /// @notice Whether or not the supplier whitelist is enforced
  bool public enforceWhitelist;

  /// @notice Maps addresses to booleans indicating if they are allowed to supply assets (i.e., mint cTokens)
  mapping(address => bool) public whitelist;

  /// @notice An array of all whitelisted accounts
  address[] public whitelistArray;

  // Indexes of account addresses in the `whitelistArray` array
  mapping(address => uint256) internal whitelistIndexes;

  /**
   * @notice The Pause Guardian can pause certain actions as a safety mechanism.
   *  Actions which allow users to remove their own assets cannot be paused.
   *  Liquidation / seizing / transfer can only be paused globally, not by market.
   */
  address public pauseGuardian;
  bool public _mintGuardianPaused;
  bool public _borrowGuardianPaused;
  bool public transferGuardianPaused;
  bool public seizeGuardianPaused;
  mapping(address => bool) public mintGuardianPaused;
  mapping(address => bool) public borrowGuardianPaused;
}

contract ComptrollerV3Storage is ComptrollerV2Storage {
  /// @notice The borrowCapGuardian can set borrowCaps to any number for any market. Lowering the borrow cap could disable borrowing on the given market.
  address public borrowCapGuardian;

  /// @notice Borrow caps enforced by borrowAllowed for each cToken address. Defaults to zero which corresponds to unlimited borrowing.
  mapping(address => uint256) public borrowCaps;

  /// @notice Supply caps enforced by mintAllowed for each cToken address. Defaults to zero which corresponds to unlimited supplying.
  mapping(address => uint256) public supplyCaps;

  /// @notice RewardsDistributor contracts to notify of flywheel changes.
  address[] public rewardsDistributors;

  /// @dev Guard variable for pool-wide/cross-asset re-entrancy checks
  bool internal _notEntered;

  /// @dev Whether or not _notEntered has been initialized
  bool internal _notEnteredInitialized;

  /// @notice RewardsDistributor to list for claiming, but not to notify of flywheel changes.
  address[] public nonAccruingRewardsDistributors;

  /// @dev cap for each user's borrows against specific assets - denominated in the borrowed asset
  mapping(address => mapping(address => uint256)) public borrowCapForCollateral;

  /// @dev blacklist to disallow the borrowing of an asset against specific collateral
  mapping(address => mapping(address => bool)) public borrowingAgainstCollateralBlacklist;

  /// @dev set of whitelisted accounts that are allowed to bypass the borrowing against specific collateral cap
  mapping(address => mapping(address => EnumerableSet.AddressSet)) internal borrowCapForCollateralWhitelist;

  /// @dev set of whitelisted accounts that are allowed to bypass the borrow cap
  mapping(address => mapping(address => EnumerableSet.AddressSet))
    internal borrowingAgainstCollateralBlacklistWhitelist;

  /// @dev set of whitelisted accounts that are allowed to bypass the supply cap
  mapping(address => EnumerableSet.AddressSet) internal supplyCapWhitelist;

  /// @dev set of whitelisted accounts that are allowed to bypass the borrow cap
  mapping(address => EnumerableSet.AddressSet) internal borrowCapWhitelist;
}

abstract contract ComptrollerBase is ComptrollerV3Storage {
  /// @notice Indicator that this is a Comptroller contract (for inspection)
  bool public constant isComptroller = true;
}

// contracts/compound/ComptrollerStorage.sol





// contracts/compound/IFeeDistributor.sol

interface IFeeDistributor {
  function minBorrowEth() external view returns (uint256);

  function maxUtilizationRate() external view returns (uint256);

  function interestFeeRate() external view returns (uint256);

  function latestComptrollerImplementation(address oldImplementation) external view returns (address);

  function latestCErc20Delegate(uint8 delegateType)
    external
    view
    returns (address cErc20Delegate, bytes memory becomeImplementationData);

  function latestPluginImplementation(address oldImplementation) external view returns (address);

  function getComptrollerExtensions(address comptroller) external view returns (address[] memory);

  function getCErc20DelegateExtensions(address cErc20Delegate) external view returns (address[] memory);

  function deployCErc20(
    uint8 delegateType,
    bytes calldata constructorData,
    bytes calldata becomeImplData
  ) external returns (address);

  function canCall(
    address pool,
    address user,
    address target,
    bytes4 functionSig
  ) external view returns (bool);

  function authoritiesRegistry() external view returns (AuthoritiesRegistry);

  fallback() external payable;

  receive() external payable;
}

// contracts/ionic/AuthoritiesRegistry.sol

contract AuthoritiesRegistry is SafeOwnableUpgradeable {
  mapping(address => PoolRolesAuthority) public poolsAuthorities;
  PoolRolesAuthority public poolAuthLogic;
  address public leveredPositionsFactory;
  bool public noAuthRequired;

  function initialize(address _leveredPositionsFactory) public initializer {
    __SafeOwnable_init(msg.sender);
    leveredPositionsFactory = _leveredPositionsFactory;
    poolAuthLogic = new PoolRolesAuthority();
  }

  function reinitialize(address _leveredPositionsFactory) public onlyOwnerOrAdmin {
    leveredPositionsFactory = _leveredPositionsFactory;
    poolAuthLogic = new PoolRolesAuthority();
    // for Neon the auth is not required
    noAuthRequired = block.chainid == 245022934;
  }

  function createPoolAuthority(address pool) public onlyOwner returns (PoolRolesAuthority auth) {
    require(address(poolsAuthorities[pool]) == address(0), "already created");

    TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(poolAuthLogic), _getProxyAdmin(), "");
    auth = PoolRolesAuthority(address(proxy));
    auth.initialize(address(this));
    poolsAuthorities[pool] = auth;

    auth.openPoolSupplierCapabilities(IonicComptroller(pool));
    auth.setUserRole(address(this), auth.REGISTRY_ROLE(), true);
    // sets the registry owner as the auth owner
    reconfigureAuthority(pool);
  }

  function reconfigureAuthority(address poolAddress) public {
    IonicComptroller pool = IonicComptroller(poolAddress);
    PoolRolesAuthority auth = poolsAuthorities[address(pool)];

    if (msg.sender != poolAddress || address(auth) != address(0)) {
      require(address(auth) != address(0), "no such authority");
      require(msg.sender == owner() || msg.sender == poolAddress, "not owner or pool");

      auth.configureRegistryCapabilities();
      auth.configurePoolSupplierCapabilities(pool);
      auth.configurePoolBorrowerCapabilities(pool);
      // everyone can be a liquidator
      auth.configureOpenPoolLiquidatorCapabilities(pool);
      auth.configureLeveredPositionCapabilities(pool);

      if (auth.owner() != owner()) {
        auth.setOwner(owner());
      }
    }
  }

  function canCall(
    address pool,
    address user,
    address target,
    bytes4 functionSig
  ) external view returns (bool) {
    PoolRolesAuthority authorityForPool = poolsAuthorities[pool];
    if (address(authorityForPool) == address(0)) {
      return noAuthRequired;
    } else {
      // allow only if an auth exists and it allows the action
      return authorityForPool.canCall(user, target, functionSig);
    }
  }

  function setUserRole(
    address pool,
    address user,
    uint8 role,
    bool enabled
  ) external {
    PoolRolesAuthority poolAuth = poolsAuthorities[pool];

    require(address(poolAuth) != address(0), "auth does not exist");
    require(msg.sender == owner() || msg.sender == leveredPositionsFactory, "not owner or factory");
    require(msg.sender != leveredPositionsFactory || role == poolAuth.LEVERED_POSITION_ROLE(), "only lev pos role");

    poolAuth.setUserRole(user, role, enabled);
  }
}

// contracts/ionic/PoolRolesAuthority.sol

contract PoolRolesAuthority is RolesAuthority, Initializable {
  constructor() RolesAuthority(address(0), Authority(address(0))) {
    _disableInitializers();
  }

  function initialize(address _owner) public initializer {
    owner = _owner;
    authority = this;
  }

  // up to 256 roles
  uint8 public constant REGISTRY_ROLE = 0;
  uint8 public constant SUPPLIER_ROLE = 1;
  uint8 public constant BORROWER_ROLE = 2;
  uint8 public constant LIQUIDATOR_ROLE = 3;
  uint8 public constant LEVERED_POSITION_ROLE = 4;

  function configureRegistryCapabilities() external requiresAuth {
    setRoleCapability(REGISTRY_ROLE, address(this), PoolRolesAuthority.configureRegistryCapabilities.selector, true);
    setRoleCapability(
      REGISTRY_ROLE,
      address(this),
      PoolRolesAuthority.configurePoolSupplierCapabilities.selector,
      true
    );
    setRoleCapability(
      REGISTRY_ROLE,
      address(this),
      PoolRolesAuthority.configurePoolBorrowerCapabilities.selector,
      true
    );
    setRoleCapability(
      REGISTRY_ROLE,
      address(this),
      PoolRolesAuthority.configureClosedPoolLiquidatorCapabilities.selector,
      true
    );
    setRoleCapability(
      REGISTRY_ROLE,
      address(this),
      PoolRolesAuthority.configureOpenPoolLiquidatorCapabilities.selector,
      true
    );
    setRoleCapability(
      REGISTRY_ROLE,
      address(this),
      PoolRolesAuthority.configureLeveredPositionCapabilities.selector,
      true
    );
    setRoleCapability(REGISTRY_ROLE, address(this), RolesAuthority.setUserRole.selector, true);
  }

  function openPoolSupplierCapabilities(IonicComptroller pool) external requiresAuth {
    _setPublicPoolSupplierCapabilities(pool, true);
  }

  function closePoolSupplierCapabilities(IonicComptroller pool) external requiresAuth {
    _setPublicPoolSupplierCapabilities(pool, false);
  }

  function _setPublicPoolSupplierCapabilities(IonicComptroller pool, bool setPublic) internal {
    setPublicCapability(address(pool), pool.enterMarkets.selector, setPublic);
    setPublicCapability(address(pool), pool.exitMarket.selector, setPublic);
    ICErc20[] memory allMarkets = pool.getAllMarkets();
    for (uint256 i = 0; i < allMarkets.length; i++) {
      bytes4[] memory selectors = getSupplierMarketSelectors();
      for (uint256 j = 0; j < selectors.length; j++) {
        setPublicCapability(address(allMarkets[i]), selectors[j], setPublic);
      }
    }
  }

  function configurePoolSupplierCapabilities(IonicComptroller pool) external requiresAuth {
    _configurePoolSupplierCapabilities(pool, SUPPLIER_ROLE);
  }

  function getSupplierMarketSelectors() internal pure returns (bytes4[] memory selectors) {
    uint8 fnsCount = 6;
    selectors = new bytes4[](fnsCount);
    selectors[--fnsCount] = CTokenSecondExtensionInterface.mint.selector;
    selectors[--fnsCount] = CTokenSecondExtensionInterface.redeem.selector;
    selectors[--fnsCount] = CTokenSecondExtensionInterface.redeemUnderlying.selector;
    selectors[--fnsCount] = CTokenFirstExtensionInterface.transfer.selector;
    selectors[--fnsCount] = CTokenFirstExtensionInterface.transferFrom.selector;
    selectors[--fnsCount] = CTokenFirstExtensionInterface.approve.selector;

    require(fnsCount == 0, "use the correct array length");
    return selectors;
  }

  function _configurePoolSupplierCapabilities(IonicComptroller pool, uint8 role) internal {
    setRoleCapability(role, address(pool), pool.enterMarkets.selector, true);
    setRoleCapability(role, address(pool), pool.exitMarket.selector, true);
    ICErc20[] memory allMarkets = pool.getAllMarkets();
    for (uint256 i = 0; i < allMarkets.length; i++) {
      bytes4[] memory selectors = getSupplierMarketSelectors();
      for (uint256 j = 0; j < selectors.length; j++) {
        setRoleCapability(role, address(allMarkets[i]), selectors[j], true);
      }
    }
  }

  function openPoolBorrowerCapabilities(IonicComptroller pool) external requiresAuth {
    _setPublicPoolBorrowerCapabilities(pool, true);
  }

  function closePoolBorrowerCapabilities(IonicComptroller pool) external requiresAuth {
    _setPublicPoolBorrowerCapabilities(pool, false);
  }

  function _setPublicPoolBorrowerCapabilities(IonicComptroller pool, bool setPublic) internal {
    ICErc20[] memory allMarkets = pool.getAllMarkets();
    for (uint256 i = 0; i < allMarkets.length; i++) {
      setPublicCapability(address(allMarkets[i]), allMarkets[i].borrow.selector, setPublic);
      setPublicCapability(address(allMarkets[i]), allMarkets[i].repayBorrow.selector, setPublic);
      setPublicCapability(address(allMarkets[i]), allMarkets[i].repayBorrowBehalf.selector, setPublic);
      setPublicCapability(address(allMarkets[i]), allMarkets[i].flash.selector, setPublic);
    }
  }

  function configurePoolBorrowerCapabilities(IonicComptroller pool) external requiresAuth {
    // borrowers have the SUPPLIER_ROLE capabilities by default
    _configurePoolSupplierCapabilities(pool, BORROWER_ROLE);
    ICErc20[] memory allMarkets = pool.getAllMarkets();
    for (uint256 i = 0; i < allMarkets.length; i++) {
      setRoleCapability(BORROWER_ROLE, address(allMarkets[i]), allMarkets[i].borrow.selector, true);
      setRoleCapability(BORROWER_ROLE, address(allMarkets[i]), allMarkets[i].repayBorrow.selector, true);
      setRoleCapability(BORROWER_ROLE, address(allMarkets[i]), allMarkets[i].repayBorrowBehalf.selector, true);
      setRoleCapability(BORROWER_ROLE, address(allMarkets[i]), allMarkets[i].flash.selector, true);
    }
  }

  function configureClosedPoolLiquidatorCapabilities(IonicComptroller pool) external requiresAuth {
    ICErc20[] memory allMarkets = pool.getAllMarkets();
    for (uint256 i = 0; i < allMarkets.length; i++) {
      setPublicCapability(address(allMarkets[i]), allMarkets[i].liquidateBorrow.selector, false);
      setRoleCapability(LIQUIDATOR_ROLE, address(allMarkets[i]), allMarkets[i].liquidateBorrow.selector, true);
      setRoleCapability(LIQUIDATOR_ROLE, address(allMarkets[i]), allMarkets[i].redeem.selector, true);
    }
  }

  function configureOpenPoolLiquidatorCapabilities(IonicComptroller pool) external requiresAuth {
    ICErc20[] memory allMarkets = pool.getAllMarkets();
    for (uint256 i = 0; i < allMarkets.length; i++) {
      setPublicCapability(address(allMarkets[i]), allMarkets[i].liquidateBorrow.selector, true);
      // TODO this leaves redeeming open for everyone
      setPublicCapability(address(allMarkets[i]), allMarkets[i].redeem.selector, true);
    }
  }

  function configureLeveredPositionCapabilities(IonicComptroller pool) external requiresAuth {
    setRoleCapability(LEVERED_POSITION_ROLE, address(pool), pool.enterMarkets.selector, true);
    setRoleCapability(LEVERED_POSITION_ROLE, address(pool), pool.exitMarket.selector, true);
    ICErc20[] memory allMarkets = pool.getAllMarkets();
    for (uint256 i = 0; i < allMarkets.length; i++) {
      setRoleCapability(LEVERED_POSITION_ROLE, address(allMarkets[i]), allMarkets[i].mint.selector, true);
      setRoleCapability(LEVERED_POSITION_ROLE, address(allMarkets[i]), allMarkets[i].redeem.selector, true);
      setRoleCapability(LEVERED_POSITION_ROLE, address(allMarkets[i]), allMarkets[i].redeemUnderlying.selector, true);

      setRoleCapability(LEVERED_POSITION_ROLE, address(allMarkets[i]), allMarkets[i].borrow.selector, true);
      setRoleCapability(LEVERED_POSITION_ROLE, address(allMarkets[i]), allMarkets[i].repayBorrow.selector, true);
      setRoleCapability(LEVERED_POSITION_ROLE, address(allMarkets[i]), allMarkets[i].flash.selector, true);
    }
  }
}

// contracts/oracles/BasePriceOracle.sol

/**
 * @title BasePriceOracle
 * @notice Returns prices of underlying tokens directly without the caller having to specify a cToken address.
 * @dev Implements the `PriceOracle` interface.
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 */
interface BasePriceOracle {
  /**
   * @notice Get the price of an underlying asset.
   * @param underlying The underlying asset to get the price of.
   * @return The underlying asset price in ETH as a mantissa (scaled by 1e18).
   * Zero means the price is unavailable.
   */
  function price(address underlying) external view returns (uint256);

  /**
   * @notice Get the underlying price of a cToken asset
   * @param cToken The cToken to get the underlying price of
   * @return The underlying asset price mantissa (scaled by 1e18).
   *  Zero means the price is unavailable.
   */
  function getUnderlyingPrice(ICErc20 cToken) external view returns (uint256);
}

// contracts/compound/CErc20Delegator.sol

/**
 * @title Compound's CErc20Delegator Contract
 * @notice CTokens which wrap an EIP-20 underlying and delegate to an implementation
 * @author Compound
 */
contract CErc20Delegator is CErc20DelegatorBase, DiamondBase {
  /**
   * @notice Emitted when implementation is changed
   */
  event NewImplementation(address oldImplementation, address newImplementation);

  /**
   * @notice Initialize the new money market
   * @param underlying_ The address of the underlying asset
   * @param comptroller_ The address of the Comptroller
   * @param ionicAdmin_ The FeeDistributor contract address.
   * @param interestRateModel_ The address of the interest rate model
   * @param name_ ERC-20 name of this token
   * @param symbol_ ERC-20 symbol of this token
   */
  constructor(
    address underlying_,
    IonicComptroller comptroller_,
    address payable ionicAdmin_,
    InterestRateModel interestRateModel_,
    string memory name_,
    string memory symbol_,
    uint256 reserveFactorMantissa_,
    uint256 adminFeeMantissa_
  ) {
    require(msg.sender == ionicAdmin_, "!admin");
    uint8 decimals_ = EIP20Interface(underlying_).decimals();
    {
      ionicAdmin = ionicAdmin_;

      // Set initial exchange rate
      initialExchangeRateMantissa = 0.2e18;

      // Set the comptroller
      comptroller = comptroller_;

      // Initialize block number and borrow index (block number mocks depend on comptroller being set)
      accrualBlockNumber = block.number;
      borrowIndex = 1e18;

      // Set the interest rate model (depends on block number / borrow index)
      require(interestRateModel_.isInterestRateModel(), "!notIrm");
      interestRateModel = interestRateModel_;
      emit NewMarketInterestRateModel(InterestRateModel(address(0)), interestRateModel_);

      name = name_;
      symbol = symbol_;
      decimals = decimals_;

      // Set reserve factor
      // Check newReserveFactor ≤ maxReserveFactor
      require(
        reserveFactorMantissa_ + adminFeeMantissa + ionicFeeMantissa <= reserveFactorPlusFeesMaxMantissa,
        "!rf:set"
      );
      reserveFactorMantissa = reserveFactorMantissa_;
      emit NewReserveFactor(0, reserveFactorMantissa_);

      // Set admin fee
      // Sanitize adminFeeMantissa_
      if (adminFeeMantissa_ == type(uint256).max) adminFeeMantissa_ = adminFeeMantissa;
      // Get latest Ionic fee
      uint256 newIonicFeeMantissa = IFeeDistributor(ionicAdmin).interestFeeRate();
      require(
        reserveFactorMantissa + adminFeeMantissa_ + newIonicFeeMantissa <= reserveFactorPlusFeesMaxMantissa,
        "!adminFee:set"
      );
      adminFeeMantissa = adminFeeMantissa_;
      emit NewAdminFee(0, adminFeeMantissa_);
      ionicFeeMantissa = newIonicFeeMantissa;
      emit NewIonicFee(0, newIonicFeeMantissa);

      // The counter starts true to prevent changing it from zero to non-zero (i.e. smaller cost/refund)
      _notEntered = true;
    }

    // Set underlying and sanity check it
    underlying = underlying_;
    EIP20Interface(underlying).totalSupply();
  }

  function implementation() public view returns (address) {
    return LibDiamond.getExtensionForFunction(bytes4(keccak256(bytes("delegateType()"))));
  }

  /**
   * @notice Called by the admin to update the implementation of the delegator
   * @param implementation_ The address of the new implementation for delegation
   * @param becomeImplementationData The encoded bytes data to be passed to _becomeImplementation
   */
  function _setImplementationSafe(address implementation_, bytes calldata becomeImplementationData) external override {
    // Check admin rights
    require(hasAdminRights(), "!admin");

    // Set implementation
    _setImplementationInternal(implementation_, becomeImplementationData);
  }

  /**
   * @dev upgrades the implementation if necessary
   */
  function _upgrade() external override {
    require(msg.sender == address(this) || hasAdminRights(), "!self or admin");

    (bool success, bytes memory data) = address(this).staticcall(abi.encodeWithSignature("delegateType()"));
    require(success, "no delegate type");

    uint8 currentDelegateType = abi.decode(data, (uint8));
    (address latestCErc20Delegate, bytes memory becomeImplementationData) = IFeeDistributor(ionicAdmin)
      .latestCErc20Delegate(currentDelegateType);

    address currentDelegate = implementation();
    if (currentDelegate != latestCErc20Delegate) {
      _setImplementationInternal(latestCErc20Delegate, becomeImplementationData);
    } else {
      // only update the extensions without reinitializing with becomeImplementationData
      _updateExtensions(currentDelegate);
    }
  }

  /**
   * @dev register a logic extension
   * @param extensionToAdd the extension whose functions are to be added
   * @param extensionToReplace the extension whose functions are to be removed/replaced
   */
  function _registerExtension(DiamondExtension extensionToAdd, DiamondExtension extensionToReplace) external override {
    require(msg.sender == address(ionicAdmin), "!unauthorized");
    LibDiamond.registerExtension(extensionToAdd, extensionToReplace);
  }

  /**
   * @dev Internal function to update the implementation of the delegator
   * @param implementation_ The address of the new implementation for delegation
   * @param becomeImplementationData The encoded bytes data to be passed to _becomeImplementation
   */
  function _setImplementationInternal(address implementation_, bytes memory becomeImplementationData) internal {
    address delegateBefore = implementation();
    _updateExtensions(implementation_);

    _functionCall(
      address(this),
      abi.encodeWithSelector(CDelegateInterface._becomeImplementation.selector, becomeImplementationData),
      "!become impl"
    );

    emit NewImplementation(delegateBefore, implementation_);
  }

  function _updateExtensions(address newDelegate) internal {
    address[] memory latestExtensions = IFeeDistributor(ionicAdmin).getCErc20DelegateExtensions(newDelegate);
    address[] memory currentExtensions = LibDiamond.listExtensions();

    // removed the current (old) extensions
    for (uint256 i = 0; i < currentExtensions.length; i++) {
      LibDiamond.removeExtension(DiamondExtension(currentExtensions[i]));
    }
    // add the new extensions
    for (uint256 i = 0; i < latestExtensions.length; i++) {
      LibDiamond.addExtension(DiamondExtension(latestExtensions[i]));
    }
  }

  function _functionCall(
    address target,
    bytes memory data,
    string memory errorMessage
  ) internal returns (bytes memory) {
    (bool success, bytes memory returndata) = target.call(data);

    if (!success) {
      // Look for revert reason and bubble it up if present
      if (returndata.length > 0) {
        // The easiest way to bubble the revert reason is using memory via assembly

        // solhint-disable-next-line no-inline-assembly
        assembly {
          let returndata_size := mload(returndata)
          revert(add(32, returndata), returndata_size)
        }
      } else {
        revert(errorMessage);
      }
    }

    return returndata;
  }
}

