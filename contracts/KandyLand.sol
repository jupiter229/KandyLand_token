// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract KandyLand is ERC20, Ownable {
    using SafeMath for uint256;

    IUniswapV2Router02 public router;
    address public immutable pair;
    address public constant deadAddress = address(0xdead);

    struct Fee {
        uint16 marketingShare;
        uint16 liquidityShare;
        uint16 devShare;
    }

    bool private swapping;

    Fee public buyFee;
    Fee public sellFee;

    uint256 public swapTokensAtAmount;
    uint256 public maxBuyAmount;
    uint256 public maxSellAmount;
    uint256 public maxWalletAmount;

    uint16 private totalBuyFee;
    uint16 private totalSellFee;

    bool public swapEnabled;

    address payable _marketingWallet = payable(address(0x123));
    address payable _devWallet = payable(address(0x456));

    mapping(address => bool) private _isExcludedFromFees;
    mapping(address => bool) private _isBlacklisted;

    // store addresses that a automatic market maker pairs. Any transfer *to* these addresses
    // could be subject to a maximum transfer amount
    mapping(address => bool) public automatedMarketMakerPairs;

    event UpdateUniswapV2Router(
        address indexed newAddress,
        address indexed oldAddress
    );

    event ExcludeFromFees(address indexed account, bool isExcluded);
    event ExcludeMultipleAccountsFromFees(address[] accounts, bool isExcluded);
    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);

    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );

    modifier lockTheSwap() {
        swapping = true;
        _;
        swapping = false;
    }

    constructor() ERC20("KandyLand", "KL") {
        buyFee = Fee({marketingShare: 200, liquidityShare: 600, devShare: 200});
        totalBuyFee = 30;

        sellFee = Fee({
            marketingShare: 200,
            liquidityShare: 600,
            devShare: 200
        });
        totalSellFee = 20;

        IUniswapV2Router02 _router = IUniswapV2Router02(
            0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
        );
        // Create a uniswap pair for this new token
        address _pair = IUniswapV2Factory(_router.factory()).createPair(
            address(this),
            _router.WETH()
        );

        router = _router;
        pair = _pair;

        _setAutomatedMarketMakerPair(_pair, true);

        // exclude from paying fees or having max transaction amount
        excludeFromFees(owner(), true);
        excludeFromFees(address(this), true);

        swapEnabled = true;

        /*
            _mint is an internal function in ERC20.sol that is only called here,
            and CANNOT be called ever again
        */
        _mint(owner(), 1_000_000_000 * (10 ** 18));

        swapTokensAtAmount = totalSupply().mul(1).div(1000);
        maxBuyAmount = totalSupply();
        maxSellAmount = totalSupply();
        maxWalletAmount = totalSupply();
    }

    receive() external payable {}

    function decimals() public pure override returns (uint8) {
        return 18;
    }

    function updateUniswapV2Router(address newAddress) public onlyOwner {
        require(
            newAddress != address(router),
            "Token: The router already has that address"
        );
        emit UpdateUniswapV2Router(newAddress, address(router));
        router = IUniswapV2Router02(newAddress);
    }

    function excludeFromFees(address account, bool excluded) public onlyOwner {
        _isExcludedFromFees[account] = excluded;
        emit ExcludeFromFees(account, excluded);
    }

    function excludeMultipleAccountsFromFees(
        address[] calldata accounts,
        bool excluded
    ) public onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            _isExcludedFromFees[accounts[i]] = excluded;
        }
        emit ExcludeMultipleAccountsFromFees(accounts, excluded);
    }

    function setAutomatedMarketMakerPair(
        address _pair,
        bool value
    ) public onlyOwner {
        _setAutomatedMarketMakerPair(_pair, value);
    }

    function _setAutomatedMarketMakerPair(address _pair, bool value) private {
        automatedMarketMakerPairs[_pair] = value;
        emit SetAutomatedMarketMakerPair(_pair, value);
    }

    function setBuyFee(
        uint16 total,
        uint16 marketing,
        uint16 liquidity,
        uint16 dev
    ) external onlyOwner {
        require(marketing + dev + liquidity == 1000, "Token: Invalid buy fee");
        buyFee = Fee({
            marketingShare: marketing,
            liquidityShare: liquidity,
            devShare: dev
        });
        totalBuyFee = total;
    }

    function setSellFee(
        uint16 total,
        uint16 marketing,
        uint16 liquidity,
        uint16 dev
    ) external onlyOwner {
        require(marketing + dev + liquidity == 1000, "Token: Invalid sell fee");
        sellFee = Fee({
            marketingShare: marketing,
            liquidityShare: liquidity,
            devShare: dev
        });
        totalSellFee = total;
    }

    function setBlacklist(address account, bool value) external onlyOwner {
        _isBlacklisted[account] = value;
    }

    function setMaxWallet(uint256 value) external onlyOwner {
        maxWalletAmount = value;
    }

    function setMaxBuyAmount(uint256 value) external onlyOwner {
        maxBuyAmount = value;
    }

    function setMaxSellAmount(uint256 value) external onlyOwner {
        maxSellAmount = value;
    }

    function setSwapTokensAmount(uint256 value) external onlyOwner {
        swapTokensAtAmount = value;
    }

    function claimStuckTokens(address _token) external onlyOwner {
        require(_token != address(this), "No rugs");
        if (_token == address(0x0)) {
            payable(owner()).transfer(address(this).balance);
            return;
        }
        IERC20 erc20token = IERC20(_token);
        uint256 balance = erc20token.balanceOf(address(this));
        erc20token.transfer(owner(), balance);
    }

    function isExcludedFromFees(address account) public view returns (bool) {
        return _isExcludedFromFees[account];
    }

    function setWallet(address _marketing, address _dev) external onlyOwner {
        _marketingWallet = payable(_marketing);
        _devWallet = payable(_dev);
    }

    function setSwapEnabled(bool value) external onlyOwner {
        swapEnabled = value;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(
            !_isBlacklisted[from] && !_isBlacklisted[to],
            "Token: Blacklisted address"
        );
        if (amount == 0) {
            super._transfer(from, to, 0);
            return;
        }

        uint256 contractTokenBalance = balanceOf(address(this));
        bool overMinimumTokenBalance = contractTokenBalance >=
            swapTokensAtAmount;

        if (
            swapEnabled && !swapping && from != pair && overMinimumTokenBalance
        ) {
            contractTokenBalance = swapTokensAtAmount;

            uint256 swapTokens = contractTokenBalance
                .mul(buyFee.liquidityShare + sellFee.liquidityShare)
                .div(2000);
            swapAndLiquify(swapTokens);

            swapAndDistribute(contractTokenBalance - swapTokens);
        }

        bool takeFee = true;

        // if any account belongs to _isExcludedFromFee account then remove the fee
        if (_isExcludedFromFees[from] || _isExcludedFromFees[to]) {
            takeFee = false;
        }

        if (takeFee) {
            uint256 fees;

            if (!automatedMarketMakerPairs[to]) {
                require(
                    amount + balanceOf(to) <= maxWalletAmount,
                    "Wallet exceeds limit"
                );
            }

            if (automatedMarketMakerPairs[to]) {
                fees = totalSellFee;
                require(amount <= maxSellAmount, "Sell exceeds limit");
            } else if (automatedMarketMakerPairs[from]) {
                fees = totalBuyFee;
                require(amount <= maxBuyAmount, "Buy exceeds limit");
            }

            if (fees > 0) {
                uint256 feeAmount = amount.mul(fees).div(1000);
                amount = amount.sub(feeAmount);

                super._transfer(from, address(this), feeAmount);
            }
        }

        super._transfer(from, to, amount);
    }

    function swapAndDistribute(uint256 tokens) private lockTheSwap {
        uint256 totalShare = 2000 -
            buyFee.liquidityShare -
            sellFee.liquidityShare;
        uint256 initialBalance = address(this).balance;
        swapTokensForEth(tokens);
        uint256 newBalance = address(this).balance.sub(initialBalance);

        uint256 forMarketing = newBalance
            .mul(buyFee.marketingShare + sellFee.marketingShare)
            .div(totalShare);
        uint256 forDev = newBalance.mul(buyFee.devShare + sellFee.devShare).div(
            totalShare
        );

        _marketingWallet.transfer(forMarketing);
        _devWallet.transfer(forDev);
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(router), tokenAmount);

        // add the liquidity
        router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            deadAddress,
            block.timestamp
        );
    }

    function swapAndLiquify(uint256 tokens) private lockTheSwap {
        // split the contract balance into halves
        uint256 half = tokens.div(2);
        uint256 otherHalf = tokens.sub(half);

        uint256 initialBalance = address(this).balance;

        // swap tokens for ETH
        swapTokensForEth(half); // <- this breaks the ETH -> HATE swap when swap+liquify is triggered

        // how much ETH did we just swap into?
        uint256 newBalance = address(this).balance.sub(initialBalance);

        // add liquidity to uniswap
        addLiquidity(otherHalf, newBalance);

        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH();

        _approve(address(this), address(router), tokenAmount);

        // make the swap
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }
}
