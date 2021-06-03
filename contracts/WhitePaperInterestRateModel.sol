pragma solidity ^0.5.16;

import "./InterestRateModel.sol";
import "./SafeMath.sol";

/**
  * @title Venus's WhitePaperInterestRateModel Contract
  * @author Venus
  * @notice The parameterized model described in section 2.4 of the original Venus Protocol whitepaper
  */
//利率模型白皮书
contract WhitePaperInterestRateModel is InterestRateModel {
    using SafeMath for uint;

    event NewInterestParams(uint baseRatePerBlock, uint multiplierPerBlock);

    /**
     * @notice The approximate number of blocks per year that is assumed by the interest rate model
     * 利率模型所假定的每年区块的近似数量
     */
    uint public constant blocksPerYear = 60 * 60 * 24 * 365 / 3; // (assuming 3s blocks)假设3 s块

    /**
     * @notice The multiplier of utilization rate that gives the slope of the interest rate
     */
    uint public multiplierPerBlock;

    /**
     * @notice The base interest rate which is the y-intercept when utilization rate is 0
     */
    uint public baseRatePerBlock;

    /**
     * @notice Construct an interest rate model
     * @param baseRatePerYear The approximate target base APR, as a mantissa (scaled by 1e18)
     * @param multiplierPerYear The rate of increase in interest rate wrt utilization (scaled by 1e18)
  
     */
     /*
        * @notice构造一个利率模型
    * @param baseRatePerYear近似的目标基础APR，作为尾数(按1e18比例缩放)
       * @param multiplerperyear利率的增长率wrt利用率(按1e18比例缩放)
     */
    constructor(uint baseRatePerYear, uint multiplierPerYear) public {
        baseRatePerBlock = baseRatePerYear.div(blocksPerYear); //根据年利率 计算每个区块下利率增长 
        multiplierPerBlock = multiplierPerYear.div(blocksPerYear); //加了xvs奖励多出来的利率增持 （每个区块）   

        emit NewInterestParams(baseRatePerBlock, multiplierPerBlock);
    }

    /**
     * @notice Calculates the utilization rate of the market: `borrows / (cash + borrows - reserves)`
     * @param cash The amount of cash in the market
     * @param borrows The amount of borrows in the market
     * @param reserves The amount of reserves in the market (currently unused)
     * @return The utilization rate as a mantissa between [0, 1e18]
     */
     /*
     * @notice计算当前每个区块的借款利率，使用市场预期的错误代码
        * @param cash市场上的现金数量
        * @param borrowing市场上的借款量
        * @param reserves市场上的储备数量
        * @return以尾数为单位的每块借款利率百分比(按1e18比例计算)
     */
    function utilizationRate(uint cash, uint borrows, uint reserves) public pure returns (uint) {
        // Utilization rate is 0 when there are no borrows
        if (borrows == 0) {
            return 0;
        }

        return borrows.mul(1e18).div(cash.add(borrows).sub(reserves));
    }

    /**
     * @notice Calculates the current borrow rate per block, with the error code expected by the market
     * @param cash The amount of cash in the market
     * @param borrows The amount of borrows in the market
     * @param reserves The amount of reserves in the market
     * @return The borrow rate percentage per block as a mantissa (scaled by 1e18)
     */
     /*
        * @notice计算当前每个区块的借款利率，使用市场预期的错误代码
        * @param cash市场上的现金数量
        * @param borrowing市场上的借款量
        * @param reserves市场上的储备数量
        * @return以尾数为单位的每块借款利率百分比(按1e18比例计算)
     */
    function getBorrowRate(uint cash, uint borrows, uint reserves) public view returns (uint) {
        uint ur = utilizationRate(cash, borrows, reserves);
        return ur.mul(multiplierPerBlock).div(1e18).add(baseRatePerBlock);
        // 借款利率  = 市场利用率 * 每块xvs奖励奖励奖励 + 基础利率
    }

    /**
     * @notice Calculates the current supply rate per block
     * @param cash The amount of cash in the market
     * @param borrows The amount of borrows in the market
     * @param reserves The amount of reserves in the market
     * @param reserveFactorMantissa The current reserve factor for the market
     * @return The supply rate percentage per block as a mantissa (scaled by 1e18)
     * 
     */
     /*
        * @notice计算每个block的当前供应率
        * @param cash市场上的现金数量
        * @param borrowing市场上的借款量
        * @param reserves市场上的储备数量
        * @param reserveFactorMantissa当前市场的储备因子
        * @return以尾数表示的每个区块的供应率百分比(按1e18比例计算)
     */
    function getSupplyRate(uint cash, uint borrows, uint reserves, uint reserveFactorMantissa) public view returns (uint) {
        uint oneMinusReserveFactor = uint(1e18).sub(reserveFactorMantissa);
        uint borrowRate = getBorrowRate(cash, borrows, reserves);
        uint rateToPool = borrowRate.mul(oneMinusReserveFactor).div(1e18);
        return utilizationRate(cash, borrows, reserves).mul(rateToPool).div(1e18);
        //借出利率 = 市场利用率 * （借款利率 / 1减去储备系数）
    }
}
