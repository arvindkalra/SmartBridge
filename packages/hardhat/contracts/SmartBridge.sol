//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Use openzeppelin to inherit battle-tested implementations (ERC20, ERC721, etc)
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import { OApp, Origin, MessagingFee } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";

contract SmartBridge is OApp {
	IERC20 public token;
	// uint32 public destinationEndpointId = 40231; // For Morph HoleSky
	uint32 public destinationEndpointId = 40322; // For Arbitrum Sepolia

	bytes public options;

	constructor(
		address _tokenAddress,
		address _endpoint
	) OApp(_endpoint, msg.sender) Ownable(msg.sender) {
		token = IERC20(_tokenAddress);
	}

    /**
     * @notice Sends a message from the source to destination chain.
     * @param isInitiate Whether this is initiating a bridge or completing one.
     * @param amount The amount of tokens to bridge.
     * @param destinationAddress The address to receive tokens on the destination chain.
     */
    function send(
        bool isInitiate,
        uint256 amount,
        address destinationAddress
    ) internal {
        bytes memory _payload = abi.encode(isInitiate, amount, destinationAddress);
        
		if (isInitiate) {
			_lzSend(
				destinationEndpointId,
				_payload,
				options,
				MessagingFee(msg.value, 0),
				payable(msg.sender)
        	); 
		}
		else {
			_lzSend(
				destinationEndpointId,
				_payload,
				options,
				MessagingFee(msg.value, 0),
				payable(address(this))
			); 
		}

        
    }

    /**
     * @dev Called when data is received from the protocol. It overrides the equivalent function in the parent contract.
     * Protocol messages are defined as packets, comprised of the following parameters.
     * @param _origin A struct containing information about where the packet came from.
     * @param _guid A global unique identifier for tracking the packet.
     * @param payload Encoded message.
     */
    function _lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata payload,
        address,  // Executor address as specified by the OApp.
        bytes calldata  // Any extra data or options to trigger on receipt.
    ) internal override {
        // Decode the payload
        (bool isInitiate, uint256 amount, address destinationAddress) = abi.decode(payload, (bool, uint256, address));

        if(isInitiate) {
            // This is on chain B (destination chain)
            onBridgeInitiated(amount, destinationAddress);
        } else {
            // This is on chain A (source chain)
            onBridgeCompleted(amount, destinationAddress);
        }

        // Emit an event for the received cross-chain message
        emit CrossChainMessageReceived(uint16(_origin.srcEid), isInitiate, amount, destinationAddress);
    }

	// State Variables
	mapping(address => uint256) public liquidityProviders;

	event LiquidityAdded(address indexed provider, uint256 amount);
	event BridgeInitiated(address indexed initiator, uint256 amount);
	event BridgeCompleted(uint256 amount, address indexed receiver, address indexed liquidityProvider);

	event CrossChainMessageReceived(uint16 srcEid, bool isInitiate, uint256 amount, address destinationAddress);

	function addLiquidity(uint256 _amount) public {
		require(_amount > 0, "Amount must be greater than 0");
		require(token.balanceOf(msg.sender) >= _amount, "Insufficient balance");
		require(token.allowance(msg.sender, address(this)) >= _amount, "Insufficient allowance");

		// Transfer tokens from the sender to the contract
		bool success = token.transferFrom(msg.sender, address(this), _amount);
		require(success, "Token transfer failed");

		if (liquidityProviders[msg.sender] == 0) {
			liquidityProvidersList.push(msg.sender);
		}

		// Update the liquidity provider's balance
		liquidityProviders[msg.sender] += _amount;
	

		// Emit an event (optional, but recommended for transparency)
		emit LiquidityAdded(msg.sender, _amount);
	}

	function bridgeTokens(uint256 _amount) public payable {
		require(_amount > 0, "Amount must be greater than 0");
		require(token.balanceOf(msg.sender) >= _amount, "Insufficient balance");
		require(token.allowance(msg.sender, address(this)) >= _amount, "Insufficient allowance");

		// Transfer tokens from the sender to the contract
		bool success = token.transferFrom(msg.sender, address(this), _amount);
		require(success, "Token transfer failed");

		// Emit an event for the bridge initiation
		emit BridgeInitiated(msg.sender, _amount);

		// Call the send function
		send(true, _amount, msg.sender);
	}

	function onBridgeInitiated(uint256 _amount, address _receiver) public {
		require(_amount > 0, "Amount must be greater than 0");
		require(_receiver != address(0), "Invalid receiver address");

		// Find a liquidity provider with sufficient liquidity
		address liquidityProvider = findLiquidityProvider(_amount);
		require(liquidityProvider != address(0), "No liquidity provider with sufficient funds");

		// Deduct the amount from the chosen liquidity provider
		liquidityProviders[liquidityProvider] -= _amount;

		// Transfer tokens from the contract to the receiver
		require(token.transfer(_receiver, _amount), "Token transfer failed");

		// Emit an event for the completed bridge
		emit BridgeCompleted(_amount, _receiver, liquidityProvider);

		// Call the send function to inform the source chain about completion
		send(false, _amount, liquidityProvider);
	}

	function onBridgeCompleted(uint256 _amount, address _liquidityProvider) public {
		liquidityProviders[_liquidityProvider] += _amount;
	}

	// Add this helper function to find a suitable liquidity provider
	function findLiquidityProvider(uint256 _amount) internal view returns (address) {
		for (uint i = 0; i < liquidityProvidersList.length; i++) {
			address provider = liquidityProvidersList[i];
			if (liquidityProviders[provider] >= _amount) {
				return provider;
			}
		}
		return address(0); // Return zero address if no suitable provider found
	}

	// Add these at the contract level
	address[] public liquidityProvidersList;

	// Add this function to your SmartBridge contract

	function ownerWithdraw(uint256 _amount) public onlyOwner {
		require(_amount > 0, "Amount must be greater than 0");
		require(_amount <= token.balanceOf(address(this)), "Insufficient balance in contract");
		
		// Transfer tokens to the owner
		bool success = token.transfer(owner(), _amount);
		require(success, "Token transfer failed");
	}

	function setOptions(bytes memory _options) public onlyOwner {
		options = _options;
	}

	function deposit() external payable {}
}
