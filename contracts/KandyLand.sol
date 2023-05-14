// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

contract KandyLand is ERC20, Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using Address for address;

    uint256 private constant TOTAL_SUPPLY = 1_000_000_000 * 10 ** 18;

    uint256 public constant BUY_TAX = 2;
    uint256 public constant SELL_TAX = 3;
    uint256 public constant ACQUISITIONS_MARKETING_TAX = 1;
    uint256 public constant LIQUIDITY_TAX = 3;
    uint256 public constant DEV_TEAM_TAX = 1;

    address public acquisitionsMarketingReceiver;
    address public liquidityReceiver;
    address public devTeamReceiver;

    IUniswapV2Router02 public immutable uniswapV2Router;
    IUniswapV2Pair public pairContract;

    address public uniswapV2Pair;

    constructor(
        address _router,
        address _acquisitionsMarketingReceiver,
        address _liquidityReceiver,
        address _devTeamReceiver
    ) ERC20("KandyLand", "KL") {
        _mint(_msgSender(), TOTAL_SUPPLY);

        uniswapV2Router = IUniswapV2Router02(_router);

        address _uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory())
            .createPair(address(this), uniswapV2Router.WETH());
        pairContract = IUniswapV2Pair(_uniswapV2Pair);

        acquisitionsMarketingReceiver = _acquisitionsMarketingReceiver;
        liquidityReceiver = _liquidityReceiver;
        devTeamReceiver = _devTeamReceiver;
    }

    function transfer(
        address to,
        uint256 value
    ) external override returns (bool) {
        _transferFrom(msg.sender, to, value);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external override returns (bool) {
        _transferFrom(from, to, value);
        return true;
    }

    function _transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) internal returns (bool) {
        uint256 netAmount = takeFee(sender, recipient, amount);

        _transfer(sender, recipient, netAmount);
        _approve(
            sender,
            _msgSender(),
            allowance(sender, _msgSender()).sub(
                amount,
                "ERC20: transfer amount exceeds allowance"
            )
        );

        return true;
    }

    function takeFee(
        address sender,
        address recipient,
        uint256 amount
    ) internal returns (uint256) {
        uint256 _sellOrBuyTax;
        if (sender == address(pairContract)) {
            _sellOrBuyTax = calculateTax(amount, BUY_TAX);
        } else if (recipient == address(pairContract)) {
            _sellOrBuyTax = calculateTax(amount, SELL_TAX);
        }

        uint256 _marketingTax = calculateTax(
            amount,
            ACQUISITIONS_MARKETING_TAX
        );
        uint256 _liquidityTax = calculateTax(amount, LIQUIDITY_TAX);
        uint256 _devTeamTax = calculateTax(amount, DEV_TEAM_TAX);

        uint256 _netAmount = amount
            .sub(_sellOrBuyTax)
            .sub(_marketingTax)
            .sub(_liquidityTax)
            .sub(_devTeamTax);

        _transfer(sender, acquisitionsMarketingReceiver, _marketingTax);
        _transfer(sender, liquidityReceiver, _liquidityTax);
        _transfer(sender, devTeamReceiver, _devTeamTax);

        return _netAmount;
    }

    function calculateTax(
        uint256 amount,
        uint256 taxPercentage
    ) internal returns (uint256) {
        return amount.mul(taxPercentage).div(100);
    }

    function addLiquidity(
        uint256 tokenAmount,
        uint256 ethAmount
    ) external onlyOwner nonReentrant {
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0,
            0,
            owner(),
            block.timestamp
        );
    }

    receive() external payable {}
}
