// SPDX-License-Identifier: MIT
pragma solidity >=0.5.16;

import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';
import './interfaces/IERC20.sol';
import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';
import "hardhat/console.sol";

interface IUniswapV2Callee {
    function uniswapV2Call(
        address sender,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external; 
}

contract Flashswap is IUniswapV2Callee {
    address private TokenB;
    address private TokenC;
    address private UniswapV2Factory;
    address private Uniswaprouter;
    constructor (address  _token,address _token1, address _factory,address _router) public {
        TokenB = _token;
        TokenC =_token1;
        UniswapV2Factory = _factory;
        Uniswaprouter=_router;
    }

    // we'll call this function to call to call FLASHLOAN on uniswap
    function testFlashSwap(address _tokenBorrow, uint256 _amount) external {
        // check the pair contract for token borrow and TokenA exists
        address pair = IUniswapV2Factory(UniswapV2Factory).getPair(
            _tokenBorrow,
            TokenB
        );
        require(pair != address(0), "!pair");

        // right now we dont know tokenborrow belongs to which token
        address token0 = IUniswapV2Pair(pair).token0();
        address token1 = IUniswapV2Pair(pair).token1();

        // as a result, either amount0out will be equal to 0 or amount1out will be
        uint256 amount0Out = _tokenBorrow == token0 ? _amount : 0;
        uint256 amount1Out = _tokenBorrow == token1 ? _amount : 0;

        
        console.log("amount of TokenA before flash=",IERC20(_tokenBorrow).balanceOf(address(this)));
        console.log("amount of TokenB before flash=",IERC20(TokenB).balanceOf(address(this)));
        console.log("amount of TokenC before flash=",IERC20(TokenC).balanceOf(address(this)));

        bytes memory data = abi.encode(_tokenBorrow, _amount,TokenB,TokenC);
        // last parameter tells whether its a normal swap or a flash swap
        IUniswapV2Pair(pair).swap(amount0Out, amount1Out, address(this), data);
        // adding data triggers a flashloan
    }

    // in return of flashloan call, uniswap will return with this function
    // providing us the token borrow and the amount
    // we also have to repay the borrowed amt plus some fees
    function uniswapV2Call(
        address _sender,
        uint256 _amount0,
        uint256 _amount1,
        bytes calldata _data
    ) external override  {
        // check msg.sender is the pair contract
        // take address of token0 n token1
        address token0 = IUniswapV2Pair(msg.sender).token0();
        address token1 = IUniswapV2Pair(msg.sender).token1();
        // call uniswapv2factory to getpair 
        address pair = IUniswapV2Factory(UniswapV2Factory).getPair(token0, token1);
        require(msg.sender == pair, "Not Pair");

        // check sender holds the address who initiated the flash loans
        require(_sender == address(this), "Not Sender");

        (address tokenBorrow, uint amount,address tok2,address tok3) = abi.decode(_data, (address, uint,address,address));

        uint amtrec=(IERC20(tokenBorrow).balanceOf(address(this)));
        console.log("Amount of TokenA received after flash=",amtrec);

        address[] memory t = new address[](2);
        t[0]=tokenBorrow;
        t[1]=tok3;
        IERC20(tokenBorrow).approve(Uniswaprouter, amtrec);
        uint[] memory amt= IUniswapV2Router02(Uniswaprouter).swapExactTokensForTokens(amtrec,amtrec,t,address(this),1769000000);
        console.log("Amounts=",amt[0],amt[1]);
        console.log("Amount of TokenC received after swap=",(IERC20(tok3).balanceOf(address(this))));

        address[] memory t1 = new address[](2);
        t1[0]=tok3;
        t1[1]=tok2;
        IERC20(tok3).approve(Uniswaprouter, amt[1]);
        {uint[] memory arr=IUniswapV2Router02(Uniswaprouter).getAmountsOut(amt[1],t1);
        console.log("Amounts",arr[0],arr[1]);
        uint[] memory amt1=IUniswapV2Router02(Uniswaprouter).swapExactTokensForTokens(amt[1],amt[1],t1,address(this),1769000000);
         console.log("After C-B swap",amt1[0],amt1[1]);
         console.log("Amount of B Token received after swap",amt1[1]);}

        // about 0.3% fees, +1 to round up
       {uint fee = ((amount * 3) / 997) + 1;
        
        t1[0]=tokenBorrow;
        t1[1]=tok2;
        uint[] memory arr=IUniswapV2Router02(Uniswaprouter).getAmountsIn(amount,t1);
        console.log("Get amountIn for swap A-B",arr[0],arr[1]);
        uint amountToRepay = arr[0] + fee;
        IERC20(tok2).transfer(pair, amountToRepay);}
    }
}