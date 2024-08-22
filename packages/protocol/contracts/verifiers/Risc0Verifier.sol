// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@risc0/contracts/IRiscZeroVerifier.sol";
import "../common/EssentialContract.sol";
import "../common/LibStrings.sol";
import "../L1/ITaikoL1.sol";
import "./IVerifier.sol";
import "./libs/LibPublicInput.sol";

/// @title Risc0Verifier
/// @custom:security-contact security@taiko.xyz
contract Risc0Verifier is EssentialContract, IVerifier {
    // [32, 0, 0, 0] -- big-endian uint32(32) for hash bytes len
    bytes private constant FIXED_JOURNAL_HEADER = hex"20000000";

    /// @notice Trusted imageId mapping
    mapping(bytes32 imageId => bool trusted) public isImageTrusted;

    uint256[49] private __gap;

    /// @dev Emitted when a trusted image is set / unset.
    /// @param imageId The id of the image
    /// @param trusted True if trusted, false otherwise
    event ImageTrusted(bytes32 imageId, bool trusted);

    /// @dev Emitted when a proof is verified
    event ProofVerified(bytes32 metaHash, bytes32 publicInputHash);

    error RISC0_AGGREGATION_NOT_SUPPORTED();
    error RISC0_INVALID_IMAGE_ID();
    error RISC0_INVALID_PROOF();

    /// @notice Initializes the contract with the provided address manager.
    /// @param _owner The address of the owner.
    /// @param _rollupAddressManager The address of the AddressManager.
    function init(address _owner, address _rollupAddressManager) external initializer {
        __Essential_init(_owner, _rollupAddressManager);
    }

    /// @notice Sets/unsets an the imageId as trusted entity
    /// @param _imageId The id of the image.
    /// @param _trusted True if trusted, false otherwise.
    function setImageIdTrusted(bytes32 _imageId, bool _trusted) external onlyOwner {
        isImageTrusted[_imageId] = _trusted;

        emit ImageTrusted(_imageId, _trusted);
    }

    /// @inheritdoc IVerifier
    function verifyProof(Context[] calldata _ctxs, TaikoData.TierProof calldata _proof) external {
        // TODO: support multiple proofs
        if (_ctxs.length != 1) revert RISC0_AGGREGATION_NOT_SUPPORTED();

        for (uint256 i; i < _ctxs.length; ++i) {
            // Do not run proof verification to contest an existing proof
            if (_ctxs[i].isContesting) continue;

            // Decode will throw if not proper length/encoding
            (bytes memory seal, bytes32 imageId) = abi.decode(_proof.data, (bytes, bytes32));

            if (!isImageTrusted[imageId]) {
                revert RISC0_INVALID_IMAGE_ID();
            }

            bytes32 publicInputHash = LibPublicInput.hashPublicInputs(
                _ctxs[i].transition,
                address(this),
                address(0),
                _ctxs[i].prover,
                _ctxs[i].metaHash,
                taikoChainId()
            );

            // journalDigest is the sha256 hash of the hashed public input
            bytes32 journalDigest = sha256(bytes.concat(FIXED_JOURNAL_HEADER, publicInputHash));

            // call risc0 verifier contract
            (bool success,) = resolve(LibStrings.B_RISCZERO_GROTH16_VERIFIER, false).staticcall(
                abi.encodeCall(IRiscZeroVerifier.verify, (seal, imageId, journalDigest))
            );
            if (!success) {
                revert RISC0_INVALID_PROOF();
            }

            emit ProofVerified(_ctxs[i].metaHash, publicInputHash);
        }
    }

    function taikoChainId() internal view virtual returns (uint64) {
        return ITaikoL1(resolve(LibStrings.B_TAIKO, false)).getConfig().chainId;
    }
}
