# MT4-EA

This repository contains an example MetaTrader 4 Expert Advisor designed for spread betting accounts. The EA trades every symbol visible in your Market Watch window and follows a simple trend strategy.

## Expert Advisor

`MQL4/Experts/MultiPairSpreadEA.mq4` automatically collects all Market Watch symbols and checks the trend on higher timeframes:

1. **Weekly trend** – price relative to the 20‑period SMA.
2. **Daily confirmation** – 20 EMA aligned above or below the 50 EMA.
3. **Hourly entry** – price pulls back to the 20 EMA with an RSI filter.

Stop loss and take profit are derived from the daily ATR (1.5× ATR for SL and 3× ATR for TP). Once price moves 1.5× ATR in profit, the stop is moved to break even. Lot size is calculated so that each trade risks **2% of the account balance** by default.

## Usage

1. Copy the contents of the `MQL4` folder into your MetaTrader 4 `MQL4` directory.
2. Compile `MultiPairSpreadEA.mq4` using the MetaEditor.
3. Attach the expert advisor to any chart. The EA will trade all Market Watch symbols using the default parameters (lot size, ATR period, etc.) which can be adjusted in the inputs. Trading logic executes every 15 minutes using a timer and orders are placed via `OrderSend`.

This is only a minimal example and should be tested on a demo account before any live deployment.
