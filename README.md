# Exness MT5 PA/SMC Trading EA

Experimental Expert Advisor prototype. It is **not a proven or production-ready trading system** and has not yet been compiled or backtested in MetaTrader 5.

## Strategy (v0.20)

An original multi-timeframe ruleset informed by public Price Action concepts. It is not a copy of Pip Lord and is not affiliated with Pip Lord.

- **H1 trend:** 50/200 EMA alignment; last closed H1 close must be on the trend side of the fast EMA.
- **M15 structure:** a closed candle must break the recent range and close in the breakout direction (a simplified BOS rule).
- **M15 displacement:** BOS candle body must be at least 0.15 ATR by default.
- **FVG:** searches for a three-candle imbalance formed within the last five closed M15 bars.
- **Order-block proxy:** most recent opposite-colour candle in the lookback; its range must overlap the FVG.
- **M5 trigger:** last closed M5 candle must touch the overlapping zone and close in the direction of the H1 bias.
- **Optional tick-volume filter:** disabled by default until it is calibrated on Exness data.
- **Exit:** stop beyond the recent M15 swing / zone and target at a configurable reward/risk multiple.

This is a rules-based approximation, not institutional order-flow data. CHoCH and the promotional M/W/V patterns are not implemented. Exact definitions and independently verified performance have not been established, so those patterns must not be added as vague labels.

## Risk controls

- Default risk per trade: 0.25% of equity.
- Default reward/risk: 2:1.
- Default daily equity loss limit: 2% from the stored day-start equity; once reached, new entries remain locked until the next broker-server day, including after EA restart.
- One open position per symbol and magic number.
- Spread filter, broker stop-distance check, volume-step normalization and server-retcode validation.
- Lot sizing uses `OrderCalcProfit` for a one-lot loss estimate in account currency. If the minimum broker lot would exceed the requested risk, the EA skips the trade rather than rounding risk upward.
- No martingale, grid, averaging down or recovery sizing.

**Daily-limit caveat:** the start-of-day equity baseline is saved in a terminal global variable, so restarting the EA during the same terminal installation should preserve it. If the EA is attached for the first time partway through a day, that attachment equity becomes the baseline. The daily guard latches a lockout for new entries; it does not forcibly close open positions and cannot guarantee a maximum account loss.

## Initial demo configuration

- Symbol: exact Exness EURUSD symbol (check for suffix).
- Entry timeframe: M5.
- Setup timeframe: M15.
- Trend timeframe: H1.
- Risk: 0.25%.
- Reward/risk: 2.0.
- Maximum daily equity loss: 2%.
- Maximum positions: 1.
- Tick-volume filter: off initially.
- Trading-hours filter: off until Exness server-time offset is verified.

## Install and test

1. Use MetaTrader 5 **desktop** and open MetaEditor (F4).
2. Put `Experts/Exness_PA_SMC_EA.mq5` in `MQL5/Experts/`.
3. Compile in MetaEditor. Resolve every compiler error and review warnings.
4. In Strategy Tester, select the exact Exness EURUSD symbol and **Every tick based on real ticks**.
5. Include realistic spread, commission, swap and execution assumptions.
6. Test multiple market regimes and a separate out-of-sample period.
7. Forward-test on an Exness demo account before considering any real use.

## Required validation before live trading

- Confirm the EA compiles on the installed MT5 build.
- Verify lot size manually against Exness tick size, tick value, contract size and account currency.
- Verify SL/TP acceptance, stop-level constraints, spread, slippage, and order retcodes.
- Record number of trades, net profit after costs, profit factor, expectancy, maximum drawdown, consecutive losses and exposure.
- Repeat on unseen historical data and forward demo. A profitable backtest does not establish future profitability.

## Status

**v0.20 — code updated, not yet compiled or backtested.** No profitability claim is made.