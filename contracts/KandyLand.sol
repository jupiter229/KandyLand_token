/// @title KandyLand Official Token
/// @author @jupiter229
/// @notice ERC20 token with 2% BUY and 3% SELL taxes, and 1% acquisitions/marketing, 3% liquidity, and 1% dev/team fees

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract KandyLand is ERC20, Ownable {
    uint256 private constant MAX = ~uint256(0);
    uint256 private constant _totalSupply = 1000000000 * 10 ** 18; // 1 billion tokens
    uint256 private _tFeeTotal;

    uint256 public buyTax = 2;
    uint256 public sellTax = 3;
    uint256 public acquisitionMarketingFee = 1;
    uint256 public liquidityFee = 3;
    uint256 public devTeamFee = 1;

    constructor() ERC20("KandyLand", "KL") {
        _mint(msg.sender, _totalSupply);
    }

    function totalSupply() public pure override returns (uint256) {
        return _totalSupply;
    }

    function decimals() public pure override returns (uint8) {
        return 18;
    }

    function getOwner() public view returns (address) {
        return owner();
    }

    function balanceOf(address account) public view override returns (uint256) {
        return super.balanceOf(account);
    }

    function transfer(
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(
        address owner,
        address spender
    ) public view override returns (uint256) {
        return super.allowance(owner, spender);
    }

    function approve(
        address spender,
        uint256 amount
    ) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()] - amount
        );
        _transfer(sender, recipient, amount);
        return true;
    }

    function excludeFromFee(address account) public onlyOwner {
        // TODO: implement if needed
    }

    function includeInFee(address account) public onlyOwner {
        // TODO: implement if needed
    }

    function setTaxRates(
        uint256 _buyTax,
        uint256 _sellTax,
        uint256 _acquisitionMarketingFee,
        uint256 _liquidityFee,
        uint256 _devTeamFee
    ) public onlyOwner {
        buyTax = _buyTax;
        sellTax = _sellTax;
        acquisitionMarketingFee = _acquisitionMarketingFee;
        liquidityFee = _liquidityFee;
        devTeamFee = _devTeamFee;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal {
        require(sender != address(0), "transfer from the zero address");
        require(recipient != address(0), "transfer to the zero address");
        require(amount > 0, "transfer amount must be greater than zero");

        uint256 transferAmount = amount;
        uint256 totalTax = 0;

        if (sender == owner()) {
            totalTax = buyTax;
        } else {
            totalTax = sellTax;
        }

        uint256 acquisitionMarketingAmount = (amount *
            acquisitionMarketingFee) / 100;
        uint256 liquidityAmount = (amount * liquidityFee) / 100;
        uint256 devTeamAmount = (amount * devTeamFee) / 100;
        uint256 taxAmount = (amount * totalTax) / 100;
        uint256 tokensToTransfer = amount -
            acquisitionMarketingAmount -
            liquidityAmount -
            devTeamAmount -
            taxAmount;
        require(
            tokensToTransfer > 0,
            "transfer amount after fees must be greater than zero"
        );

        if (totalTax > 0) {
            _takeTax(sender, taxAmount, totalTax);
        }

        _transfer(sender, address(this), acquisitionMarketingAmount);
        _transfer(sender, address(this), liquidityAmount);

        if (devTeamAmount > 0) {
            _transfer(sender, address(this), devTeamAmount);
            _transfer(address(this), owner(), devTeamAmount);
        }

        _transfer(sender, recipient, tokensToTransfer);
    }

    function _takeTax(
        address sender,
        uint256 taxAmount,
        uint256 totalTax
    ) internal {
        if (totalTax == buyTax) {
            _transfer(sender, address(this), taxAmount);
            _tFeeTotal += taxAmount;
        } else if (totalTax == sellTax) {
            uint256 liquidityAmount = taxAmount / 2;
            _transfer(sender, address(this), liquidityAmount);
            _tFeeTotal += liquidityAmount;
        }
    }

    function getTotalTaxFees() public view returns (uint256) {
        return _tFeeTotal;
    }

    function withdrawTokens(
        address tokenAddress,
        address recipient,
        uint256 amount
    ) public onlyOwner {
        require(
            tokenAddress != address(this),
            "cannot withdraw KandyLand tokens"
        );
        IERC20(tokenAddress).transfer(recipient, amount);
    }

    function withdrawETH(
        address payable recipient,
        uint256 amount
    ) public onlyOwner {
        recipient.transfer(amount);
    }

    function renounceOwnership() public override onlyOwner {
        revert("renouncing ownership is not allowed");
    }
}
