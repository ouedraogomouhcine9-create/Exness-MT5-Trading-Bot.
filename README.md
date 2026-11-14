# Exness MT5 PA/SMC Trading EA

This repository contains an **experimental Expert Advisor prototype**, not a proven or production-ready trading system.

## Strategy concept

An original multi-timeframe ruleset informed by publicly described Price Action concepts (not a copy of Pip Lord and not affiliated with Pip Lord):

- **H1 trend filter:** 50/200 EMA alignment and close relative to the fast EMA.
- **M15 setup:** close beyond a recent range (BOS proxy), followed by a three-candle Fair Value Gap.
- **Order-block proxy:** most recent opposite-colour candle in the lookback window. The EA currently requires overlap between this zone and the FVG.
- **M5 trigger:** a closed candle touches the overlapping zone and closes in the direction of the H1 bias.
- **Exit:** stop beyond the recent M15 swing / zone and take-profit at a configurable risk-reward multiple.

The M/W/V reversal formations sometimes described in promotional material are **not implemented**: their exact rules and independently verified performance have not been established. They should not be added as vague pattern labels.

## Risk controls

- Default risk per trade: 0.25% of equity.
- Default reward/risk: 2:1.
- Default maximum daily equity loss: 2% from the EA's recorded day-start equity.
- One open position at a time per symbol and magic number.
- Spread filter, broker stop-distance check, volume normalization.
- No martingale, grid, averaging down, or recovery sizing.

**Important limitations:** day-start equity is held in memory and resets if the EA is restarted; this prototype blocks new entries after the daily loss threshold but does not forcibly close an existing position. Run it on a dedicated demo account and do not treat the daily guard as a guaranteed account-level loss limit.

## Install

1. Open MetaTrader 5 desktop.
2. Open MetaEditor (F4).
3. Copy `Experts/Exness_PA_SMC_EA.mq5` into the corresponding `MQL5/Experts/` folder, or open the file from MetaEditor.
4. Compile. Resolve any broker/build-specific errors before testing.
5. In MT5 Strategy Tester, choose the exact Exness symbol (including any suffix), **Every tick based on real ticks**, and realistic commission/spread settings.
6. Test several market regimes, then use a separate out-of-sample period. Only after that, forward-test on demo.

## First test configuration

- Symbol: Exness EURUSD (verify exact symbol name).
- Chart / entry timeframe: M5.
- Trend timeframe: H1.
- Setup timeframe: M15.
- Risk: 0.25% per trade.
- Reward/risk: 2.0.
- Max daily loss: 2.0%.
- Max positions: 1.

Broker server time is used for optional trading hours. Leave the time filter disabled until the broker's server-time offset is verified.

## Validation checklist

- Compile in the user's installed MT5/MetaEditor build.
- Verify calculated lot size against tick value, tick size, contract size, and account currency on Exness demo.
- Check behaviour on 3/5-digit quotes, variable spread, commission, gaps, and market execution.
- Review trade logs and ensure the SL/TP are accepted by the broker.
- Record trade count, profit factor, expectancy, maximum drawdown, consecutive losses, and net result after costs.
- Repeat on unseen data and forward demo. A profitable backtest alone does not establish future profitability.

## Status

Prototype v0.10. Not yet compiled in MetaEditor or backtested against Exness historical data. No profitability claim is made.
