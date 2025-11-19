"use strict";
var __defProp = Object.defineProperty;
var __getOwnPropDesc = Object.getOwnPropertyDescriptor;
var __getOwnPropNames = Object.getOwnPropertyNames;
var __hasOwnProp = Object.prototype.hasOwnProperty;
var __export = (target, all) => {
  for (var name in all)
    __defProp(target, name, { get: all[name], enumerable: true });
};
var __copyProps = (to, from, except, desc) => {
  if (from && typeof from === "object" || typeof from === "function") {
    for (let key of __getOwnPropNames(from))
      if (!__hasOwnProp.call(to, key) && key !== except)
        __defProp(to, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc(from, key)) || desc.enumerable });
  }
  return to;
};
var __toCommonJS = (mod) => __copyProps(__defProp({}, "__esModule", { value: true }), mod);

// src/index.ts
var index_exports = {};
__export(index_exports, {
  ElitraClient: () => ElitraClient,
  calculateAPY: () => calculateAPY,
  convertToAssets: () => convertToAssets,
  convertToShares: () => convertToShares,
  encodeApprove: () => encodeApprove,
  encodeERC4626Deposit: () => encodeERC4626Deposit,
  encodeERC4626Withdraw: () => encodeERC4626Withdraw,
  encodeManageCall: () => encodeManageCall,
  encodeTransfer: () => encodeTransfer,
  formatShares: () => formatShares,
  formatUnits: () => import_viem3.formatUnits,
  parseAmount: () => parseAmount,
  parseUnits: () => import_viem3.parseUnits
});
module.exports = __toCommonJS(index_exports);

// src/client.ts
var import_viem = require("viem");

// src/abis/ElitraVault.json
var ElitraVault_default = [
  {
    type: "constructor",
    inputs: [],
    stateMutability: "nonpayable"
  },
  {
    type: "receive",
    stateMutability: "payable"
  },
  {
    type: "function",
    name: "aggregatedUnderlyingBalances",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "uint256",
        internalType: "uint256"
      }
    ],
    stateMutability: "view"
  },
  {
    type: "function",
    name: "allowance",
    inputs: [
      {
        name: "owner",
        type: "address",
        internalType: "address"
      },
      {
        name: "spender",
        type: "address",
        internalType: "address"
      }
    ],
    outputs: [
      {
        name: "",
        type: "uint256",
        internalType: "uint256"
      }
    ],
    stateMutability: "view"
  },
  {
    type: "function",
    name: "approve",
    inputs: [
      {
        name: "spender",
        type: "address",
        internalType: "address"
      },
      {
        name: "value",
        type: "uint256",
        internalType: "uint256"
      }
    ],
    outputs: [
      {
        name: "",
        type: "bool",
        internalType: "bool"
      }
    ],
    stateMutability: "nonpayable"
  },
  {
    type: "function",
    name: "asset",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "address",
        internalType: "address"
      }
    ],
    stateMutability: "view"
  },
  {
    type: "function",
    name: "authority",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "address",
        internalType: "contract Authority"
      }
    ],
    stateMutability: "view"
  },
  {
    type: "function",
    name: "balanceOf",
    inputs: [
      {
        name: "account",
        type: "address",
        internalType: "address"
      }
    ],
    outputs: [
      {
        name: "",
        type: "uint256",
        internalType: "uint256"
      }
    ],
    stateMutability: "view"
  },
  {
    type: "function",
    name: "balanceUpdateHook",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "address",
        internalType: "contract IBalanceUpdateHook"
      }
    ],
    stateMutability: "view"
  },
  {
    type: "function",
    name: "cancelRedeem",
    inputs: [
      {
        name: "receiver",
        type: "address",
        internalType: "address"
      },
      {
        name: "shares",
        type: "uint256",
        internalType: "uint256"
      },
      {
        name: "assets",
        type: "uint256",
        internalType: "uint256"
      }
    ],
    outputs: [],
    stateMutability: "nonpayable"
  },
  {
    type: "function",
    name: "convertToAssets",
    inputs: [
      {
        name: "shares",
        type: "uint256",
        internalType: "uint256"
      }
    ],
    outputs: [
      {
        name: "",
        type: "uint256",
        internalType: "uint256"
      }
    ],
    stateMutability: "view"
  },
  {
    type: "function",
    name: "convertToShares",
    inputs: [
      {
        name: "assets",
        type: "uint256",
        internalType: "uint256"
      }
    ],
    outputs: [
      {
        name: "",
        type: "uint256",
        internalType: "uint256"
      }
    ],
    stateMutability: "view"
  },
  {
    type: "function",
    name: "decimals",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "uint8",
        internalType: "uint8"
      }
    ],
    stateMutability: "view"
  },
  {
    type: "function",
    name: "deposit",
    inputs: [
      {
        name: "assets",
        type: "uint256",
        internalType: "uint256"
      },
      {
        name: "receiver",
        type: "address",
        internalType: "address"
      }
    ],
    outputs: [
      {
        name: "",
        type: "uint256",
        internalType: "uint256"
      }
    ],
    stateMutability: "nonpayable"
  },
  {
    type: "function",
    name: "fulfillRedeem",
    inputs: [
      {
        name: "receiver",
        type: "address",
        internalType: "address"
      },
      {
        name: "shares",
        type: "uint256",
        internalType: "uint256"
      },
      {
        name: "assets",
        type: "uint256",
        internalType: "uint256"
      }
    ],
    outputs: [],
    stateMutability: "nonpayable"
  },
  {
    type: "function",
    name: "getAvailableBalance",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "uint256",
        internalType: "uint256"
      }
    ],
    stateMutability: "view"
  },
  {
    type: "function",
    name: "initialize",
    inputs: [
      {
        name: "_asset",
        type: "address",
        internalType: "contract IERC20"
      },
      {
        name: "_owner",
        type: "address",
        internalType: "address"
      },
      {
        name: "_balanceUpdateHook",
        type: "address",
        internalType: "contract IBalanceUpdateHook"
      },
      {
        name: "_redemptionHook",
        type: "address",
        internalType: "contract IRedemptionHook"
      },
      {
        name: "_name",
        type: "string",
        internalType: "string"
      },
      {
        name: "_symbol",
        type: "string",
        internalType: "string"
      }
    ],
    outputs: [],
    stateMutability: "nonpayable"
  },
  {
    type: "function",
    name: "isAuthorized",
    inputs: [
      {
        name: "user",
        type: "address",
        internalType: "address"
      },
      {
        name: "functionSig",
        type: "bytes4",
        internalType: "bytes4"
      }
    ],
    outputs: [
      {
        name: "",
        type: "bool",
        internalType: "bool"
      }
    ],
    stateMutability: "view"
  },
  {
    type: "function",
    name: "lastBlockUpdated",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "uint256",
        internalType: "uint256"
      }
    ],
    stateMutability: "view"
  },
  {
    type: "function",
    name: "lastPricePerShare",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "uint256",
        internalType: "uint256"
      }
    ],
    stateMutability: "view"
  },
  {
    type: "function",
    name: "manage",
    inputs: [
      {
        name: "target",
        type: "address",
        internalType: "address"
      },
      {
        name: "data",
        type: "bytes",
        internalType: "bytes"
      },
      {
        name: "value",
        type: "uint256",
        internalType: "uint256"
      }
    ],
    outputs: [
      {
        name: "result",
        type: "bytes",
        internalType: "bytes"
      }
    ],
    stateMutability: "nonpayable"
  },
  {
    type: "function",
    name: "manageBatch",
    inputs: [
      {
        name: "targets",
        type: "address[]",
        internalType: "address[]"
      },
      {
        name: "data",
        type: "bytes[]",
        internalType: "bytes[]"
      },
      {
        name: "values",
        type: "uint256[]",
        internalType: "uint256[]"
      }
    ],
    outputs: [],
    stateMutability: "nonpayable"
  },
  {
    type: "function",
    name: "maxDeposit",
    inputs: [
      {
        name: "receiver",
        type: "address",
        internalType: "address"
      }
    ],
    outputs: [
      {
        name: "",
        type: "uint256",
        internalType: "uint256"
      }
    ],
    stateMutability: "view"
  },
  {
    type: "function",
    name: "maxMint",
    inputs: [
      {
        name: "receiver",
        type: "address",
        internalType: "address"
      }
    ],
    outputs: [
      {
        name: "",
        type: "uint256",
        internalType: "uint256"
      }
    ],
    stateMutability: "view"
  },
  {
    type: "function",
    name: "maxRedeem",
    inputs: [
      {
        name: "owner",
        type: "address",
        internalType: "address"
      }
    ],
    outputs: [
      {
        name: "",
        type: "uint256",
        internalType: "uint256"
      }
    ],
    stateMutability: "view"
  },
  {
    type: "function",
    name: "maxWithdraw",
    inputs: [
      {
        name: "owner",
        type: "address",
        internalType: "address"
      }
    ],
    outputs: [
      {
        name: "",
        type: "uint256",
        internalType: "uint256"
      }
    ],
    stateMutability: "view"
  },
  {
    type: "function",
    name: "mint",
    inputs: [
      {
        name: "shares",
        type: "uint256",
        internalType: "uint256"
      },
      {
        name: "receiver",
        type: "address",
        internalType: "address"
      }
    ],
    outputs: [
      {
        name: "",
        type: "uint256",
        internalType: "uint256"
      }
    ],
    stateMutability: "nonpayable"
  },
  {
    type: "function",
    name: "name",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "string",
        internalType: "string"
      }
    ],
    stateMutability: "view"
  },
  {
    type: "function",
    name: "onERC1155BatchReceived",
    inputs: [
      {
        name: "",
        type: "address",
        internalType: "address"
      },
      {
        name: "",
        type: "address",
        internalType: "address"
      },
      {
        name: "",
        type: "uint256[]",
        internalType: "uint256[]"
      },
      {
        name: "",
        type: "uint256[]",
        internalType: "uint256[]"
      },
      {
        name: "",
        type: "bytes",
        internalType: "bytes"
      }
    ],
    outputs: [
      {
        name: "",
        type: "bytes4",
        internalType: "bytes4"
      }
    ],
    stateMutability: "pure"
  },
  {
    type: "function",
    name: "onERC1155Received",
    inputs: [
      {
        name: "",
        type: "address",
        internalType: "address"
      },
      {
        name: "",
        type: "address",
        internalType: "address"
      },
      {
        name: "",
        type: "uint256",
        internalType: "uint256"
      },
      {
        name: "",
        type: "uint256",
        internalType: "uint256"
      },
      {
        name: "",
        type: "bytes",
        internalType: "bytes"
      }
    ],
    outputs: [
      {
        name: "",
        type: "bytes4",
        internalType: "bytes4"
      }
    ],
    stateMutability: "pure"
  },
  {
    type: "function",
    name: "onERC721Received",
    inputs: [
      {
        name: "",
        type: "address",
        internalType: "address"
      },
      {
        name: "",
        type: "address",
        internalType: "address"
      },
      {
        name: "",
        type: "uint256",
        internalType: "uint256"
      },
      {
        name: "",
        type: "bytes",
        internalType: "bytes"
      }
    ],
    outputs: [
      {
        name: "",
        type: "bytes4",
        internalType: "bytes4"
      }
    ],
    stateMutability: "pure"
  },
  {
    type: "function",
    name: "owner",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "address",
        internalType: "address"
      }
    ],
    stateMutability: "view"
  },
  {
    type: "function",
    name: "pause",
    inputs: [],
    outputs: [],
    stateMutability: "nonpayable"
  },
  {
    type: "function",
    name: "paused",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "bool",
        internalType: "bool"
      }
    ],
    stateMutability: "view"
  },
  {
    type: "function",
    name: "pendingRedeemRequest",
    inputs: [
      {
        name: "user",
        type: "address",
        internalType: "address"
      }
    ],
    outputs: [
      {
        name: "assets",
        type: "uint256",
        internalType: "uint256"
      },
      {
        name: "pendingShares",
        type: "uint256",
        internalType: "uint256"
      }
    ],
    stateMutability: "view"
  },
  {
    type: "function",
    name: "previewDeposit",
    inputs: [
      {
        name: "assets",
        type: "uint256",
        internalType: "uint256"
      }
    ],
    outputs: [
      {
        name: "",
        type: "uint256",
        internalType: "uint256"
      }
    ],
    stateMutability: "view"
  },
  {
    type: "function",
    name: "previewMint",
    inputs: [
      {
        name: "shares",
        type: "uint256",
        internalType: "uint256"
      }
    ],
    outputs: [
      {
        name: "",
        type: "uint256",
        internalType: "uint256"
      }
    ],
    stateMutability: "view"
  },
  {
    type: "function",
    name: "previewRedeem",
    inputs: [
      {
        name: "shares",
        type: "uint256",
        internalType: "uint256"
      }
    ],
    outputs: [
      {
        name: "",
        type: "uint256",
        internalType: "uint256"
      }
    ],
    stateMutability: "view"
  },
  {
    type: "function",
    name: "previewWithdraw",
    inputs: [
      {
        name: "assets",
        type: "uint256",
        internalType: "uint256"
      }
    ],
    outputs: [
      {
        name: "",
        type: "uint256",
        internalType: "uint256"
      }
    ],
    stateMutability: "view"
  },
  {
    type: "function",
    name: "redeem",
    inputs: [
      {
        name: "shares",
        type: "uint256",
        internalType: "uint256"
      },
      {
        name: "receiver",
        type: "address",
        internalType: "address"
      },
      {
        name: "owner",
        type: "address",
        internalType: "address"
      }
    ],
    outputs: [
      {
        name: "",
        type: "uint256",
        internalType: "uint256"
      }
    ],
    stateMutability: "nonpayable"
  },
  {
    type: "function",
    name: "redemptionHook",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "address",
        internalType: "contract IRedemptionHook"
      }
    ],
    stateMutability: "view"
  },
  {
    type: "function",
    name: "requestRedeem",
    inputs: [
      {
        name: "shares",
        type: "uint256",
        internalType: "uint256"
      },
      {
        name: "receiver",
        type: "address",
        internalType: "address"
      },
      {
        name: "owner",
        type: "address",
        internalType: "address"
      }
    ],
    outputs: [
      {
        name: "",
        type: "uint256",
        internalType: "uint256"
      }
    ],
    stateMutability: "nonpayable"
  },
  {
    type: "function",
    name: "setAuthority",
    inputs: [
      {
        name: "newAuthority",
        type: "address",
        internalType: "contract Authority"
      }
    ],
    outputs: [],
    stateMutability: "nonpayable"
  },
  {
    type: "function",
    name: "setBalanceUpdateHook",
    inputs: [
      {
        name: "newAdapter",
        type: "address",
        internalType: "contract IBalanceUpdateHook"
      }
    ],
    outputs: [],
    stateMutability: "nonpayable"
  },
  {
    type: "function",
    name: "setRedemptionHook",
    inputs: [
      {
        name: "newStrategy",
        type: "address",
        internalType: "contract IRedemptionHook"
      }
    ],
    outputs: [],
    stateMutability: "nonpayable"
  },
  {
    type: "function",
    name: "symbol",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "string",
        internalType: "string"
      }
    ],
    stateMutability: "view"
  },
  {
    type: "function",
    name: "totalAssets",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "uint256",
        internalType: "uint256"
      }
    ],
    stateMutability: "view"
  },
  {
    type: "function",
    name: "totalPendingAssets",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "uint256",
        internalType: "uint256"
      }
    ],
    stateMutability: "view"
  },
  {
    type: "function",
    name: "totalSupply",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "uint256",
        internalType: "uint256"
      }
    ],
    stateMutability: "view"
  },
  {
    type: "function",
    name: "transfer",
    inputs: [
      {
        name: "to",
        type: "address",
        internalType: "address"
      },
      {
        name: "value",
        type: "uint256",
        internalType: "uint256"
      }
    ],
    outputs: [
      {
        name: "",
        type: "bool",
        internalType: "bool"
      }
    ],
    stateMutability: "nonpayable"
  },
  {
    type: "function",
    name: "transferFrom",
    inputs: [
      {
        name: "from",
        type: "address",
        internalType: "address"
      },
      {
        name: "to",
        type: "address",
        internalType: "address"
      },
      {
        name: "value",
        type: "uint256",
        internalType: "uint256"
      }
    ],
    outputs: [
      {
        name: "",
        type: "bool",
        internalType: "bool"
      }
    ],
    stateMutability: "nonpayable"
  },
  {
    type: "function",
    name: "transferOwnership",
    inputs: [
      {
        name: "newOwner",
        type: "address",
        internalType: "address"
      }
    ],
    outputs: [],
    stateMutability: "nonpayable"
  },
  {
    type: "function",
    name: "unpause",
    inputs: [],
    outputs: [],
    stateMutability: "nonpayable"
  },
  {
    type: "function",
    name: "updateBalance",
    inputs: [
      {
        name: "newAggregatedBalance",
        type: "uint256",
        internalType: "uint256"
      }
    ],
    outputs: [],
    stateMutability: "nonpayable"
  },
  {
    type: "function",
    name: "withdraw",
    inputs: [
      {
        name: "",
        type: "uint256",
        internalType: "uint256"
      },
      {
        name: "",
        type: "address",
        internalType: "address"
      },
      {
        name: "",
        type: "address",
        internalType: "address"
      }
    ],
    outputs: [
      {
        name: "",
        type: "uint256",
        internalType: "uint256"
      }
    ],
    stateMutability: "nonpayable"
  },
  {
    type: "event",
    name: "Approval",
    inputs: [
      {
        name: "owner",
        type: "address",
        indexed: true,
        internalType: "address"
      },
      {
        name: "spender",
        type: "address",
        indexed: true,
        internalType: "address"
      },
      {
        name: "value",
        type: "uint256",
        indexed: false,
        internalType: "uint256"
      }
    ],
    anonymous: false
  },
  {
    type: "event",
    name: "AuthorityUpdated",
    inputs: [
      {
        name: "user",
        type: "address",
        indexed: true,
        internalType: "address"
      },
      {
        name: "newAuthority",
        type: "address",
        indexed: true,
        internalType: "contract Authority"
      }
    ],
    anonymous: false
  },
  {
    type: "event",
    name: "BalanceUpdateHookUpdated",
    inputs: [
      {
        name: "oldHook",
        type: "address",
        indexed: true,
        internalType: "address"
      },
      {
        name: "newHook",
        type: "address",
        indexed: true,
        internalType: "address"
      }
    ],
    anonymous: false
  },
  {
    type: "event",
    name: "Deposit",
    inputs: [
      {
        name: "sender",
        type: "address",
        indexed: true,
        internalType: "address"
      },
      {
        name: "owner",
        type: "address",
        indexed: true,
        internalType: "address"
      },
      {
        name: "assets",
        type: "uint256",
        indexed: false,
        internalType: "uint256"
      },
      {
        name: "shares",
        type: "uint256",
        indexed: false,
        internalType: "uint256"
      }
    ],
    anonymous: false
  },
  {
    type: "event",
    name: "Initialized",
    inputs: [
      {
        name: "version",
        type: "uint64",
        indexed: false,
        internalType: "uint64"
      }
    ],
    anonymous: false
  },
  {
    type: "event",
    name: "ManageBatchOperation",
    inputs: [
      {
        name: "index",
        type: "uint256",
        indexed: true,
        internalType: "uint256"
      },
      {
        name: "target",
        type: "address",
        indexed: true,
        internalType: "address"
      },
      {
        name: "functionSig",
        type: "bytes4",
        indexed: false,
        internalType: "bytes4"
      },
      {
        name: "value",
        type: "uint256",
        indexed: false,
        internalType: "uint256"
      },
      {
        name: "result",
        type: "bytes",
        indexed: false,
        internalType: "bytes"
      }
    ],
    anonymous: false
  },
  {
    type: "event",
    name: "OwnershipTransferred",
    inputs: [
      {
        name: "user",
        type: "address",
        indexed: true,
        internalType: "address"
      },
      {
        name: "newOwner",
        type: "address",
        indexed: true,
        internalType: "address"
      }
    ],
    anonymous: false
  },
  {
    type: "event",
    name: "PPSUpdated",
    inputs: [
      {
        name: "timestamp",
        type: "uint256",
        indexed: true,
        internalType: "uint256"
      },
      {
        name: "oldPPS",
        type: "uint256",
        indexed: false,
        internalType: "uint256"
      },
      {
        name: "newPPS",
        type: "uint256",
        indexed: false,
        internalType: "uint256"
      }
    ],
    anonymous: false
  },
  {
    type: "event",
    name: "Paused",
    inputs: [
      {
        name: "account",
        type: "address",
        indexed: false,
        internalType: "address"
      }
    ],
    anonymous: false
  },
  {
    type: "event",
    name: "Received",
    inputs: [
      {
        name: "sender",
        type: "address",
        indexed: false,
        internalType: "address"
      },
      {
        name: "amount",
        type: "uint256",
        indexed: false,
        internalType: "uint256"
      }
    ],
    anonymous: false
  },
  {
    type: "event",
    name: "RedeemRequest",
    inputs: [
      {
        name: "receiver",
        type: "address",
        indexed: true,
        internalType: "address"
      },
      {
        name: "owner",
        type: "address",
        indexed: true,
        internalType: "address"
      },
      {
        name: "assets",
        type: "uint256",
        indexed: false,
        internalType: "uint256"
      },
      {
        name: "shares",
        type: "uint256",
        indexed: false,
        internalType: "uint256"
      },
      {
        name: "instant",
        type: "bool",
        indexed: false,
        internalType: "bool"
      }
    ],
    anonymous: false
  },
  {
    type: "event",
    name: "RedemptionHookUpdated",
    inputs: [
      {
        name: "oldHook",
        type: "address",
        indexed: true,
        internalType: "address"
      },
      {
        name: "newHook",
        type: "address",
        indexed: true,
        internalType: "address"
      }
    ],
    anonymous: false
  },
  {
    type: "event",
    name: "RequestCancelled",
    inputs: [
      {
        name: "receiver",
        type: "address",
        indexed: true,
        internalType: "address"
      },
      {
        name: "shares",
        type: "uint256",
        indexed: false,
        internalType: "uint256"
      },
      {
        name: "assets",
        type: "uint256",
        indexed: false,
        internalType: "uint256"
      }
    ],
    anonymous: false
  },
  {
    type: "event",
    name: "RequestFulfilled",
    inputs: [
      {
        name: "receiver",
        type: "address",
        indexed: true,
        internalType: "address"
      },
      {
        name: "shares",
        type: "uint256",
        indexed: false,
        internalType: "uint256"
      },
      {
        name: "assets",
        type: "uint256",
        indexed: false,
        internalType: "uint256"
      }
    ],
    anonymous: false
  },
  {
    type: "event",
    name: "Transfer",
    inputs: [
      {
        name: "from",
        type: "address",
        indexed: true,
        internalType: "address"
      },
      {
        name: "to",
        type: "address",
        indexed: true,
        internalType: "address"
      },
      {
        name: "value",
        type: "uint256",
        indexed: false,
        internalType: "uint256"
      }
    ],
    anonymous: false
  },
  {
    type: "event",
    name: "UnderlyingBalanceUpdated",
    inputs: [
      {
        name: "timestamp",
        type: "uint256",
        indexed: true,
        internalType: "uint256"
      },
      {
        name: "oldBalance",
        type: "uint256",
        indexed: false,
        internalType: "uint256"
      },
      {
        name: "newBalance",
        type: "uint256",
        indexed: false,
        internalType: "uint256"
      }
    ],
    anonymous: false
  },
  {
    type: "event",
    name: "Unpaused",
    inputs: [
      {
        name: "account",
        type: "address",
        indexed: false,
        internalType: "address"
      }
    ],
    anonymous: false
  },
  {
    type: "event",
    name: "VaultPausedDueToThreshold",
    inputs: [
      {
        name: "timestamp",
        type: "uint256",
        indexed: true,
        internalType: "uint256"
      },
      {
        name: "oldPPS",
        type: "uint256",
        indexed: false,
        internalType: "uint256"
      },
      {
        name: "newPPS",
        type: "uint256",
        indexed: false,
        internalType: "uint256"
      }
    ],
    anonymous: false
  },
  {
    type: "event",
    name: "Withdraw",
    inputs: [
      {
        name: "sender",
        type: "address",
        indexed: true,
        internalType: "address"
      },
      {
        name: "receiver",
        type: "address",
        indexed: true,
        internalType: "address"
      },
      {
        name: "owner",
        type: "address",
        indexed: true,
        internalType: "address"
      },
      {
        name: "assets",
        type: "uint256",
        indexed: false,
        internalType: "uint256"
      },
      {
        name: "shares",
        type: "uint256",
        indexed: false,
        internalType: "uint256"
      }
    ],
    anonymous: false
  },
  {
    type: "error",
    name: "AddressEmptyCode",
    inputs: [
      {
        name: "target",
        type: "address",
        internalType: "address"
      }
    ]
  },
  {
    type: "error",
    name: "ERC20InsufficientAllowance",
    inputs: [
      {
        name: "spender",
        type: "address",
        internalType: "address"
      },
      {
        name: "allowance",
        type: "uint256",
        internalType: "uint256"
      },
      {
        name: "needed",
        type: "uint256",
        internalType: "uint256"
      }
    ]
  },
  {
    type: "error",
    name: "ERC20InsufficientBalance",
    inputs: [
      {
        name: "sender",
        type: "address",
        internalType: "address"
      },
      {
        name: "balance",
        type: "uint256",
        internalType: "uint256"
      },
      {
        name: "needed",
        type: "uint256",
        internalType: "uint256"
      }
    ]
  },
  {
    type: "error",
    name: "ERC20InvalidApprover",
    inputs: [
      {
        name: "approver",
        type: "address",
        internalType: "address"
      }
    ]
  },
  {
    type: "error",
    name: "ERC20InvalidReceiver",
    inputs: [
      {
        name: "receiver",
        type: "address",
        internalType: "address"
      }
    ]
  },
  {
    type: "error",
    name: "ERC20InvalidSender",
    inputs: [
      {
        name: "sender",
        type: "address",
        internalType: "address"
      }
    ]
  },
  {
    type: "error",
    name: "ERC20InvalidSpender",
    inputs: [
      {
        name: "spender",
        type: "address",
        internalType: "address"
      }
    ]
  },
  {
    type: "error",
    name: "ERC4626ExceededMaxDeposit",
    inputs: [
      {
        name: "receiver",
        type: "address",
        internalType: "address"
      },
      {
        name: "assets",
        type: "uint256",
        internalType: "uint256"
      },
      {
        name: "max",
        type: "uint256",
        internalType: "uint256"
      }
    ]
  },
  {
    type: "error",
    name: "ERC4626ExceededMaxMint",
    inputs: [
      {
        name: "receiver",
        type: "address",
        internalType: "address"
      },
      {
        name: "shares",
        type: "uint256",
        internalType: "uint256"
      },
      {
        name: "max",
        type: "uint256",
        internalType: "uint256"
      }
    ]
  },
  {
    type: "error",
    name: "ERC4626ExceededMaxRedeem",
    inputs: [
      {
        name: "owner",
        type: "address",
        internalType: "address"
      },
      {
        name: "shares",
        type: "uint256",
        internalType: "uint256"
      },
      {
        name: "max",
        type: "uint256",
        internalType: "uint256"
      }
    ]
  },
  {
    type: "error",
    name: "ERC4626ExceededMaxWithdraw",
    inputs: [
      {
        name: "owner",
        type: "address",
        internalType: "address"
      },
      {
        name: "assets",
        type: "uint256",
        internalType: "uint256"
      },
      {
        name: "max",
        type: "uint256",
        internalType: "uint256"
      }
    ]
  },
  {
    type: "error",
    name: "EnforcedPause",
    inputs: []
  },
  {
    type: "error",
    name: "ExpectedPause",
    inputs: []
  },
  {
    type: "error",
    name: "FailedCall",
    inputs: []
  },
  {
    type: "error",
    name: "InsufficientBalance",
    inputs: [
      {
        name: "balance",
        type: "uint256",
        internalType: "uint256"
      },
      {
        name: "needed",
        type: "uint256",
        internalType: "uint256"
      }
    ]
  },
  {
    type: "error",
    name: "InsufficientShares",
    inputs: []
  },
  {
    type: "error",
    name: "InvalidAssetsAmount",
    inputs: []
  },
  {
    type: "error",
    name: "InvalidInitialization",
    inputs: []
  },
  {
    type: "error",
    name: "InvalidRedemptionMode",
    inputs: []
  },
  {
    type: "error",
    name: "InvalidSharesAmount",
    inputs: []
  },
  {
    type: "error",
    name: "NotInitializing",
    inputs: []
  },
  {
    type: "error",
    name: "NotSharesOwner",
    inputs: []
  },
  {
    type: "error",
    name: "SafeERC20FailedOperation",
    inputs: [
      {
        name: "token",
        type: "address",
        internalType: "address"
      }
    ]
  },
  {
    type: "error",
    name: "SharesAmountZero",
    inputs: []
  },
  {
    type: "error",
    name: "TargetMethodNotAuthorized",
    inputs: [
      {
        name: "target",
        type: "address",
        internalType: "address"
      },
      {
        name: "functionSig",
        type: "bytes4",
        internalType: "bytes4"
      }
    ]
  },
  {
    type: "error",
    name: "UpdateAlreadyCompletedInThisBlock",
    inputs: []
  },
  {
    type: "error",
    name: "UseRequestRedeem",
    inputs: []
  },
  {
    type: "error",
    name: "ZeroAddress",
    inputs: []
  }
];

// src/client.ts
var ElitraClient = class {
  constructor(config) {
    this.vaultAddress = config.vaultAddress;
    this.publicClient = config.publicClient;
    this.walletClient = config.walletClient;
  }
  // ========================================= READ OPERATIONS =========================================
  /**
   * Get the vault's underlying asset address
   */
  async getAsset() {
    const asset = await this.publicClient.readContract({
      address: this.vaultAddress,
      abi: ElitraVault_default,
      functionName: "asset"
    });
    return asset;
  }
  /**
   * Get the total assets managed by the vault
   */
  async getTotalAssets() {
    const totalAssets = await this.publicClient.readContract({
      address: this.vaultAddress,
      abi: ElitraVault_default,
      functionName: "totalAssets"
    });
    return totalAssets;
  }
  /**
   * Get the total supply of vault shares
   */
  async getTotalSupply() {
    const totalSupply = await this.publicClient.readContract({
      address: this.vaultAddress,
      abi: ElitraVault_default,
      functionName: "totalSupply"
    });
    return totalSupply;
  }
  /**
   * Get the current price per share (in asset units)
   */
  async getPricePerShare() {
    const [totalAssets, totalSupply] = await Promise.all([
      this.getTotalAssets(),
      this.getTotalSupply()
    ]);
    if (totalSupply === 0n) {
      return 10n ** 18n;
    }
    return totalAssets * 10n ** 18n / totalSupply;
  }
  /**
   * Preview the amount of shares received for a deposit
   */
  async previewDeposit(assets) {
    const shares = await this.publicClient.readContract({
      address: this.vaultAddress,
      abi: ElitraVault_default,
      functionName: "previewDeposit",
      args: [assets]
    });
    return shares;
  }
  /**
   * Preview the amount of assets required to mint shares
   */
  async previewMint(shares) {
    const assets = await this.publicClient.readContract({
      address: this.vaultAddress,
      abi: ElitraVault_default,
      functionName: "previewMint",
      args: [shares]
    });
    return assets;
  }
  /**
   * Preview the amount of assets received for redeeming shares
   */
  async previewRedeem(shares) {
    const assets = await this.publicClient.readContract({
      address: this.vaultAddress,
      abi: ElitraVault_default,
      functionName: "previewRedeem",
      args: [shares]
    });
    return assets;
  }
  /**
   * Get available balance for withdrawals (excluding pending redemptions)
   */
  async getAvailableBalance() {
    const balance = await this.publicClient.readContract({
      address: this.vaultAddress,
      abi: ElitraVault_default,
      functionName: "getAvailableBalance"
    });
    return balance;
  }
  /**
   * Get pending redemption request for a user
   */
  async getPendingRedeem(user) {
    const result = await this.publicClient.readContract({
      address: this.vaultAddress,
      abi: ElitraVault_default,
      functionName: "pendingRedeemRequest",
      args: [user]
    });
    return {
      assets: result[0],
      shares: result[1]
    };
  }
  /**
   * Get complete vault state
   */
  async getVaultState() {
    const [
      totalAssets,
      totalSupply,
      aggregatedUnderlyingBalances,
      totalPendingAssets,
      availableBalance,
      isPaused,
      lastBlockUpdated,
      lastPricePerShare
    ] = await Promise.all([
      this.getTotalAssets(),
      this.getTotalSupply(),
      this.publicClient.readContract({
        address: this.vaultAddress,
        abi: ElitraVault_default,
        functionName: "aggregatedUnderlyingBalances"
      }),
      this.publicClient.readContract({
        address: this.vaultAddress,
        abi: ElitraVault_default,
        functionName: "totalPendingAssets"
      }),
      this.getAvailableBalance(),
      this.publicClient.readContract({
        address: this.vaultAddress,
        abi: ElitraVault_default,
        functionName: "paused"
      }),
      this.publicClient.readContract({
        address: this.vaultAddress,
        abi: ElitraVault_default,
        functionName: "lastBlockUpdated"
      }),
      this.publicClient.readContract({
        address: this.vaultAddress,
        abi: ElitraVault_default,
        functionName: "lastPricePerShare"
      })
    ]);
    const pricePerShare = totalSupply === 0n ? 10n ** 18n : totalAssets * 10n ** 18n / totalSupply;
    return {
      totalAssets,
      totalSupply,
      pricePerShare,
      aggregatedUnderlyingBalances,
      totalPendingAssets,
      availableBalance,
      isPaused,
      lastBlockUpdated,
      lastPricePerShare
    };
  }
  /**
   * Get user's position in the vault
   */
  async getUserPosition(user) {
    const [shares, pendingRedeem, maxWithdraw, maxRedeem] = await Promise.all([
      this.publicClient.readContract({
        address: this.vaultAddress,
        abi: ElitraVault_default,
        functionName: "balanceOf",
        args: [user]
      }),
      this.getPendingRedeem(user),
      this.publicClient.readContract({
        address: this.vaultAddress,
        abi: ElitraVault_default,
        functionName: "maxWithdraw",
        args: [user]
      }),
      this.publicClient.readContract({
        address: this.vaultAddress,
        abi: ElitraVault_default,
        functionName: "maxRedeem",
        args: [user]
      })
    ]);
    const assets = shares === 0n ? 0n : await this.previewRedeem(shares);
    return {
      shares,
      assets,
      pendingRedeem,
      maxWithdraw,
      maxRedeem
    };
  }
  // ========================================= WRITE OPERATIONS =========================================
  /**
   * Deposit assets into the vault
   *
   * @param assets - Amount of assets to deposit
   * @param options - Deposit options
   * @returns Transaction hash and shares received
   */
  async deposit(assets, options = {}) {
    if (!this.walletClient) {
      throw new Error("WalletClient is required for write operations");
    }
    const account = this.walletClient.account;
    if (!account) {
      throw new Error("WalletClient must have an account");
    }
    const receiver = options.receiver ?? account.address;
    const expectedShares = await this.previewDeposit(assets);
    const hash = await this.walletClient.writeContract({
      address: this.vaultAddress,
      abi: ElitraVault_default,
      functionName: "deposit",
      args: [assets, receiver],
      account,
      chain: this.walletClient.chain
    });
    return {
      hash,
      shares: expectedShares
    };
  }
  /**
   * Mint vault shares
   *
   * @param shares - Amount of shares to mint
   * @param options - Mint options
   * @returns Transaction hash and assets deposited
   */
  async mint(shares, options = {}) {
    if (!this.walletClient) {
      throw new Error("WalletClient is required for write operations");
    }
    const account = this.walletClient.account;
    if (!account) {
      throw new Error("WalletClient must have an account");
    }
    const receiver = options.receiver ?? account.address;
    const hash = await this.walletClient.writeContract({
      address: this.vaultAddress,
      abi: ElitraVault_default,
      functionName: "mint",
      args: [shares, receiver],
      account,
      chain: this.walletClient.chain
    });
    return {
      hash,
      shares
    };
  }
  /**
   * Request redemption of vault shares
   *
   * @param shares - Amount of shares to redeem
   * @param options - Redeem options
   * @returns Transaction hash and redemption details
   */
  async requestRedeem(shares, options = {}) {
    if (!this.walletClient) {
      throw new Error("WalletClient is required for write operations");
    }
    const account = this.walletClient.account;
    if (!account) {
      throw new Error("WalletClient must have an account");
    }
    const receiver = options.receiver ?? account.address;
    const owner = options.owner ?? account.address;
    const hash = await this.walletClient.writeContract({
      address: this.vaultAddress,
      abi: ElitraVault_default,
      functionName: "requestRedeem",
      args: [shares, receiver, owner],
      account,
      chain: this.walletClient.chain
    });
    const receipt = await this.publicClient.waitForTransactionReceipt({ hash });
    const logs = (0, import_viem.parseEventLogs)({
      abi: ElitraVault_default,
      logs: receipt.logs,
      eventName: "RedeemRequest"
    });
    if (logs.length > 0) {
      const event = logs[0];
      const isInstant = event.args.instant;
      const assets = event.args.assets;
      return {
        hash,
        value: isInstant ? assets : 0n,
        // 0 is the REQUEST_ID for queued
        isInstant
      };
    }
    const expectedAssets = await this.previewRedeem(shares);
    return {
      hash,
      value: expectedAssets,
      isInstant: true
    };
  }
  /**
   * Call the manage function to execute arbitrary calls from the vault
   *
   * @param target - Target contract address
   * @param data - Encoded function call data
   * @param options - Manage options
   * @returns Transaction hash and return data
   */
  async manage(target, data, options = {}) {
    if (!this.walletClient) {
      throw new Error("WalletClient is required for write operations");
    }
    const account = this.walletClient.account;
    if (!account) {
      throw new Error("WalletClient must have an account");
    }
    const value = options.value ?? 0n;
    const hash = await this.walletClient.writeContract({
      address: this.vaultAddress,
      abi: ElitraVault_default,
      functionName: "manage",
      args: [target, data, value],
      account,
      gas: options.gasLimit,
      chain: this.walletClient.chain
    });
    return {
      hash,
      data
    };
  }
  /**
   * Call the manageBatch function to execute multiple arbitrary calls sequentially from the vault
   *
   * @param targets - Array of target contract addresses
   * @param data - Array of encoded function call data
   * @param values - Array of ETH values to send with each call
   * @param options - ManageBatch options
   * @returns Transaction hash
   */
  async manageBatch(targets, data, values, options = {}) {
    if (!this.walletClient) {
      throw new Error("WalletClient is required for write operations");
    }
    const account = this.walletClient.account;
    if (!account) {
      throw new Error("WalletClient must have an account");
    }
    const hash = await this.walletClient.writeContract({
      address: this.vaultAddress,
      abi: ElitraVault_default,
      functionName: "manageBatch",
      args: [targets, data, values],
      account,
      gas: options.gasLimit,
      chain: this.walletClient.chain
    });
    return {
      hash
    };
  }
  /**
   * Update the vault's balance with new aggregated balance
   * Requires authorization
   *
   * @param newAggregatedBalance - New total balance across all protocols
   * @returns Transaction hash
   */
  async updateBalance(newAggregatedBalance) {
    if (!this.walletClient) {
      throw new Error("WalletClient is required for write operations");
    }
    const account = this.walletClient.account;
    if (!account) {
      throw new Error("WalletClient must have an account");
    }
    const hash = await this.walletClient.writeContract({
      address: this.vaultAddress,
      abi: ElitraVault_default,
      functionName: "updateBalance",
      args: [newAggregatedBalance],
      account,
      chain: this.walletClient.chain
    });
    return hash;
  }
  /**
   * Pause the vault (requires authorization)
   */
  async pause() {
    if (!this.walletClient) {
      throw new Error("WalletClient is required for write operations");
    }
    const account = this.walletClient.account;
    if (!account) {
      throw new Error("WalletClient must have an account");
    }
    const hash = await this.walletClient.writeContract({
      address: this.vaultAddress,
      abi: ElitraVault_default,
      functionName: "pause",
      account,
      chain: this.walletClient.chain
    });
    return hash;
  }
  /**
   * Unpause the vault (requires authorization)
   */
  async unpause() {
    if (!this.walletClient) {
      throw new Error("WalletClient is required for write operations");
    }
    const account = this.walletClient.account;
    if (!account) {
      throw new Error("WalletClient must have an account");
    }
    const hash = await this.walletClient.writeContract({
      address: this.vaultAddress,
      abi: ElitraVault_default,
      functionName: "unpause",
      account,
      chain: this.walletClient.chain
    });
    return hash;
  }
  /**
   * Fulfill a pending redemption request
   * 
   * @param receiver - Address to receive the assets
   * @param shares - Amount of shares to fulfill
   * @param assets - Amount of assets to redeem
   * @returns Transaction hash
   */
  async fulfillRedeem(receiver, shares, assets) {
    if (!this.walletClient) {
      throw new Error("WalletClient is required for write operations");
    }
    const account = this.walletClient.account;
    if (!account) {
      throw new Error("WalletClient must have an account");
    }
    const hash = await this.walletClient.writeContract({
      chain: this.publicClient.chain,
      address: this.vaultAddress,
      abi: ElitraVault_default,
      functionName: "fulfillRedeem",
      args: [receiver, shares, assets],
      account
    });
    return hash;
  }
  // ========================================= UTILITY METHODS =========================================
  /**
   * Get the vault address
   */
  getVaultAddress() {
    return this.vaultAddress;
  }
  /**
   * Set a new wallet client
   */
  setWalletClient(walletClient) {
    this.walletClient = walletClient;
  }
};

// src/utils.ts
var import_viem2 = require("viem");
function encodeManageCall(abi, functionName, args) {
  return (0, import_viem2.encodeFunctionData)({
    abi: (0, import_viem2.parseAbi)(abi),
    functionName,
    args
  });
}
function encodeApprove(spender, amount) {
  return encodeManageCall(
    ["function approve(address spender, uint256 amount) returns (bool)"],
    "approve",
    [spender, amount]
  );
}
function encodeTransfer(to, amount) {
  return encodeManageCall(
    ["function transfer(address to, uint256 amount) returns (bool)"],
    "transfer",
    [to, amount]
  );
}
function encodeERC4626Deposit(assets, receiver) {
  return encodeManageCall(
    ["function deposit(uint256 assets, address receiver) returns (uint256)"],
    "deposit",
    [assets, receiver]
  );
}
function encodeERC4626Withdraw(assets, receiver, owner) {
  return encodeManageCall(
    ["function withdraw(uint256 assets, address receiver, address owner) returns (uint256)"],
    "withdraw",
    [assets, receiver, owner]
  );
}
function convertToShares(assets, totalAssets, totalSupply) {
  if (totalSupply === 0n) {
    return assets;
  }
  return assets * totalSupply / totalAssets;
}
function convertToAssets(shares, totalAssets, totalSupply) {
  if (totalSupply === 0n) {
    return 0n;
  }
  return shares * totalAssets / totalSupply;
}
function calculateAPY(oldPPS, newPPS, timeDelta) {
  if (oldPPS === 0n || timeDelta === 0n) {
    return 0;
  }
  const priceChange = Number(newPPS - oldPPS);
  const oldPrice = Number(oldPPS);
  const secondsPerYear = 365.25 * 24 * 60 * 60;
  const timeInSeconds = Number(timeDelta);
  const periodReturn = priceChange / oldPrice;
  const periodsPerYear = secondsPerYear / timeInSeconds;
  const apy = (Math.pow(1 + periodReturn, periodsPerYear) - 1) * 100;
  return apy;
}
function formatShares(shares, decimals = 18, precision = 4) {
  const divisor = 10n ** BigInt(decimals);
  const whole = shares / divisor;
  const remainder = shares % divisor;
  const remainderStr = remainder.toString().padStart(decimals, "0");
  const decimalPart = remainderStr.slice(0, precision);
  if (precision === 0 || BigInt(decimalPart) === 0n) {
    return whole.toString();
  }
  return `${whole}.${decimalPart}`;
}
function parseAmount(amount, decimals = 18) {
  const [whole, fraction = ""] = amount.split(".");
  const paddedFraction = fraction.padEnd(decimals, "0").slice(0, decimals);
  return BigInt(whole + paddedFraction);
}

// src/index.ts
var import_viem3 = require("viem");
// Annotate the CommonJS export names for ESM import in node:
0 && (module.exports = {
  ElitraClient,
  calculateAPY,
  convertToAssets,
  convertToShares,
  encodeApprove,
  encodeERC4626Deposit,
  encodeERC4626Withdraw,
  encodeManageCall,
  encodeTransfer,
  formatShares,
  formatUnits,
  parseAmount,
  parseUnits
});
