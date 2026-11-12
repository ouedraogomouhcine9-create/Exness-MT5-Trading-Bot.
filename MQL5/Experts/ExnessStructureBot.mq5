#property strict
#property version "0.10"
#property description "Demo-only EURUSD M5 structure breakout/retest EA"
#include <Trade/Trade.mqh>
CTrade trade;

input double RiskPercent=0.25;
input double RewardRisk=2.0;
input int SwingLookback=12;
input int RetestMaxBars=5;
input int RetestTolerance=35;
input int StopBufferPoints=25;
input int MaxSpreadPoints=20;
input int VolumeLookback=20;
input double VolumeMultiplier=1.15;
input bool RequireFVG=false;
input bool RequireOrderBlock=false;
input ulong MagicNumber=6122026;

enum SetupState { WAIT_BREAKOUT=0, WAIT_BUY_RETEST=1, WAIT_SELL_RETEST=2 };
SetupState state=WAIT_BREAKOUT;
double breakoutLevel=0.0;
int barsSinceBreakout=0;
datetime lastBarTime=0;

bool IsNewBar()
{
 datetime t=iTime(_Symbol,PERIOD_M5,0);
 if(t==0 || t==lastBarTime) return false;
 lastBarTime=t; return true;
}
bool SafetyChecks()
{
 if(AccountInfoInteger(ACCOUNT_TRADE_MODE)!=ACCOUNT_TRADE_MODE_DEMO)
 { Print("SAFETY BLOCK: demo account required."); return false; }
 if(_Symbol!="EURUSD" || _Period!=PERIOD_M5) return false;
 if(SymbolInfoInteger(_Symbol,SYMBOL_SPREAD)>MaxSpreadPoints) return false;
 return Bars(_Symbol,PERIOD_M5)>=SwingLookback+VolumeLookback+10;
}
double HighestSwing()
{
 double v=-DBL_MAX;
 for(int i=3;i<SwingLookback+3;i++) v=MathMax(v,iHigh(_Symbol,PERIOD_M5,i));
 return v;
}
double LowestSwing()
{
 double v=DBL_MAX;
 for(int i=3;i<SwingLookback+3;i++) v=MathMin(v,iLow(_Symbol,PERIOD_M5,i));
 return v;
}
bool VolumeConfirmed()
{
 double sum=0;
 for(int i=2;i<VolumeLookback+2;i++) sum+=(double)iVolume(_Symbol,PERIOD_M5,i);
 double avg=sum/VolumeLookback;
 return avg>0 && (double)iVolume(_Symbol,PERIOD_M5,1)>=avg*VolumeMultiplier;
}
bool BullishFVG(){ return iLow(_Symbol,PERIOD_M5,1)>iHigh(_Symbol,PERIOD_M5,3); }
bool BearishFVG(){ return iHigh(_Symbol,PERIOD_M5,1)<iLow(_Symbol,PERIOD_M5,3); }
bool BullishOrderBlock()
{
 for(int i=2;i<=8;i++)
  if(iClose(_Symbol,PERIOD_M5,i)<iOpen(_Symbol,PERIOD_M5,i) &&
     iClose(_Symbol,PERIOD_M5,1)>iHigh(_Symbol,PERIOD_M5,i)) return true;
 return false;
}
bool BearishOrderBlock()
{
 for(int i=2;i<=8;i++)
  if(iClose(_Symbol,PERIOD_M5,i)>iOpen(_Symbol,PERIOD_M5,i) &&
     iClose(_Symbol,PERIOD_M5,1)<iLow(_Symbol,PERIOD_M5,i)) return true;
 return false;
}
double CalculateLots(double entry,double sl)
{
 double riskMoney=AccountInfoDouble(ACCOUNT_EQUITY)*RiskPercent/100.0;
 double tickSize=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
 double tickValue=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
 double minLot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
 double maxLot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
 double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
 double dist=MathAbs(entry-sl);
 if(tickSize<=0 || tickValue<=0 || dist<=0 || step<=0) return 0;
 double lossPerLot=(dist/tickSize)*tickValue;
 double lots=MathFloor((riskMoney/lossPerLot)/step)*step;
 if(lots<minLot) return 0; // Never exceed configured risk to force minimum lot.
 return NormalizeDouble(MathMin(maxLot,lots),2);
}
bool HasOurPosition()
{
 for(int i=PositionsTotal()-1;i>=0;i--)
 {
  ulong ticket=PositionGetTicket(i);
  if(ticket>0 && PositionGetString(POSITION_SYMBOL)==_Symbol &&
     (ulong)PositionGetInteger(POSITION_MAGIC)==MagicNumber) return true;
 }
 return false;
}
void PlaceBuy()
{
 double entry=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
 double sl=iLow(_Symbol,PERIOD_M5,1)-StopBufferPoints*_Point;
 double risk=entry-sl; if(risk<=0) return;
 double lots=CalculateLots(entry,sl); if(lots<=0) return;
 trade.SetExpertMagicNumber(MagicNumber);
 trade.Buy(lots,_Symbol,0.0,NormalizeDouble(sl,_Digits),
           NormalizeDouble(entry+RewardRisk*risk,_Digits),"Structure retest buy");
}
void PlaceSell()
{
 double entry=SymbolInfoDouble(_Symbol,SYMBOL_BID);
 double sl=iHigh(_Symbol,PERIOD_M5,1)+StopBufferPoints*_Point;
 double risk=sl-entry; if(risk<=0) return;
 double lots=CalculateLots(entry,sl); if(lots<=0) return;
 trade.SetExpertMagicNumber(MagicNumber);
 trade.Sell(lots,_Symbol,0.0,NormalizeDouble(sl,_Digits),
            NormalizeDouble(entry-RewardRisk*risk,_Digits),"Structure retest sell");
}
void OnTick()
{
 if(!IsNewBar() || !SafetyChecks() || HasOurPosition()) return;
 double c=iClose(_Symbol,PERIOD_M5,1);
 double h=iHigh(_Symbol,PERIOD_M5,1), l=iLow(_Symbol,PERIOD_M5,1);
 if(state==WAIT_BREAKOUT)
 {
  if(c>HighestSwing()){ state=WAIT_BUY_RETEST; breakoutLevel=HighestSwing(); barsSinceBreakout=0; return; }
  if(c<LowestSwing()){ state=WAIT_SELL_RETEST; breakoutLevel=LowestSwing(); barsSinceBreakout=0; return; }
  return;
 }
 barsSinceBreakout++;
 if(barsSinceBreakout>RetestMaxBars){ state=WAIT_BREAKOUT; return; }
 double tol=RetestTolerance*_Point;
 if(state==WAIT_BUY_RETEST)
 {
  bool retest=l<=breakoutLevel+tol && l>=breakoutLevel-tol;
  bool confirm=c>iOpen(_Symbol,PERIOD_M5,1) && c>breakoutLevel;
  bool filters=VolumeConfirmed() && (!RequireFVG || BullishFVG()) &&
               (!RequireOrderBlock || BullishOrderBlock());
  if(retest && confirm && filters){ PlaceBuy(); state=WAIT_BREAKOUT; }
 }
 else if(state==WAIT_SELL_RETEST)
 {
  bool retest=h>=breakoutLevel-tol && h<=breakoutLevel+tol;
  bool confirm=c<iOpen(_Symbol,PERIOD_M5,1) && c<breakoutLevel;
  bool filters=VolumeConfirmed() && (!RequireFVG || BearishFVG()) &&
               (!RequireOrderBlock || BearishOrderBlock());
  if(retest && confirm && filters){ PlaceSell(); state=WAIT_BREAKOUT; }
 }
}
