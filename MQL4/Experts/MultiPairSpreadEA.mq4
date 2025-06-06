#property strict
#property description "Trend following multi-pair EA"

input double RiskPercent  = 2.0;    // % of account balance to risk per trade
input int    AtrPeriod     = 14;     // ATR calculation period
input double AtrSLFactor   = 1.5;    // Stop loss multiplier
input double AtrTPFactor   = 3.0;    // Take profit multiplier
input int    Slippage      = 3;      // Maximum slippage (deviation)
input int    MagicNumber   = 987654; // Magic number for orders
input double EmaProximityPips = 5.0; // EMA touch buffer in pips

string Symbols[];

double CalcRiskLot(string symbol, double slDistance);

int OnInit()
{
    int total = SymbolsTotal(true);
    if(total <= 0)
    {
        Print("No symbols found in Market Watch");
        return(INIT_FAILED);
    }
    ArrayResize(Symbols, total);
    for(int i=0; i<total; i++)
        Symbols[i] = SymbolName(i, true);

    // trade logic is run on a timer instead of every tick
    EventSetTimer(60*15); // check every 15 minutes

    return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
    EventKillTimer();
}

void OnTimer()
{
    for(int i=0; i<ArraySize(Symbols); i++)
    {
        string symbol = Symbols[i];
        if(!IsTradeAllowed(symbol)) continue;

        double atrDaily = iATR(symbol, PERIOD_D1, AtrPeriod, 0);
        if(atrDaily <= 0) continue;

        ManageBreakeven(symbol, atrDaily);
        if(HasOpenOrder(symbol)) continue;

        int dir = TrendDirection(symbol);
        if(dir == 0) continue;

        if(EntrySignal(symbol, dir))
            OpenTrade(symbol, dir, atrDaily);
    }
}

int TrendDirection(string symbol)
{
    double weeklyClose = iClose(symbol, PERIOD_W1, 1);
    double weeklySMA   = iMA(symbol, PERIOD_W1, 10, 0, MODE_SMA, PRICE_CLOSE, 1);
    if(weeklyClose==0 || weeklySMA==0) return 0;

    double dailyEMA50   = iMA(symbol, PERIOD_D1, 50, 0, MODE_EMA, PRICE_CLOSE, 1);
    double dailyEMA200  = iMA(symbol, PERIOD_D1, 200, 0, MODE_EMA, PRICE_CLOSE, 1);

    if(weeklyClose > weeklySMA && dailyEMA50 > dailyEMA200)
        return 1;   // long trend
    if(weeklyClose < weeklySMA && dailyEMA50 < dailyEMA200)
        return -1;  // short trend
    return 0;
}

bool EntrySignal(string symbol, int dir)
{
    double ema   = iMA(symbol, PERIOD_H1, 20, 0, MODE_EMA, PRICE_CLOSE, 0);
    double rsi   = iRSI(symbol, PERIOD_H1, 14, PRICE_CLOSE, 0);

    double bid   = SymbolInfoDouble(symbol, SYMBOL_BID);
    double ask   = SymbolInfoDouble(symbol, SYMBOL_ASK);

    double point  = MarketInfo(symbol, MODE_POINT);
    double buffer = EmaProximityPips * point;

    if(dir > 0)   // long
    {
        bool touch = (ask <= ema + buffer);
        if(touch && rsi > 50 && rsi < 70)
            return(true);
    }
    else if(dir < 0) // short
    {
        bool touch = (bid >= ema - buffer);
        if(touch && rsi < 50 && rsi > 30)
            return(true);
    }
    return(false);
}

void OpenTrade(string symbol, int dir, double atrDaily)
{
    int    digits = (int)MarketInfo(symbol, MODE_DIGITS);
    double price  = (dir>0) ? MarketInfo(symbol, MODE_ASK) : MarketInfo(symbol, MODE_BID);
    double sl     = (dir>0) ? price - atrDaily*AtrSLFactor : price + atrDaily*AtrSLFactor;

    double slDistance = MathAbs(price - sl);
    double lot    = CalcRiskLot(symbol, slDistance);
    double half   = lot/2.0;

    price = NormalizeDouble(price, digits);
    sl    = NormalizeDouble(sl, digits);
    double tpPartial = (dir>0) ? price + atrDaily : price - atrDaily;
    tpPartial = NormalizeDouble(tpPartial, digits);

    int type   = (dir>0) ? OP_BUY : OP_SELL;

    // first half position with 1 ATR target
    int ticket = OrderSend(symbol, type, half, price, Slippage, sl, tpPartial,
                           "TrendEA", MagicNumber, 0, clrNONE);
    if(ticket < 0)
        Print("OrderSend failed on ", symbol, " error ", GetLastError());

    // second half position for trailing exit
    ticket = OrderSend(symbol, type, half, price, Slippage, sl, 0,
                       "TrendEA", MagicNumber, 0, clrNONE);
    if(ticket < 0)
        Print("OrderSend failed on ", symbol, " error ", GetLastError());
}

void ManageBreakeven(string symbol, double atrDaily)
{
    for(int i=OrdersTotal()-1; i>=0; i--)
    {
        if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
            if(OrderSymbol()==symbol && OrderMagicNumber()==MagicNumber)
            {
                double open   = OrderOpenPrice();
                double sl     = OrderStopLoss();
                int digits    = (int)MarketInfo(symbol, MODE_DIGITS);
                double stopLevel = MarketInfo(symbol, MODE_STOPLEVEL) *
                                   MarketInfo(symbol, MODE_POINT);

                if(OrderType()==OP_BUY)
                {
                    if(OrderTakeProfit()==0)
                    {
                        if(Bid - open >= atrDaily)
                        {
                            double newSL = NormalizeDouble(Bid - atrDaily*AtrSLFactor, digits);
                            if(newSL - sl >= stopLevel)
                            {
                                bool mod = OrderModify(OrderTicket(), 0, newSL, 0, 0, clrNONE);
                                if(!mod)
                                    Print("OrderModify failed on ", symbol,
                                          " error ", GetLastError());
                            }
                        }
                    }
                    else
                    {
                        if(Bid - open >= atrDaily*AtrSLFactor &&
                           Bid - open >= stopLevel && sl < open)
                        {
                            bool mod = OrderModify(OrderTicket(), 0,
                                                    NormalizeDouble(open, digits),
                                                    OrderTakeProfit(), 0, clrNONE);
                            if(!mod)
                                Print("OrderModify failed on ", symbol,
                                      " error ", GetLastError());
                        }
                    }
                }
                else if(OrderType()==OP_SELL)
                {
                    if(OrderTakeProfit()==0)
                    {
                        if(open - Ask >= atrDaily)
                        {
                            double newSL = NormalizeDouble(Ask + atrDaily*AtrSLFactor, digits);
                            if(sl - newSL >= stopLevel)
                            {
                                bool mod = OrderModify(OrderTicket(), 0, newSL, 0, 0, clrNONE);
                                if(!mod)
                                    Print("OrderModify failed on ", symbol,
                                          " error ", GetLastError());
                            }
                        }
                    }
                    else
                    {
                        if(open - Ask >= atrDaily*AtrSLFactor &&
                           open - Ask >= stopLevel && sl > open)
                        {
                            bool mod = OrderModify(OrderTicket(), 0,
                                                    NormalizeDouble(open, digits),
                                                    OrderTakeProfit(), 0, clrNONE);
                            if(!mod)
                                Print("OrderModify failed on ", symbol,
                                      " error ", GetLastError());
                        }
                    }
                }
            }
        }
    }
}

bool HasOpenOrder(string symbol)
{
    for(int i=OrdersTotal()-1; i>=0; i--)
    {
        if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
            if(OrderSymbol()==symbol && OrderMagicNumber()==MagicNumber)
                return(true);
        }
    }
    return(false);
}

bool IsTradeAllowed(string symbol)
{
    return(MarketInfo(symbol, MODE_TRADEALLOWED) != 0);
}

double CalcRiskLot(string symbol, double slDistance)
{
    if(slDistance <= 0.0)
        return(0.0);

    double riskAmount = AccountBalance() * RiskPercent / 100.0;
    double point      = MarketInfo(symbol, MODE_POINT);
    double tickValue  = MarketInfo(symbol, MODE_TICKVALUE);

    double lot = riskAmount / ((slDistance/point) * tickValue);

    double lotStep = MarketInfo(symbol, MODE_LOTSTEP);
    double minLot  = MarketInfo(symbol, MODE_MINLOT);
    double maxLot  = MarketInfo(symbol, MODE_MAXLOT);

    lot = MathFloor(lot/lotStep)*lotStep;
    lot = MathMax(minLot, MathMin(lot, maxLot));
    return(NormalizeDouble(lot, 2));
}
