// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import "./IERC20.sol";

contract SampleToken is IERC20 {
  uint256 private _totalSupply; // total token
  //mapping[address] => _balances
  mapping(address => uint256) private _balances;
  //mapping[sender][spender] => _allowances
  mapping(address => mapping(address => uint256)) private _allowances;

  constructor() {
    _totalSupply = 1000000;
    _balances[msg.sender] = 1000000;
  }

  function totalSupply() public view override returns (uint256) {
    return _totalSupply;
  }

  function balanceOf(address account) public view override returns (uint256) {
    return _balances[account];
  }

  function transfer(address recipient, uint256 amount)
    public
    override
    returns (bool success)
  {
    require(_balances[msg.sender] >= amount);
    _balances[msg.sender] -= amount;
    _balances[recipient] += amount;
    emit Transfer(msg.sender, recipient, amount);
    return true;
  }

  function transferFrom(
    address sender,
    address recipient,
    uint256 amount
  ) public override returns (bool success) {
    require(_balances[sender] >= amount);
    require(_allowances[sender][msg.sender] >= amount);
    _balances[sender] -= amount;
    _balances[recipient] += amount;
    emit Transfer(sender, recipient, amount);
    return true;
}

  function approve(address spender, uint256 amount)
    public
    override
    returns (bool success)
  {
    _allowances[msg.sender][spender] = amount;
    emit Approval(msg.sender, spender, amount);
    return true;
  }

  function allowance(address owner, address spender)
    public
    view
    override
    returns (uint256 remaining)
  {
    return _allowances[owner][spender];
  }
}
