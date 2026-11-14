//+------------------------------------------------------------------+
//| Exness PA/SMC EA - research prototype                            |
//| Original implementation inspired by public Price Action ideas.  |
//| No claim of equivalence to, or endorsement by, Pip Lord.          |
//+------------------------------------------------------------------+
#property strict
#property version   "0.10"
#property description "Multi-timeframe Price Action EA: trend, BOS, FVG retest, risk controls."

#include <Trade/Trade.mqh>
CTrade trade;

input ENUM_TIMEFRAMES TrendTF       = PERIOD_H1;
input ENUM_TIMEFRAMES SetupTF       = PERIOD_M15;
input ENUM_TIMEFRAMES EntryTF       = PERIOD_M5;
input int             FastEMA       = 50;
input int             SlowEMA       = 200;
input int             SwingLookback = 12;
input int             ZoneLookback  = 8;
input double          RiskPercent   = 0.25;
input double          RewardRisk    = 2.0;
input double          MaxDailyLoss  = 2.0;
input double          MaxSpreadPts  = 25;
input int             MaxPositions  = 1;
input int             SlippagePts   = 15;
input ulong           MagicNumber   = 6142026;
input bool            UseTradingHours = false;
input int             StartHour       = 7;
input int             EndHour         = 17;

int fastHandle = INVALID_HANDLE;
int slowHandle = INVALID_HANDLE;
datetime lastEntryBar = 0;
int dayKey = -1;
double dayStartEquity = 0.0;

struct Zone { double low; double high; bool bullish; datetime formed; };

int DateKey(datetime t)
{
   MqlDateTime d; TimeToStruct(t,d);
   return d.year*10000+d.mon*100+d.day;
}

bool NewBar(ENUM_TIMEFRAMES tf)
{
   datetime t=iTime(_Symbol,tf,0);
   if(t==0 || t==lastEntryBar) return false;
   lastEntryBar=t;
   return true;
}

bool TradingWindow()
{
   if(!UseTradingHours) return true;
   MqlDateTime d; TimeToStruct(TimeCurrent(),d);
   if(StartHour==EndHour) return true;
   if(StartHour<EndHour) return (d.hour>=StartHour && d.hour<EndHour);
   return (d.hour>=StartHour || d.hour<EndHour);
}

void RefreshDailyEquity()
{
   int k=DateKey(TimeCurrent());
   if(k!=dayKey)
   {
      dayKey=k;
      dayStartEquity=AccountInfoDouble(ACCOUNT_EQUITY);
   }
}

bool DailyLossAllowed()
{
   RefreshDailyEquity();
   if(dayStartEquity<=0) return false;
   double lossPct=(dayStartEquity-AccountInfoDouble(ACCOUNT_EQUITY))/dayStartEquity*100.0;
   return (lossPct<MaxDailyLoss);
}

int CountOurPositions()
{
   int count=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket>0 && PositionGetString(POSITION_SYMBOL)==_Symbol &&
         (ulong)PositionGetInteger(POSITION_MAGIC)==MagicNumber) count++;
   }
   return count;
}

int TrendDirection()
{
   double f[],s[];
   ArrayResize(f,2); ArrayResize(s,2);
   ArraySetAsSeries(f,true); ArraySetAsSeries(s,true);
   if(CopyBuffer(fastHandle,0,1,2,f)<2 || CopyBuffer(slowHandle,0,1,2,s)<2)
      return 0;
   double close=iClose(_Symbol,TrendTF,1);
   if(close==0) return 0;
   if(f[0]>s[0] && close>f[0]) return 1;
   if(f[0]<s[0] && close<f[0]) return -1;
   return 0;
}

// Find a recent break of the previous range and a three-candle fair-value gap.
bool FindSetup(int direction, Zone &fvg, Zone &ob, double &swingStop)
{
   MqlRates r[];
   ArraySetAsSeries(r,true);
   int need=MathMax(SwingLookback+5,ZoneLookback+5);
   if(CopyRates(_Symbol,SetupTF,0,need,r)<need) return false;

   double priorHigh=r[2].high, priorLow=r[2].low;
   for(int i=3;i<SwingLookback+3;i++)
   {
      priorHigh=MathMax(priorHigh,r[i].high);
      priorLow=MathMin(priorLow,r[i].low);
   }
   bool bos=(direction==1 ? r[1].close>priorHigh : r[1].close<priorLow);
   if(!bos) return false;

   bool gapFound=false;
   for(int i=1;i<=3;i++)
   {
      // Bullish FVG: older candle high below newer candle low.
      if(direction==1 && r[i+2].high<r[i].low)
      {
         fvg.low=r[i+2].high; fvg.high=r[i].low;
         fvg.bullish=true; fvg.formed=r[i].time; gapFound=true; break;
      }
      // Bearish FVG: older candle low above newer candle high.
      if(direction==-1 && r[i+2].low>r[i].high)
      {
         fvg.low=r[i].high; fvg.high=r[i+2].low;
         fvg.bullish=false; fvg.formed=r[i].time; gapFound=true; break;
      }
   }
   if(!gapFound) return false;

   bool obFound=false;
   for(int i=2;i<=ZoneLookback+1;i++)
   {
      if(direction==1 && r[i].close<r[i].open)
      {
         ob.low=r[i].low; ob.high=r[i].open; ob.bullish=true; ob.formed=r[i].time;
         obFound=true; break;
      }
      if(direction==-1 && r[i].close>r[i].open)
      {
         ob.low=r[i].open; ob.high=r[i].high; ob.bullish=false; ob.formed=r[i].time;
         obFound=true; break;
      }
   }
   if(!obFound) return false;

   // Require the FVG and candidate order block to overlap.
   if(MathMax(fvg.low,ob.low)>MathMin(fvg.high,ob.high)) return false;

   swingStop=(direction==1 ? r[1].low : r[1].high);
   for(int i=2;i<=SwingLookback;i++)
      swingStop=(direction==1 ? MathMin(swingStop,r[i].low) : MathMax(swingStop,r[i].high));
   return true;
}

double NormalizeVolume(double lots)
{
   double minLot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double maxLot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(step<=0) return 0;
   lots=MathMax(minLot,MathMin(maxLot,lots));
   lots=MathFloor(lots/step)*step;
   int digits=2;
   if(step>=1.0) digits=0; else if(step>=0.1) digits=1; else if(step>=0.01) digits=2; else digits=3;
   return NormalizeDouble(lots,digits);
}

double LotsForRisk(double entry,double stop)
{
   double riskMoney=AccountInfoDouble(ACCOUNT_EQUITY)*RiskPercent/100.0;
   double tickSize=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double tickValue=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double distance=MathAbs(entry-stop);
   if(distance<=0 || tickSize<=0 || tickValue<=0) return 0;
   double lossPerLot=(distance/tickSize)*tickValue;
   if(lossPerLot<=0) return 0;
   return NormalizeVolume(riskMoney/lossPerLot);
}

bool SpreadAllowed()
{
   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   return (ask>0 && bid>0 && (ask-bid)/_Point<=MaxSpreadPts);
}

void TryEntry()
{
   if(!TradingWindow() || !DailyLossAllowed() || !SpreadAllowed()) return;
   if(CountOurPositions()>=MaxPositions) return;

   int dir=TrendDirection();
   if(dir==0) return;

   Zone fvg,ob; double swingStop=0;
   if(!FindSetup(dir,fvg,ob,swingStop)) return;

   MqlRates e[];
   ArraySetAsSeries(e,true);
   if(CopyRates(_Symbol,EntryTF,0,3,e)<3) return;
   // Use the last closed entry candle: it must touch the shared FVG/OB zone
   // and close back in the direction of the higher-timeframe bias.
   double zoneLow=MathMax(fvg.low,ob.low);
   double zoneHigh=MathMin(fvg.high,ob.high);
   bool touched=(e[1].low<=zoneHigh && e[1].high>=zoneLow);
   bool confirm=(dir==1 ? e[1].close>e[1].open : e[1].close<e[1].open);
   if(!touched || !confirm) return;

   double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double entry=(dir==1 ? ask : bid);
   double stop=(dir==1 ? MathMin(swingStop,zoneLow) : MathMax(swingStop,zoneHigh));
   int stopsLevel=(int)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
   double minDistance=stopsLevel*_Point;
   if(dir==1 && entry-stop<minDistance) stop=entry-minDistance;
   if(dir==-1 && stop-entry<minDistance) stop=entry+minDistance;
   stop=NormalizeDouble(stop,_Digits);

   double risk=MathAbs(entry-stop);
   if(risk<2*_Point) return;
   double target=NormalizeDouble(entry+dir*risk*RewardRisk,_Digits);
   double lots=LotsForRisk(entry,stop);
   if(lots<=0) return;

   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(SlippagePts);
   trade.SetTypeFillingBySymbol(_Symbol);
   bool sent=(dir==1 ? trade.Buy(lots,_Symbol,0,stop,target,"PA-SMC FVG retest")
                     : trade.Sell(lots,_Symbol,0,stop,target,"PA-SMC FVG retest"));
   if(!sent) Print("Order failed: ",trade.ResultRetcode()," - ",trade.ResultRetcodeDescription());
   else Print("Order sent. Lots=",lots," SL=",stop," TP=",target);
}

int OnInit()
{
   if(RiskPercent<=0 || RiskPercent>2 || RewardRisk<1 || MaxDailyLoss<=0 ||
      FastEMA<=0 || SlowEMA<=FastEMA || SwingLookback<3 || MaxPositions<1)
      return INIT_PARAMETERS_INCORRECT;

   fastHandle=iMA(_Symbol,TrendTF,FastEMA,0,MODE_EMA,PRICE_CLOSE);
   slowHandle=iMA(_Symbol,TrendTF,SlowEMA,0,MODE_EMA,PRICE_CLOSE);
   if(fastHandle==INVALID_HANDLE || slowHandle==INVALID_HANDLE) return INIT_FAILED;

   trade.SetExpertMagicNumber(MagicNumber);
   RefreshDailyEquity();
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(fastHandle!=INVALID_HANDLE) IndicatorRelease(fastHandle);
   if(slowHandle!=INVALID_HANDLE) IndicatorRelease(slowHandle);
}

void OnTick()
{
   if(NewBar(EntryTF)) TryEntry();
}
//+------------------------------------------------------------------+
