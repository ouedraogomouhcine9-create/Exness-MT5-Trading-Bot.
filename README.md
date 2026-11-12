# Exness MT5 Trading Bot — Demo only

## First target
- Broker: Exness; platform: MetaTrader 5
- Symbol/timeframe: EURUSD M5
- Entry: market-structure breakout, retest and candle confirmation
- Confirmation: tick volume; optional FVG and order-block filters
- Risk: 0.25% equity per trade; target R:R 1:2
- Protection: automatic SL/TP, spread filter, one position at a time
- Safety: refuses to trade unless the account is a DEMO account

## Status
Initial Expert Advisor draft added under `MQL5/Experts/ExnessStructureBot.mq5`.
It has **not** yet been compiled or backtested. Do not use on a live account.

## Installation
Compilation and execution require MT5 desktop on Windows or a compatible Windows VPS. The Android MT5 app cannot run Expert Advisors. In MetaEditor, place the EA in `MQL5/Experts`, compile it, resolve any compiler errors, then backtest and forward-test on demo only.
