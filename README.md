# MT4-EA

This repository contains an example MetaTrader 4 Expert Advisor designed for spread betting accounts. The EA trades every symbol visible in your Market Watch window and follows a simple trend strategy.

## Expert Advisor

`MQL4/Experts/MultiPairSpreadEA.mq4` automatically collects all Market Watch symbols and checks the trend on higher timeframes:

1. **Weekly trend** – price relative to the 10‑period SMA.
2. **Daily confirmation** – 50 EMA aligned above or below the 200 EMA.
3. **Hourly entry** – price touches the 20 EMA (within a configurable buffer) using live Bid/Ask with an RSI filter.
4. **Exit strategy** – half the position closes at 1×ATR profit, the remainder trails with an ATR-based stop.

## Usage

1. Copy the contents of the `MQL4` folder into your MetaTrader 4 `MQL4` directory.
2. Compile `MultiPairSpreadEA.mq4` using the MetaEditor.

3. Attach the expert advisor to any chart. The EA will trade all Market Watch symbols using the default parameters (lot size, ATR period, etc.) which can be adjusted in the inputs. Trading logic executes every 15 minutes using a timer and orders are placed via `OrderSend`.

This is only a minimal example and should be tested on a demo account before any live deployment.
