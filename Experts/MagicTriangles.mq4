//+------------------------------------------------------------------+
//|                                               MagicTriangles.mq4 |
//|                        Copyright 2016, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property     copyright                     "Copyright @ 2016 AlFa Forex"
#property     link                          "alessio.fabiani@gmail.com"
#property     version                       "1.0"
#property     strict
string        Version =                     "1.0";

#define BUY_ORDERS        1
#define SELL_ORDERS       2
#define ORDER_INCREMENT   4
#define SLEEP_TIME      250
#define major             1
#define minor             0

enum Enum1       // Lot Size
  {
   Dynamic,     // Dynamic lots
   StepLots,    // Step lots
   Static,      // Fixed lots
  };
enum Enum2       // Initial Balance
  {
   AccountBal,  // Account Balance
   SpecificBal, // Specified Balance
  };

extern bool   SkipFriday                     = false;
extern int    ClosingHour                    = 20;
extern int    ClosingMinute                  = 10;
extern bool   UseTradingTime                 = false;
extern int    TradingTimeStart               = 8;
extern int    TradingTimeEnd                 = 21;
extern bool   ClosePositionsNonTradingHours  = false;
extern double TradeOnValidRangeInPips        = 0;
extern int    TradeOnValidRangeBars          = 0;
extern int    ExpHours                       = 2;                     // Expiration Hours

extern Enum1  MoneyManagement                = Dynamic;               // Money Management
extern double RiskSetting                    = 1.0;                   // Risk Setting   (Dynamic)
extern double LotSize                        = 0.01;                  // Fixed Lot Size
extern double LotStep                        = 0.01;                  // Stepping Lot Size
extern bool   NoDropLotSize                  = true;
extern double MaxCurSpread                   = 1.5;                   // Max Spread Live  (Pips)
extern double MaxAvgSpread                   = 1.5;                   // Max Spread Avg   (Pips)

extern string _tmp1_=" --- Trade params ---";
extern bool   MarketExecution                = false;
extern int    PipsRangeFromLine              = 10;

extern double AccelerationPips               = 0.0;                  // Acceleration Allowed (Pips)
extern double InitialStopLoss                = 100;                   // Initial Stop (Pips)
extern double StopLossOverride               = 0;
extern bool   UseVirtualStopLoss             = false;
extern bool   UseAwesomeTrail                = false;
extern int    FractalsShift                  = 3;
extern bool   UseAwesomeATRLevels            = false;
extern int    ATRLevelsATRPeriod             = 10;
extern int    ATRLevelsTimeFrame             = PERIOD_M30;
extern bool   UseAwesomeSMMALevels           = false;
extern int    SMMALevelsMAPeriod             = 20;
extern int    SMMALevelsTimeFrame            = PERIOD_M5;
extern bool   UseBE                          = false;
extern double BeActivationPips               = 5.0;
extern double BePlusPips                     = 2.0;
extern bool   UseTrailStop                   = true;
extern double TrailingStop                   = 10.0;                   // Trailing Stop      (Pips)
extern double TSActivationPips               = 20.0;                   // TS Activation    (Pips)
extern double TrailingStep                   = 0.5;                   // Trailing Step     (Pips)
extern bool   UseHybridStop                  = false;
extern double ActivationPips                 = 10.0;
extern double StopTrailAtPips                = 2.0;
extern bool   ProfitLock                     = false;
extern double TrigPer                        = 0.5;
extern double ProLockPer                     = 20;
extern int    MaxPositions                   = 1;
extern int    TradesPerBar                   = 0;                     // Trades Per Bar
extern double TargetProfit                   = 100;                     // Target Profit  (Pips)
extern int    Slippage                       = 2;
extern Enum2  InitialBalance                 = AccountBal;            // Initial Balance
extern double SpecificBalance                = 250.0;                 // Specified Balance
extern double StepIntialBalance              = 1000;
extern double StepBalance                    = 100.0;                 // Stepping Balance
extern bool   ECNFriendly                    = true;
extern string TradeTag                       = "MagicTriangles";          // User Defined Tag
extern int    MagicNumber                    = 20100620;                  // MagicNumber Number

extern string _tmp2_=" --- TrendLine params ---";
extern string LongTrendLineDescr="LTR";
extern string ShortTrendLineDescr="STR";

extern string _tmp3_=" --- Chart ---";
extern color  clBuy=Blue;
extern color  clSell=Red;

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

#include <stdlib.mqh>
#include <stderror.mqh>

//+------------------------------------------------------------------+
//| Expert global variables                                          |
//+------------------------------------------------------------------+
int RepeatN=5;

int BuyCnt,SellCnt;
int BuyStopCnt,SellStopCnt;
int BuyLimitCnt,SellLimitCnt;

int             ExpSeconds;

double          SpreadAvg;
double          Spread;
int             MinBars;
bool            IsNewBar;

#define SPRD_CNT     100;
int             SpreadCounter;

double          HighestDownFrac;
double          LowestUpFrac;
datetime        UpFracTime;
datetime        DownFracTime;
double          ATRlowest;
double          ATRhighest;

MqlDateTime     currentBarTimeStruct, lastBarTimeStruct, timeGMTStruct;
datetime        currentBarTimeGMT;
datetime        lastBarTimeGMT;
int             timeGMTOffset=0;

static datetime LatestTradeTime;
int             TradesThisBar;
int             BuysThisBar;
int             SellsThisBar;
int             PendingTotal;
int             PendingBuys;
int             PendingSells;
int             OpenTotal;
int             OpenSells;
int             OpenBuys;
bool            OutOfRange;

double          BidStamp;
double          LastHighestBalance;
double          DigiMultiplier;
double          TrailingStop2;
double          TS1;
double          SL2;

double          ArraySpread[30];
double          avgspread = 0;
int             UpTo30Counter = 0;

double          CalculatedBalance;
double          CalculatedEquity;

static color    BuyColor = Green;
static color    SellColor = Red;

#define         SENSE_TICKS 3
double          TicksPrice[SENSE_TICKS];
double          Speed[SENSE_TICKS];
double          Acceleration[SENSE_TICKS];

string ls_objName;

double LastHigh = 0;
double LastLow  = 0;
int    LastCounter = 0;

double LastBuyTL1 = 0;
double LastBuyTL2 = 0;

double LastSellTL1 = 0;
double LastSellTL2 = 0;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnInit()
{
//--- initialize global variables
   HighestDownFrac      = 0;
   LowestUpFrac         = 0;
   UpFracTime           = 0;
   DownFracTime         = 0;
   ATRlowest            = 0;
   ATRhighest           = 0;

   ExpSeconds           = (ExpHours*PERIOD_H1*60);

   BidStamp             = 0;
   OutOfRange           = true;

   TradesThisBar        = 0;
   BuysThisBar          = 0;
   SellsThisBar         = 0;
   SpreadAvg            = 0.2;
   avgspread            = 0;
   LastHighestBalance   = 0;

//Adjust Time GMT Offset
   TimeToStruct(iTime(Symbol(),PERIOD_M1,0),currentBarTimeStruct);
   TimeGMT(timeGMTStruct);
   timeGMTOffset = (currentBarTimeStruct.hour-timeGMTStruct.hour);
   currentBarTimeGMT = GetTimeToGMT(iTime(Symbol(),PERIOD_M1,0));
   lastBarTimeGMT = currentBarTimeGMT;
   
   Print(" GMT Offset : ", timeGMTOffset);
   
//Adjust calculations for 5 digit brokers
   if(MarketInfo(Symbol(),MODE_DIGITS)==3 || MarketInfo(Symbol(),MODE_DIGITS)==5)
   {
      DigiMultiplier = 10;
   }
   else if(MarketInfo(Symbol(),MODE_DIGITS)==6)
   {
      DigiMultiplier = 100;
   }
   else
   {
      DigiMultiplier = 1;
   }
   Slippage = int(Slippage*DigiMultiplier);

   if(InitialStopLoss==0)
   {
      TS1 = 0;
   } else {
      TS1 = InitialStopLoss;
   }

   if((UseHybridStop == false) && (UseTrailStop == true) && (UseAwesomeTrail == true))
   {
      Print("You must choose either Trailing Stop -OR- Awesome Stops");
      return;
   }
   
   if((UseHybridStop == true) && !(UseTrailStop == true) && !(UseAwesomeTrail == true))
   {
      Print("You must choose both Trailing Stop -AND- Awesome Stops -WHEN- Hybrid mode is enabled.");
      return;
   }

   Print("Account Equity=",AccountEquity(),". Account Balance=",AccountBalance(),". Account Free Margin = ",AccountFreeMargin(),". Account Leverage=",AccountLeverage());

// Check for enough ticks and trade permission
   MinBars = 10;
   if(Bars<MinBars)
   {
      Print(" CANNOT TRADE. Not enough historical information!");
      return;
   }

   if(IsTradeAllowed()==false)
   {
      Print(" CANNOT TRADE  Trading is not allowed! Please confirm that the checkbox -Allow Live Trading option- is checked and that you are able to connect to the server.");
      return;
   }

// Using current symbol to check for account type
   Print("Lot Information: Symbol=",Symbol(),". MIN LOT ALLOWED=",MarketInfo(Symbol(),MODE_MINLOT),". MAX LOT ALLOWED=",MarketInfo(Symbol(),MODE_MAXLOT),". LOT SIZE IN BASE CURRENCY=",MarketInfo(Symbol(),MODE_LOTSIZE));
   Print("Lot Information: Buying 1 lot in your Account is equivalent to buying ",MarketInfo(Symbol(),MODE_LOTSIZE)," of currency.");
   Print("Lot Information: Buying the minimum lot size of ",MarketInfo(Symbol(),MODE_MINLOT)," is equivalent to buying ",MarketInfo(Symbol(),MODE_LOTSIZE)*MarketInfo(Symbol(),MODE_MINLOT)," of currency.");

   Print("Min Stops/Limit Level = ",MarketInfo(Symbol(),MODE_STOPLEVEL)," Points.");

//--
   RefreshRates();

   CalculatedBalance = 0.0;
   CalculatedEquity = 0.0;
   if(InitialBalance==SpecificBal)
   {
      CalculateInitialBalance();
   }
   
   SpreadCounter = 0;
//----init end
   return;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
//----deinitialization start
   DELETEP(Symbol(),"All");
   DELETEP(Symbol(),"All");

   Print(" Expert Advisor has been removed ");
   Comment("");
//----deinitialization end
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
{

//------------------
   IsNewBar = CheckIsNewBar();
//------------------

   if(!IsConnected())
   {
      if(IsNewBar) Print(" URGENT ACTION REQUIRED : There is no connection to the server!");
      return;
   }

   if(IsStopped())
   {
      if(IsNewBar) Print(" ERROR :Expert Advisor has been stopped");
      return;
   }
   
   OpenTotal =0;
   OpenSells =0;
   OpenBuys  =0;
   PendingTotal = 0;
   PendingSells = 0;
   PendingBuys  = 0;
   
   if (IsNewBar)
   {
      TradesThisBar = 0;
      BuysThisBar = 0;
      SellsThisBar = 0;

   //Adjust Time GMT Offset
      TimeToStruct(iTime(Symbol(),PERIOD_M1,0),currentBarTimeStruct);
      TimeGMT(timeGMTStruct);
      timeGMTOffset = (currentBarTimeStruct.hour-timeGMTStruct.hour);

   }

   if (TradesPerBar == 0) {
      BuysThisBar = -1;
      SellsThisBar = -1;
   }

//-- ProfitLock ------------------------------------------------------------------------------------------------------------------------
   if(CheckProfitLock())
   {
      Print("PROFIT LOCK: Close all orders!");
   }

//-- CheckBrokenOrders -----------------------------------------------------------------------------------------------------------------
   if(StopLossOverride>0 || InitialStopLoss>0)
   {
      CheckBrokenOrders();
   }

//-- TrailingStop ----------------------------------------------------------------------------------------------------------------------
   CheckTrailingStop();
   
//-- AwesomeStop -----------------------------------------------------------------------------------------------------------------------
   CheckAwesomeStop();

//-- Check if trading is possible
   if((TS1>0 && (TS1)*DigiMultiplier < MarketInfo(NULL,MODE_SPREAD)+MarketInfo(NULL,MODE_STOPLEVEL))|| (TS1==0 && InitialStopLoss>0 && (InitialStopLoss)*DigiMultiplier < MarketInfo(NULL,MODE_SPREAD)+MarketInfo(NULL,MODE_STOPLEVEL)))
   {
      if(IsNewBar) Print(" WARNING!! Your Stop Loss is too small for broker's minimum stop levels (Points):  ",  DoubleToStr(MarketInfo(NULL,MODE_SPREAD)+MarketInfo(NULL,MODE_STOPLEVEL),int(Digits)));      
   }
   
   // Check trading time
   if(UseTradingTime)
   {
      if(!((Hour()-timeGMTOffset)>=TradingTimeStart && (Hour()-timeGMTOffset)<=TradingTimeEnd))
      {
         if(IsNewBar)
         {
            Print(" INFO: Trading Time oustide the range. Do not Trade anymore!");
            Print(" INFO: Hour["+string(Hour())+"] - GMT Offset["+string(timeGMTOffset)+"] - TimeStart["+string(TradingTimeStart)+"] - TimeEnd["+string(TradingTimeEnd)+"]");
         }
         
         if(ClosePositionsNonTradingHours)
         {
            if(IsNewBar) Print(" INFO: Trading Time oustide the range AND Close Positions Enabled. DELETE orders and do not Trade anymore!");
            CloseAll(OP_BUY,MagicNumber);
            CloseAll(OP_SELL,MagicNumber);
            CloseAll(OP_BUY,MagicNumber);
            CloseAll(OP_SELL,MagicNumber);
            DELETEP(Symbol(),"All");
            DELETEP(Symbol(),"All");
            return;            
         }
         return;
      }
   }

   // 0=Sunday,1=Monday,2=Tuesday,3=Wednesday,4=Thursday,5=Friday,6=Saturday) of the last known server time;
   int CloseAlltradesDay = 5;
   // ClosingHour 0 to 23 & Closing Minute 0 to 59 , BOTH based on Brokers Time;
   if(SkipFriday && DayOfWeek()==CloseAlltradesDay && (Hour()-timeGMTOffset)==ClosingHour && Minute()>=ClosingMinute)
   {
      if(IsNewBar) Print("DO NOT Trade on Friday...");
      DELETEP(Symbol(),"All");
      DELETEP(Symbol(),"All");
      return;
   }

   //--- Check Valid Pip Range
   if (TradeOnValidRangeInPips>0 && TradeOnValidRangeBars>0)
   {
      int tvHighestIndex   = iHighest(NULL,PERIOD_CURRENT,MODE_HIGH,TradeOnValidRangeBars,1);
      int tvLowestIndex    = iLowest(NULL,PERIOD_CURRENT,MODE_LOW,TradeOnValidRangeBars,1);
      
      double tvHighestVal=0,tvLowestVal=0;
      if(tvHighestIndex!=-1) tvHighestVal=High[tvHighestIndex];
      if(tvLowestIndex!=-1)  tvLowestVal =Low[tvLowestIndex];
      
      if(NormalizeDouble((tvHighestVal-tvLowestVal),int(Digits))>=NormalizeDouble(TradeOnValidRangeInPips*DigiMultiplier*Point,int(Digits)))
      {
         if(IsNewBar) Print("Back [",TradeOnValidRangeBars,"] bars range in Pips Higher than ",TradeOnValidRangeInPips," ... Skip Trade!");
         DELETEP(Symbol(),"All");
         DELETEP(Symbol(),"All");
         return;
      }
   }

   //--- Computing Spread
      double sumofspreads;
      int loopcount1;
      int loopcount2;
      ArrayCopy(ArraySpread,ArraySpread,0,1,29);
      ArraySpread[29]=Spread;
      if(UpTo30Counter<30)
         UpTo30Counter++;
      sumofspreads=0;
      loopcount2=29;
      for(loopcount1=0; loopcount1<UpTo30Counter; loopcount1++)
        {
         sumofspreads+=ArraySpread[loopcount2];
         loopcount2 --;
        }
      avgspread=sumofspreads/UpTo30Counter;
      
      Spread    = NormalizeDouble(((Ask-Bid)/Point/DigiMultiplier),2);
      SpreadAvg = NormalizeDouble(avgspread,2);

   if(Spread > MaxCurSpread || SpreadAvg > MaxAvgSpread) 
   {
      SpreadCounter = SPRD_CNT;
      
      if(IsNewBar) Print("WARNING :Spread too high! Current Spread: ",DoubleToStr(Spread,2),"  Average Spread: ",DoubleToStr(SpreadAvg,2));
      DELETEP(Symbol(),"All");
      DELETEP(Symbol(),"All");
      return;
   }

   //---- Speed and Acceleration
   TicksPrice[2] = (TicksPrice[1]>0?TicksPrice[1]:Bid);
   TicksPrice[1] = (TicksPrice[0]>0?TicksPrice[0]:Bid);
   TicksPrice[0] = Bid;
   
   for (int s=0; s<SENSE_TICKS-1; s++) {
      Speed[s] = TicksPrice[s] - TicksPrice[s+1];
   }

   Acceleration[2] = Acceleration[1];
   Acceleration[1] = Acceleration[0];
   Acceleration[0] = Speed[0] - Speed[1];
   
   if (AccelerationPips > 0)
   {
      if(Acceleration[0] != 0 && MathAbs(Acceleration[0]) >= AccelerationPips*DigiMultiplier*Point)
      {
         if(IsNewBar) Print(" WARNING: Market too fast!! SKIP Trading due to HIGH Acceleration -> Acceleration Pips: ", MathAbs(NormalizeDouble(Acceleration[0]/(DigiMultiplier*Point),2)));
         DELETEP(Symbol(),"All");
         DELETEP(Symbol(),"All");
         return;
      }
   }
   //----------------------------------------------

   if (SpreadCounter <= 0)
   {
      /*if (IsNewBar)
      {
         Print("Current Spread: ",DoubleToStr(Spread,1),"  Average Spread: ",DoubleToStr(SpreadAvg,1));
         Print("Acceleration Pips: ", MathAbs(NormalizeDouble(Acceleration[0]/(DigiMultiplier*Point),2)));
      }*/
   } else {
      SpreadCounter = SpreadCounter-1;
   }
   
//---

   if(InitialBalance != SpecificBal)
   {
      CalculatedBalance= AccountBalance();
      CalculatedEquity = AccountEquity();
   }

//-- Initial entry logic ---------------------------------------------------------------------------------------------------------------

   if(Bars > 13)
   {

      int HighestIndex   = iHighest(NULL,PERIOD_CURRENT,MODE_HIGH,13,0);
      int LowestIndex    = iLowest(NULL,PERIOD_CURRENT,MODE_LOW,13,0);
      
      double HighestVal=0,LowestVal=0;
      if(HighestIndex!=-1) HighestVal=High[HighestIndex];
      if(LowestIndex!=-1)  LowestVal =Low[LowestIndex];

      ls_objName="LONGline";
      if((LastCounter >= 13) || (LastHigh == 0) || (HighestVal>LastHigh) || (ObjectGet(ls_objName,OBJPROP_COLOR) == White))
      {
         LastHigh = HighestVal;
         ObjectCreate(0,ls_objName,OBJ_TREND,0,0,0);
         ObjectSetInteger(0,ls_objName,OBJPROP_SELECTED,true);
         ObjectSetInteger(0,ls_objName,OBJPROP_RAY,false);
         ObjectSetInteger(0,ls_objName,OBJPROP_COLOR,clBuy);
         ObjectSetInteger(0,ls_objName,OBJPROP_TIME,Time[13]);
         ObjectSetDouble(0,ls_objName,OBJPROP_PRICE,Low[0]+MathAbs(Low[13]-High[0]));
         ObjectSetInteger(0,ls_objName,OBJPROP_TIME2,Time[0]+Period()*60*10);
         ObjectSetDouble(0,ls_objName,OBJPROP_PRICE2,Low[0]);
         ObjectSetString(0,ls_objName,OBJPROP_TEXT,LongTrendLineDescr);
      }
      
      ls_objName="SHORTline";
      if((LastCounter >= 13) || (LastLow == 0) || (LowestVal<LastLow) || (ObjectGet(ls_objName,OBJPROP_COLOR) == White))
      {
         LastLow = LowestVal;
         ObjectCreate(0,ls_objName,OBJ_TREND,0,0,0);
         ObjectSetInteger(0,ls_objName,OBJPROP_SELECTED,true);
         ObjectSetInteger(0,ls_objName,OBJPROP_RAY,false);
         ObjectSetInteger(0,ls_objName,OBJPROP_COLOR,clSell);
         ObjectSetInteger(0,ls_objName,OBJPROP_TIME,Time[13]);
         ObjectSetDouble(0,ls_objName,OBJPROP_PRICE,High[0]-MathAbs(Low[13]-High[0]));
         ObjectSetInteger(0,ls_objName,OBJPROP_TIME2,Time[0]+Period()*60*10);
         ObjectSetDouble(0,ls_objName,OBJPROP_PRICE2,High[0]);
         ObjectSetString(0,ls_objName,OBJPROP_TEXT,ShortTrendLineDescr);
      }
   }
   
   RefreshRates();

   string obj_name,obj_descr;
   color  obj_color;
   int obj_type;

   if(IsNewBar)
   {
      LastCounter++;
      int total = ObjectsTotal();
      for(int i=total-1; i>= 0; i--)
      {
         obj_name = ObjectName(i);
         obj_type = ObjectType(obj_name);
         if(obj_type!=OBJ_TREND) continue;
         
         obj_descr = ObjectDescription(obj_name);
         obj_color = (color) ObjectGet(obj_name,OBJPROP_COLOR);
         
         if( (obj_descr == LongTrendLineDescr)  && (obj_color == clBuy)  )
         {
            if((TradesPerBar == 0) || (TradesThisBar<TradesPerBar))
            {
               if((MaxPositions == 0) || (total>0 && OpenTotal<MaxPositions))
               {
                  if(Spread <= MaxCurSpread && SpreadAvg <= MaxAvgSpread && SpreadCounter <= 0)
                  {
                     LTR(obj_name);
                  }
               }
            }
         }
         
         if( (obj_descr == ShortTrendLineDescr) && (obj_color == clSell) )
         {
            if((TradesPerBar == 0) || (TradesThisBar<TradesPerBar))
            {
               if((MaxPositions == 0) || (total>0 && OpenTotal<MaxPositions))
               {
                  if(Spread <= MaxCurSpread && SpreadAvg <= MaxAvgSpread && SpreadCounter <= 0)
                  {
                     STR(obj_name);
                  }
               }
            }
         }
      }
   }
   
//-- End Trading Code

   IsNewBar = false;
   
   if(LastCounter>13) LastCounter=0;
//---

}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void LTR(string obj_name)
{
   bool BuySig = False;
   double TL1 = ObjectGetValueByShift(obj_name, 1);
   double TL2 = ObjectGetValueByShift(obj_name, 2);

   if (TL1 > 0 && TL2 > 0)
   {
      LastBuyTL1 = TL1;
      LastBuyTL2 = TL2;
   }
   
   
   if (LastBuyTL1 > 0 && LastBuyTL2 > 0)
   {
      BuySig=((Close[1]>LastBuyTL1 && Close[2]<=LastBuyTL2)
                && (Close[1]-PipsRangeFromLine*Point*DigiMultiplier>LastBuyTL1));
   }
   
//-----

   RecountOrders();

   double price,sl,tp;
   int ticket=0;
   string comment;

   if(BuySig)
     {
      ObjectSet(obj_name,OBJPROP_COLOR,White);
      ObjectSet(obj_name,OBJPROP_WIDTH,2);
      //if (BuyCnt > 0) return;
      //if(OrdersCountBar0(0, OP_BUY, obj_name) > 0) return;

      //-----

      if(MarketExecution)
        {
         for(int i=0; i<RepeatN; i++)
           {
            RefreshRates();
            price=Ask;

            comment="{"+obj_name+"}";

            double lots=CalculateLots();
            ticket=Buy(Symbol(),CalculateLots(),price,0,0,MagicNumber,comment);
            if(ticket>0) break;
           }

         for(int i=0; i<2*RepeatN; i++)
           {
            if(ticket<=0) break;
            if(!OrderSelect(ticket,SELECT_BY_TICKET)) break;

            sl = If(InitialStopLoss > 0, OrderOpenPrice() - InitialStopLoss*Point*DigiMultiplier, 0);
            tp = If(TargetProfit > 0, OrderOpenPrice() + TargetProfit*Point*DigiMultiplier, 0);

            TradesThisBar++;
            BuysThisBar++;
            
            if(sl>0 || tp>0)
              {
               bool res=OrderModify(OrderTicket(),OrderOpenPrice(),sl,tp,0);
               if(res) break;
              }
           }
        }

      else
        {
         for(int i=0; i<RepeatN; i++)
           {
            RefreshRates();
            price=Ask;

            sl = If(InitialStopLoss > 0, price - InitialStopLoss*Point*DigiMultiplier, 0);
            tp = If(TargetProfit > 0, price + TargetProfit*Point*DigiMultiplier, 0);

            comment="{"+obj_name+"}";

            double lots=CalculateLots();
            ticket=Buy(Symbol(),CalculateLots(),price,sl,tp,MagicNumber,comment);
            if(ticket>0)
            {
               TradesThisBar++;
               BuysThisBar++;

               break;
            }
           }
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void STR(string obj_name)
{
   bool SellSig = False;
   double TL1 = ObjectGetValueByShift(obj_name, 1);
   double TL2 = ObjectGetValueByShift(obj_name, 2);

   if (TL1 > 0 && TL2 > 0)
   {
      LastSellTL1 = TL1;
      LastSellTL2 = TL2;
   }
   
   
   if (LastSellTL1 > 0 && LastSellTL2 > 0)
   {
      SellSig=((Close[1]<LastSellTL1 && Close[2]>=LastSellTL2)
                 && (Close[1]+PipsRangeFromLine*Point*DigiMultiplier<LastSellTL1));
   }
   
//-----

   double price,sl,tp;
   int ticket=0;
   string comment;

   RecountOrders();

   if(SellSig)
     {
      ObjectSet(obj_name,OBJPROP_COLOR,White);
      ObjectSet(obj_name,OBJPROP_WIDTH,2);
      //if (SellCnt > 0) return;
      //if(OrdersCountBar0(0, OP_SELL, obj_name) > 0) return;

      //-----

      if(MarketExecution)
        {
         for(int i=0; i<RepeatN; i++)
           {
            RefreshRates();
            price=Bid;

            comment="{"+obj_name+"}";

            double lots=CalculateLots();
            ticket=Sell(Symbol(),CalculateLots(),price,0,0,MagicNumber,comment);
            if(ticket>0) break;
           }

         for(int i=0; i<2*RepeatN; i++)
           {
            if(ticket<=0) break;
            if(!OrderSelect(ticket,SELECT_BY_TICKET)) break;

            sl = If(InitialStopLoss > 0, OrderOpenPrice() + InitialStopLoss*Point*DigiMultiplier, 0);
            tp = If(TargetProfit > 0, OrderOpenPrice() - TargetProfit*Point*DigiMultiplier, 0);

            TradesThisBar++;
            SellsThisBar++;

            if(sl>0 || tp>0)
              {
               bool res=OrderModify(OrderTicket(),OrderOpenPrice(),sl,tp,0);
               if(res) break;
              }
           }
        }

      else
        {
         for(int i=0; i<RepeatN; i++)
           {
            RefreshRates();
            price=Bid;

            sl = If(InitialStopLoss > 0, price + InitialStopLoss*Point*DigiMultiplier, 0);
            tp = If(TargetProfit > 0, price - TargetProfit*Point*DigiMultiplier, 0);

            comment="{"+obj_name+"}";

            double lots=CalculateLots();
            ticket=Sell(Symbol(),CalculateLots(),price,sl,tp,MagicNumber,comment);
            if(ticket>0)
            {
               TradesThisBar++;
               SellsThisBar++;

               break;
            }
           }
        }
     }
  }
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

double If(bool cond,double if_true,double if_false)
  {
   if(cond) return (if_true);
   return (if_false);
  }
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void RecountOrders()
  {
   BuyCnt=0;
   SellCnt=0;
   BuyStopCnt=0;
   SellStopCnt = 0;
   BuyLimitCnt = 0;
   SellLimitCnt= 0;

   int cnt=OrdersTotal();
   for(int i=0; i<cnt; i++)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderSymbol()!=Symbol()) continue;
      if(OrderMagicNumber()!=MagicNumber) continue;

      int type= OrderType();
      if(type == OP_BUY) BuyCnt++;
      if(type == OP_SELL) SellCnt++;
      if(type == OP_BUYSTOP) BuyStopCnt++;
      if(type == OP_SELLSTOP) SellStopCnt++;
      if(type == OP_BUYLIMIT) BuyLimitCnt++;
      if(type == OP_SELLLIMIT) SellLimitCnt++;
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OrdersCountBar0(int TF,int type,string comment)
  {
   int orders=0;

   int cnt=OrdersTotal();
   for(int i=0; i<cnt; i++)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderSymbol()!=Symbol()) continue;
      if(OrderMagicNumber()!=MagicNumber) continue;
      if(OrderType()!=type) continue;
      if(StringFind(OrderComment(),comment)==-1) continue;

      if(OrderOpenTime()>=iTime(NULL,TF,0)) orders++;
     }

   cnt=OrdersHistoryTotal();
   for(int i=0; i<cnt; i++)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)) continue;
      if(OrderSymbol()!=Symbol()) continue;
      if(OrderMagicNumber()!=MagicNumber) continue;
      if(OrderType()!=type) continue;
      if(StringFind(OrderComment(),comment)==-1) continue;

      if(OrderOpenTime()>=iTime(NULL,TF,0)) orders++;
     }

   return (orders);
  }

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

int SleepOk=500;
int SleepErr=2000;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int Buy(string symbol,double lot,double price,double sl,double tp,int magic,string comment="")
  {
   int dig=(int)MarketInfo(symbol,MODE_DIGITS);

   price=NormalizeDouble(price,dig);
   sl = NormalizeDouble(sl, dig);
   tp = NormalizeDouble(tp, dig);

   string _lot=DoubleToStr(lot,2);
   string _price=DoubleToStr(price,dig);
   string _sl = DoubleToStr(sl, dig);
   string _tp = DoubleToStr(tp, dig);

   Print("Buy \"",symbol,"\", ",_lot,", ",_price,", ",Slippage,", ",_sl,", ",_tp,", ",magic,", \"",comment,"\"");

   int res= OrderSend(symbol, OP_BUY, lot, price, Slippage, sl, tp, comment, magic, 0, clBuy);
   if(res>=0)
     {
      Sleep(SleepOk);
      return (res);
     }

   int code=GetLastError();
   Print("Error opening BUY order: ",ErrorDescription(code)," (",code,")");
   Sleep(SleepErr);

   return (-1);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int Sell(string symbol,double lot,double price,double sl,double tp,int magic,string comment="")
  {
   int dig=(int)MarketInfo(symbol,MODE_DIGITS);

   price=NormalizeDouble(price,dig);
   sl = NormalizeDouble(sl, dig);
   tp = NormalizeDouble(tp, dig);

   string _lot=DoubleToStr(lot,2);
   string _price=DoubleToStr(price,dig);
   string _sl = DoubleToStr(sl, dig);
   string _tp = DoubleToStr(tp, dig);

   Print("Sell \"",symbol,"\", ",_lot,", ",_price,", ",Slippage,", ",_sl,", ",_tp,", ",magic,", \"",comment,"\"");

   int res= OrderSend(symbol, OP_SELL, lot, price, Slippage, sl, tp, comment, magic, 0, clSell);
   if(res>=0)
     {
      Sleep(SleepOk);
      return (res);
     }

   int code=GetLastError();
   Print("Error opening SELL order: ",ErrorDescription(code)," (",code,")");
   Sleep(SleepErr);

   return (-1);
  }

//+------------------------------------------------------------------+   
bool CheckIsNewBar()
{
   TimeToStruct(iTime(Symbol(),Period(),0),currentBarTimeStruct);
   currentBarTimeGMT = StrToTime(string(currentBarTimeStruct.year)+"."+string(currentBarTimeStruct.mon)+"."+string(currentBarTimeStruct.day)+" "+string(currentBarTimeStruct.hour-timeGMTOffset)+":"+string(currentBarTimeStruct.min)+":"+string(currentBarTimeStruct.sec));

   if( currentBarTimeGMT != lastBarTimeGMT)
   {
      lastBarTimeGMT = currentBarTimeGMT;
      return(true);
   }
   
   return(false);
}
//+------------------------------------------------------------------+   
datetime GetTimeToGMT(datetime time1)
{
   MqlDateTime time1Struct, time1GMTStruct;
   TimeToStruct(iTime(Symbol(),PERIOD_M1,0),time1Struct);
   TimeGMT(time1GMTStruct);
   int timeOffset = (time1Struct.hour-time1GMTStruct.hour);

   TimeToStruct(time1,time1Struct);
   //datetime time1GMT = StrToTime(time1Struct.year+"."+time1Struct.mon+"."+time1Struct.day+" "+(time1Struct.hour-timeGMTOffset)+":"+time1Struct.min+":"+time1Struct.sec);
   time1GMTStruct.year = time1Struct.year;
   time1GMTStruct.mon  = time1Struct.mon;
   time1GMTStruct.day  = time1Struct.day;
   time1GMTStruct.hour = (time1Struct.hour-timeOffset);
   time1GMTStruct.min  = time1Struct.min;
   time1GMTStruct.sec  = time1Struct.sec;
   datetime time1GMT = StructToTime(time1GMTStruct);

   return(time1GMT);
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CalculateInitialBalance()
{
   double total=0.0;
   double opentotal=0.0;

   int i,hstTotal=OrdersHistoryTotal();
   for(i=0;i<hstTotal;i++)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_HISTORY))
      {
         Print("Could not select order");
      }
      if(OrderMagicNumber()!=MagicNumber)
      {
         continue;
      }

      total+=OrderProfit()+OrderCommission()+OrderSwap();
   }

   int tot=OrdersTotal();
   for(i=0;i<tot;i++)
   {
      if(!OrderSelect(i,SELECT_BY_POS))
      {
         Print("Could not select order");
      }
      if(OrderMagicNumber()!=MagicNumber)
      {
         continue;
      }

      opentotal+=OrderProfit()+OrderCommission()+OrderSwap();
   }

   CalculatedBalance= SpecificBalance+total;
   CalculatedEquity = CalculatedBalance+opentotal;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CalculateLots()
{

   // Order value
   RefreshRates();                              // Refresh rates
   double Min_Lot     = MarketInfo(Symbol(),MODE_MINLOT);        // Minimal number of lots
   double Max_Lot     = MarketInfo(Symbol(),MODE_MAXLOT);
   double Free        = AccountFreeMargin();                 // Free margin
   double One_Lot     = MarketInfo(Symbol(),MODE_MARGINREQUIRED);// Price of 1 lot
   double Step        = MarketInfo(Symbol(),MODE_LOTSTEP);       // Step is changed
   double Size        = MarketInfo(Symbol(),MODE_LOTSIZE);       // Step is changed
   double leverageMux = 500.0;
   
   if (leverageMux < AccountLeverage()) leverageMux = 2*AccountLeverage();
   if (Min_Lot == 0) Min_Lot = 0.01;
   if (Max_Lot == 0) Max_Lot = 100.0;
   if (One_Lot == 0) One_Lot = (AccountBalance()*(leverageMux/AccountLeverage()));
   if (Step    == 0) Step    = Min_Lot;
   if (Size    == 0) Size    = (AccountLeverage()*1000.0);
   
   if(MoneyManagement==Static)
   {
      if(LotSize < Min_Lot){LotSize = Min_Lot;}
      if(LotSize > Max_Lot){LotSize = Max_Lot;}
      return (NormalizeDouble(LotSize,2));
   }
   if(MoneyManagement==StepLots)
   {
      double balanceDiff = AccountEquity()-StepIntialBalance;
      int mux = int(balanceDiff/StepBalance);
      if (balanceDiff < 0 || mux == 0)
      {
          if(NoDropLotSize)
          {
            LotSize = SteppingLatestLotSize();
          }
          if(LotSize < Min_Lot){LotSize = Min_Lot;}
          if(LotSize > Max_Lot){LotSize = Max_Lot;}
          return (NormalizeDouble(LotSize,2));
      } else {
          LotSize = LotSize+mux*LotStep;
          if(LotSize < Min_Lot){LotSize = Min_Lot;}
          if(LotSize > Max_Lot){LotSize = Max_Lot;}
          return (NormalizeDouble(LotSize,2));
      }
   }
   if(InitialBalance==SpecificBal)
   {
      Free=CalculatedBalance;
   }
   
   double LeverageRatio = leverageMux/AccountLeverage();

   double MinimumMarginLevel = (AccountBalance()*10)/AccountLeverage();
   
   if(Free<=0) {
      Free = MinimumMarginLevel;
   }
   
   /*if (Free/AccountBalance()<MinimumMarginLevel)
   {
      LeverageRatio = LeverageRatio / 2;
   }*/
   
   double Lts=MathFloor(Free*RiskSetting/10.0/One_Lot/Step*LeverageRatio)*Step;  // For opening

   if(Lts<=Min_Lot) Lts=Min_Lot;               // Not less than minimal
   if(Lts>=Max_Lot) Lts=Max_Lot;
   if(Lts*One_Lot>=Free) // Lot larger than free margin
   {
      //Alert(" Not enough money for ",Lts," lots");
      return (NormalizeDouble(Min_Lot,2));                                   // Exit start()
   }
   return (NormalizeDouble(Lts,2));
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double SteppingLatestLotSize()
{
   RefreshRates();
    //Sleep(100);                              // Refresh rates
   double total=0.0;
   double opentotal=0.0;

   int i,hstTotal=OrdersHistoryTotal();
   for(i=0;i<hstTotal;i++)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_HISTORY))
        {
         Print("Could not select order");
        }
      if(OrderMagicNumber()!=MagicNumber)
        {
         continue;
        }
      if(OrderProfit()>0)
         total+=OrderProfit()+OrderCommission()+OrderSwap();
     }

   double Min_Lot=MarketInfo(Symbol(),MODE_MINLOT);        // Minimal number of lots
   double Max_Lot=MarketInfo(Symbol(),MODE_MAXLOT);
   double steppingCalculatedBalance= StepIntialBalance+total;

   double lotSize = LotSize;
   double balanceDiff = steppingCalculatedBalance-StepIntialBalance;
   int mux = int(balanceDiff/StepBalance);
   if (balanceDiff < 0 || mux == 0) {
       if(lotSize < Min_Lot){lotSize = Min_Lot;}
       if(lotSize > Max_Lot){lotSize = Max_Lot;}
       return (NormalizeDouble(lotSize,2));
   } else {
       lotSize = LotSize+mux*LotStep;
       if(lotSize < Min_Lot){lotSize = Min_Lot;}
       if(lotSize > Max_Lot){lotSize = Max_Lot;}
       return (NormalizeDouble(lotSize,2));
   }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int ClosedOrdersPerBar(int bar) 
{
   if (bar == 0 && TradesThisBar<1) return(0);
   
   RefreshRates();

   int orders=0;
   int cnt = 0;
   if(OrdersHistoryTotal()>0) 
      { 
      for(int i = OrdersHistoryTotal()-1; i>=0; i--) 
      {
         if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         {
            continue;
         }
         
         if(OrderMagicNumber()!=MagicNumber)
         {
            continue;
         }
         
         if(OrderSymbol()!=Symbol())
         {
            continue;
         }
         
         if(OrderCloseTime() >= iTime(NULL,0,bar))
         {
            orders += ORDER_INCREMENT;
            cnt++;
            if(OrderType() == OP_BUY)  orders |= BUY_ORDERS;
            if(OrderType() == OP_SELL) orders |= SELL_ORDERS;
         }
         
         if (cnt >= TradesPerBar) {
            break;
         }
      } 
   }
   
   return(orders); 
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CheckOrdersCondition()
{
    int result=0;
    for (int i=OrdersTotal()-1; i>=0; i--) {
        if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
            if (OrderType()==OP_BUY && OrderSymbol()==Symbol() && OrderMagicNumber()==MagicNumber) {
                result=result+1000;
            }
            if (OrderType()==OP_SELL && OrderSymbol()==Symbol() && OrderMagicNumber()==MagicNumber) {
                result=result+100;
            }
            if (OrderType()==OP_BUYSTOP && OrderSymbol()==Symbol() && OrderMagicNumber()==MagicNumber) {
                result=result+10;
            }
            if (OrderType()==OP_SELLSTOP && OrderSymbol()==Symbol() && OrderMagicNumber()==MagicNumber) {
                result=result+1;
            }
        }
    }
    return(result); // 0 means we have no trades
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CheckStopLoss(int order_type,string symbol_sl,double price_sl,double sl)
{
  RefreshRates();
  double modeSpread = MarketInfo(NULL,MODE_SPREAD);
  double modeStop   = MarketInfo(NULL,MODE_STOPLEVEL);
  
  if(TrailingStop >0)
  {
      TrailingStop2 = TrailingStop*DigiMultiplier*Point;
  }
   //executes when AutoAdjustTPSL is set to true
   double minimumstop;
   if(sl==0)
   { // no stop loss
      return(sl);
   }
   minimumstop=modeStop*Point;

   if(MathAbs(NormalizeDouble(price_sl-sl,int(Digits)))<=minimumstop)
   {
      //move to a higher stop that assure execution
      if(order_type == OP_BUY || order_type == OP_BUYSTOP)
      {
         if(price_sl>sl)
         {
            //for longs
            sl=price_sl-minimumstop-TrailingStop2;
         } else {
            Print("ERROR: Could not adjust stop loss, SL=",sl);
            return(sl);
         }
      }
      else if(order_type==OP_SELL || order_type==OP_SELLSTOP)
      {
         if(price_sl<sl) {
            //for shorts
            sl=price_sl+minimumstop+TrailingStop2;
         } else {
            Print("ERROR: Could not adjust stop loss, SL=",sl);
            return(sl);
         }
      }

      //normalize SL
      sl=NormalizeDouble(sl,int(Digits));
      Print("Stop Loss was too small. It was changed. New SL=",sl);
   }
   
   return(sl);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CheckTakeProfit(string symbol_tp,double price_tp,double tp)
{
   //To adjust TP to server accepted levels
   double minimumstop;
   if(tp==0)
   { //no take profit
      return(tp);
   }
   minimumstop=2*MarketInfo(symbol_tp,MODE_STOPLEVEL)*MarketInfo(symbol_tp,MODE_POINT);

   if(MathAbs(price_tp-tp)<=minimumstop)
   {
      //move to a higher stop that assure execution
      //for longs
      if(price_tp<tp)
      {
         tp=price_tp+minimumstop;
      //for shorts
      } else if(price_tp>tp) {
         tp=price_tp-minimumstop;
      } else {
         Print("ERROR: Could not adjust take profit, TP=",tp);
         return(tp);
      }
      //normalize TP
      tp=NormalizeDouble(tp,int(Digits));
      Print("Target Profit was too small. It was changed. New TP=",tp);
   }
   return(tp);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CheckBrokenOrders()
{
   RefreshRates();
   double modeSpread = MarketInfo(NULL,MODE_SPREAD);
   double modeStop   = MarketInfo(NULL,MODE_STOPLEVEL);
   
   // Check StopLoss
   if(InitialStopLoss == 0)
   {
       SL2 = 0;
   } else {
       SL2 = InitialStopLoss;
   }
   
   for(int cnt=OrdersTotal()-1;cnt>=0;cnt--)
   {
      if(!OrderSelect(cnt,SELECT_BY_POS,MODE_TRADES))
      {
         Print("Order could not be selected");
      }
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MagicNumber)
         continue;
         
      if(OrderSymbol()==Symbol() && OrderMagicNumber()==MagicNumber)
      {
         if(OrderType()==OP_BUY || OrderType()==OP_SELL)
         {
            if(OrderType()==OP_BUY)
            {
               if( StopLossOverride > 0 ) 
               {
                  if(UseVirtualStopLoss){
                     if(NormalizeDouble(OrderOpenPrice()-Bid,Digits)>NormalizeDouble((StopLossOverride*DigiMultiplier+modeSpread)*Point,int(Digits))) {
                        if(OrderClose(OrderTicket(),OrderLots(),MarketInfo(OrderSymbol(), MODE_BID),0,BuyColor)) {
                           Print(" INFO: Order StopLossOverride hitten - closed ORDER #", OrderTicket(), " at price ", MarketInfo(OrderSymbol(), MODE_BID));
                           continue;
                        } else {
                           Print(" WARNING: Order StopLossOverride broken and was not possible to close the ORDER #", OrderTicket(), " at price ", MarketInfo(OrderSymbol(), MODE_BID));
                        }
                     }
                  } else if ( (OrderProfit()+OrderCommission()+OrderSwap())>0 ) {
                     if(NormalizeDouble(OrderOpenPrice()-OrderStopLoss(),Digits)>NormalizeDouble(StopLossOverride*DigiMultiplier*Point,Digits)) {

                        double smma_low = iMA(NULL,0,20,0,MODE_SMMA,PRICE_MEDIAN,0);
                        
                        if ((smma_low > 0) && (smma_low < Bid))
                        {
                           if ( (OrderStopLoss() == 0) || (OrderStopLoss() > 0 && OrderStopLoss() < NormalizeDouble(Ask-(StopLossOverride*DigiMultiplier*Point),Digits)) )
                           {
                              if(OrderModify(OrderTicket(),OrderOpenPrice(),CheckStopLoss(OP_BUY,OrderSymbol(),Ask,NormalizeDouble(Ask-((StopLossOverride*DigiMultiplier)*Point),int(Digits))),OrderTakeProfit(),0,BuyColor))
                              {
                                 Print(" INFO: Order StopLossOverride hitten - modify ORDER #", OrderTicket(), " SL at ", CheckStopLoss(OP_BUY,OrderSymbol(),Ask,NormalizeDouble(Ask-(StopLossOverride*DigiMultiplier*Point),Digits)));
                                 continue;
                              } else {
                                 Print(" WARNING: Order StopLossOverride broken and was not possible to close the ORDER #", OrderTicket(), " at price ", MarketInfo(OrderSymbol(), MODE_BID));
                              }
                           }
                        }
                        else
                        {
                           if(OrderClose(OrderTicket(),OrderLots(),MarketInfo(OrderSymbol(), MODE_BID),0,BuyColor))
                           {
                              Print(" INFO: Order StopLossOverride hitten - closed ORDER #", OrderTicket(), " at price ", MarketInfo(OrderSymbol(), MODE_BID));
                              continue;
                           } else {
                              Print(" WARNING: Order StopLossOverride broken and was not possible to close the ORDER #", OrderTicket(), " at price ", MarketInfo(OrderSymbol(), MODE_BID));
                           }
                        }
                     }
                  }
               }
               else if( OrderStopLoss()==0 && InitialStopLoss>0 )
               {
                  //modify order, adds TP/SL
                  if(OrderModify(OrderTicket(),OrderOpenPrice(),CheckStopLoss(OP_BUY,OrderSymbol(),Ask,NormalizeDouble(Ask-(SL2*DigiMultiplier*Point),Digits)),OrderTakeProfit(),0,BuyColor))
                  {
                     Print("Fixing broken trades: SL=",CheckStopLoss(OP_BUY,OrderSymbol(),Ask,NormalizeDouble(Ask-(SL2*DigiMultiplier*Point),Digits))," TP=",OrderTakeProfit());
                  } else {
                     int errorcode_ts=GetLastError();
                     Print("Could not add SL/TP to order. Error:",errorcode_ts);
                  }
               }
            }
            
            if(OrderType()==OP_SELL) {  // go short set up
               if( StopLossOverride > 0 ) 
               {
                  if(UseVirtualStopLoss){
                     if(NormalizeDouble(Ask-OrderOpenPrice(),Digits)>NormalizeDouble((StopLossOverride*DigiMultiplier+modeSpread)*Point,int(Digits)))
                     {
                        if(OrderClose(OrderTicket(),OrderLots(),MarketInfo(OrderSymbol(), MODE_ASK),0,SellColor))
                        {
                           Print(" INFO: Order StopLossOverride hitten - closed ORDER #", OrderTicket(), " at price ", MarketInfo(OrderSymbol(), MODE_ASK));
                           continue;
                        } else {
                           Print(" WARNING: Order StopLossOverride broken and was not possible to close the ORDER #", OrderTicket(), " at price ", MarketInfo(OrderSymbol(), MODE_ASK));
                        }
                     }
                  } else if( (OrderProfit()+OrderCommission()+OrderSwap())>0 ){
                     if(NormalizeDouble(OrderStopLoss()-OrderOpenPrice(),Digits)>NormalizeDouble(StopLossOverride*DigiMultiplier*Point,Digits)) {
                        
                        double smma_high = iMA(NULL,0,20,0,MODE_SMMA,PRICE_MEDIAN,0);
                        
                        if ((smma_high > 0) && (smma_high > Ask))
                        {
                           if ( (OrderStopLoss() == 0) || (OrderStopLoss() > 0 && OrderStopLoss() > NormalizeDouble(Bid+(StopLossOverride*DigiMultiplier*Point),Digits)) )
                           {
                              if(OrderModify(OrderTicket(),OrderOpenPrice(),CheckStopLoss(OP_SELL,OrderSymbol(),Bid,NormalizeDouble(Bid+(StopLossOverride*DigiMultiplier*Point),Digits)),OrderTakeProfit(),0,SellColor))
                              {
                                 Print(" INFO: Order StopLossOverride hitten - modify ORDER #", OrderTicket(), " SL at smma_high ", CheckStopLoss(OP_SELL,OrderSymbol(),Bid,NormalizeDouble(Bid+(StopLossOverride*DigiMultiplier*Point),Digits)));
                                 continue;
                              } else {
                                 Print(" WARNING: Order StopLossOverride broken and was not possible to close the ORDER #", OrderTicket(), " at price ", MarketInfo(OrderSymbol(), MODE_ASK));
                              }
                           }
                        }
                        else
                        {
                           if(OrderClose(OrderTicket(),OrderLots(),MarketInfo(OrderSymbol(), MODE_ASK),0,SellColor))
                           {
                              Print(" INFO: Order StopLossOverride hitten - closed ORDER #", OrderTicket(), " at price ", MarketInfo(OrderSymbol(), MODE_ASK));
                              continue;
                           } else {
                              Print(" WARNING: Order StopLossOverride broken and was not possible to close the ORDER #", OrderTicket(), " at price ", MarketInfo(OrderSymbol(), MODE_ASK));
                           }
                        }
                     }
                  }
               }
               else if( OrderStopLoss()==0 && InitialStopLoss>0 )
               {
                  //modify order, adds TP/SL
                  if(OrderModify(OrderTicket(),OrderOpenPrice(),CheckStopLoss(OP_SELL,OrderSymbol(),Bid,NormalizeDouble(Bid+(SL2*DigiMultiplier*Point),Digits)),OrderTakeProfit(),0,BuyColor))
                  {
                     Print("Fixing broken trades: SL=",CheckStopLoss(OP_SELL,OrderSymbol(),Bid,NormalizeDouble(Bid+(SL2*DigiMultiplier*Point),Digits))," TP=",OrderTakeProfit());
                  }else {
                     int errorcode_ts=GetLastError();
                     Print("Could not add SL/TP to order. Error:",errorcode_ts);
                  }
               }
            }

         }
      }
   }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CheckProfitLock() {
   RefreshRates();
   if (LastHighestBalance == 0)
   {
      LastHighestBalance = AccountBalance();
   }
   
   if (ProfitLock == true) 
   {
      if (AccountEquity() > LastHighestBalance + (LastHighestBalance * ProLockPer / 100.0))
      {
         if ( (LastHighestBalance > 0) && (AccountEquity() < LastHighestBalance - (LastHighestBalance * TrigPer / 100.0)) )
         {
            LastHighestBalance = AccountBalance();
            CloseAll(OP_BUY, MagicNumber);
            CloseAll(OP_SELL, MagicNumber);
            return(true);
         } else {
            LastHighestBalance = AccountEquity();
         }
      }
   }
   
   double totalProfit = 0;
   for(int iPos=OrdersTotal() - 1; iPos >=0; iPos--) if (
       OrderSelect(iPos,SELECT_BY_POS)
   &&  OrderSymbol()      == Symbol()
   &&  OrderMagicNumber() == MagicNumber
   )
   {
       //int duration = iBarShift(0,NULL, OrderOpenTime());
       //if (duration < ExpHours) continue;
       int duration = int(TimeCurrent() - OrderOpenTime());
       if (duration < ExpHours * 3600) continue;
       
       totalProfit += OrderProfit()+OrderCommission()+OrderSwap();
   }
   
   if(totalProfit>0)
   {
      CloseAll(OP_BUY, MagicNumber);
      CloseAll(OP_SELL, MagicNumber);
      return(true);
   }
   
   return(false);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CheckTrailingStop() {
   //--------------------------------------------------------------------------------------------------------------
   //-- Trailing Stops
   //--------------------------------------------------------------------------------------------------------------
    RefreshRates();
    
    for (int cnt = 0; cnt < OrdersTotal(); cnt++)
    {
        if (!OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES))
        {
            Print("Cannot select order");
            continue;
        }

        if ((OrderMagicNumber() == MagicNumber) && (OrderSymbol() == Symbol()))
        {

            if(OrderOpenTime()> LatestTradeTime)
            {
                LatestTradeTime=OrderOpenTime();
            }

            int dgts=int(Digits);

            if (OrderType() == OP_SELL)
            {
                OpenTotal++;
                OpenSells++;

                if (UseTrailStop == true && TrailingStop > 0)
                {
                    if (ProfitLock == true)
                    {
                        if (AccountEquity() >= (AccountBalance() + (AccountBalance() * ProLockPer / 100.0)))
                        {
                            continue;
                        }
                    }
                          
                    if (UseHybridStop == true)
                    {
                        if (Ask <= NormalizeDouble(OrderOpenPrice() - StopTrailAtPips*Point*DigiMultiplier, dgts))
                        {
                            continue;
                        }
                    }
                    
                    if (UseTrailStop == true)
                    {
                        if ( Ask <= NormalizeDouble(OrderOpenPrice()-TSActivationPips*Point*DigiMultiplier, dgts) )
                        {
                            if ( (OrderStopLoss() == 0) || (OrderStopLoss() > 0 && OrderStopLoss() > NormalizeDouble(Ask+(TrailingStep + TrailingStop)*Point*DigiMultiplier, dgts)))
                            {
                                Print(" INFO: Trailing Stop SELL Order @ ", CheckStopLoss(OP_SELL,Symbol(), Ask, NormalizeDouble(Ask+((TrailingStep + TrailingStop)*Point*DigiMultiplier), dgts)));
                                if (!OrderModify(OrderTicket(), OrderOpenPrice(), CheckStopLoss(OP_SELL,Symbol(), Ask, NormalizeDouble(Ask+((TrailingStep + TrailingStop)*Point*DigiMultiplier), dgts)), OrderTakeProfit(), 0, Red))
                                {
                                    Print("OrderModify failed");
                                }
                            }
                        }
                    }
                }
            }

            if (OrderType() == OP_BUY)
            {
                OpenTotal++;
                OpenBuys++;

                if (UseTrailStop == true && TrailingStop > 0)
                {
                    if (ProfitLock == true)
                    {
                        if (AccountEquity() >= (AccountBalance() + (AccountBalance() * ProLockPer / 100.0)))
                        {
                           continue;
                        }
                    }
                    
                    if (UseHybridStop == true)
                    {
                        if (Bid >= NormalizeDouble(OrderOpenPrice() + StopTrailAtPips*Point*DigiMultiplier, dgts))
                        {
                            continue;
                        }
                    }

                    if (UseTrailStop == true)
                    {
                        if ( Bid >= NormalizeDouble(OrderOpenPrice()+(TSActivationPips*Point*DigiMultiplier), dgts) )
                        {
                            if (OrderStopLoss() == 0 || (OrderStopLoss() != 0 && OrderStopLoss() < NormalizeDouble(Bid-(TrailingStep + TrailingStop)*Point*DigiMultiplier, dgts)))
                            {
                                Print(" INFO: Trailing Stop BUY Order @ ", CheckStopLoss(OP_BUY,Symbol(), Bid, NormalizeDouble(Bid-((TrailingStep + TrailingStop)*Point*DigiMultiplier), dgts)));
                                if (!OrderModify(OrderTicket(), OrderOpenPrice(), CheckStopLoss(OP_BUY,Symbol(), Bid, NormalizeDouble(Bid-((TrailingStep + TrailingStop)*Point*DigiMultiplier), dgts)), OrderTakeProfit(), 0, Green))
                                {
                                    Print("OrderModify failed");
                                }
                            }
                        }
                    }
                }
            }

            if (OrderType() == OP_BUYSTOP) {
                PendingTotal++;
                PendingBuys++;
            }

            if (OrderType() == OP_SELLSTOP) {
                PendingTotal++;
                PendingSells++;
            }
        }
    }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CheckAwesomeStop() {
   //--------------------------------------------------------------------------------------------------------------
   //-- Awesome Stops. Fractals Trailing Stops
   //--------------------------------------------------------------------------------------------------------------
   RefreshRates();
   
   if((UseAwesomeTrail == true) || (UseBE == true))
   {
       RefreshRates();
   
       if (ProfitLock == true && (AccountEquity() >= (AccountBalance() + (AccountBalance() * ProLockPer / 100.0))))
       {
            return;
       }
       
       for (int cnt = 0; cnt < OrdersTotal(); cnt++)
       {
           if (!OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES))
           {
               Print("Cannot select order");
               continue;
           }
   
           if ((OrderMagicNumber() == MagicNumber) && (OrderSymbol() == Symbol()))
           {
               if (OrderType() > OP_SELL)
                  continue;
               
               if((iFractals(Symbol(),0,MODE_LOWER,FractalsShift) > 0) && (HighestDownFrac != iFractals(Symbol(),0,MODE_LOWER,FractalsShift)))
               {
                  HighestDownFrac = iFractals(Symbol(),0,MODE_LOWER,FractalsShift);
                  DownFracTime = TimeCurrent();
               }
               if((iFractals(Symbol(),0,MODE_UPPER,FractalsShift) > 0) && (LowestUpFrac != iFractals(Symbol(),0,MODE_UPPER,FractalsShift)))
               {
                  LowestUpFrac = iFractals(Symbol(),0,MODE_UPPER,FractalsShift);
                  UpFracTime = TimeCurrent();
               }

               if(UseAwesomeATRLevels)
               {
                  double rates_d1x[][6];
                  ArrayCopyRates(rates_d1x, Symbol(), 0);
                  double fullatrx = iATR(Symbol(), ATRLevelsTimeFrame, ATRLevelsATRPeriod, 1);
                  
                  if (fullatrx <= 0)
                  {
                     Print(" ERROR: MT4 could not compute ATR index correclty ATR: ["+string(fullatrx)+"]");
                     return;
                  }
                  double L4x = rates_d1x[1][3] - fullatrx;
                  double H4x = rates_d1x[1][2] + fullatrx;
                  double L4tx = rates_d1x[0][3] - fullatrx;
                  double H4tx = rates_d1x[0][2] + fullatrx;
                  
                  ATRlowest=MathMin(MathMin(MathMin(H4x,L4x),H4tx),L4tx);
                  ATRhighest=MathMax(MathMax(MathMax(H4x,L4x),H4tx),L4tx);
                  
                  if (ATRlowest <= 0 || ATRhighest <= 0)
                  {
                     Print(" ERROR: MT4 could not compute ATR index correclty ATRlowest: ["+string(ATRlowest)+"] - ATRhighest: ["+string(ATRhighest)+"]");
                     return;
                  }
               }
               
               if(OrderOpenTime()> LatestTradeTime)
               {
                   LatestTradeTime=OrderOpenTime();
               }
   
               int dgts=int(Digits);
   
               if (OrderType() == OP_SELL)
               {
                   if( (UseBE == true) && (NormalizeDouble((Ask+(BeActivationPips*Point*DigiMultiplier)),dgts)<NormalizeDouble(OrderOpenPrice(),dgts)) )
                   {
                     if ( (OrderStopLoss() == 0) || (OrderStopLoss() > 0 && OrderStopLoss() > NormalizeDouble((OrderOpenPrice()-(BePlusPips*Point*DigiMultiplier)),dgts)) )
                     {
                       if(!OrderModify(OrderTicket(),OrderOpenPrice(),NormalizeDouble((OrderOpenPrice()-(BePlusPips*Point*DigiMultiplier)),dgts),0,0,Red))
                       {
                           Print("OrderModify failed");
                       }
                     }
                   }
   
                   if (UseHybridStop == true)
                   {
                       if (Ask >= NormalizeDouble(OrderOpenPrice() - ActivationPips*Point*DigiMultiplier, dgts))
                       {
                           continue;
                       }
                   }
                   
                   if (UseAwesomeTrail == true)
                   {
                      if((UseAwesomeATRLevels == false) && (UseAwesomeSMMALevels == false))
                      {
                          if (Ask <= OrderOpenPrice() && Ask <= NormalizeDouble(LowestUpFrac + (TrailingStop*Point*DigiMultiplier), dgts))
                          {
                              if(UpFracTime > OrderOpenTime() + FractalsShift * 60)
                              {
                                  if (OrderStopLoss() == 0 || (OrderStopLoss() > 0 && OrderStopLoss() > NormalizeDouble(LowestUpFrac + (TrailingStop*Point*DigiMultiplier), dgts)))
                                  {
                                      Print("Lowest Up Frac  ", LowestUpFrac);
                                      if (!OrderModify(OrderTicket(), OrderOpenPrice(), CheckStopLoss(OP_SELL,Symbol(), Ask, NormalizeDouble(LowestUpFrac + (TrailingStop*Point*DigiMultiplier), dgts)), OrderTakeProfit(), 0, Red))
                                      {
                                          Print("OrderModify failed");
                                      }
                                  }
                              }
                          }
                      } 
                      if((UseAwesomeATRLevels == true) && (UseAwesomeSMMALevels == false)) 
                      {
                          if (Ask <= OrderOpenPrice() && Ask <= NormalizeDouble(ATRhighest + (TrailingStop*Point*DigiMultiplier), dgts))
                          {
                              if (OrderStopLoss() == 0 || (OrderStopLoss() > 0 && OrderStopLoss() > NormalizeDouble(ATRhighest + (TrailingStop*Point*DigiMultiplier), dgts)))
                              {
                                  Print("Lowest Up ATR  ", ATRhighest);
                                  double TP1 = OrderTakeProfit();
                                  if (TP1 != 0) TP1 = NormalizeDouble(ATRlowest, dgts);
                                  if (!OrderModify(OrderTicket(), OrderOpenPrice(), CheckStopLoss(OP_SELL,Symbol(), Ask, NormalizeDouble(ATRhighest + (TrailingStop*Point*DigiMultiplier), dgts)), TP1, 0, Red))
                                  {
                                      Print("OrderModify failed");
                                  }
                              }
                          }
                      } 
                      if((UseAwesomeSMMALevels == true) && (UseAwesomeATRLevels == false))
                      {
                          
                          double bb1_ma = iMA(NULL,SMMALevelsTimeFrame,SMMALevelsMAPeriod,0,MODE_SMMA,PRICE_MEDIAN,1);

                          if (bb1_ma <= 0)
                          {
                             Print(" ERROR: MT4 could not compute iMA index correclty SMMA: ["+string(bb1_ma)+"]");
                             return;
                          }
                          
                          if (Ask <= OrderOpenPrice() && Ask <= NormalizeDouble(bb1_ma + (TrailingStop*Point*DigiMultiplier), dgts))
                          {
                              if (OrderStopLoss() == 0 || (OrderStopLoss() > 0 && OrderStopLoss() > NormalizeDouble(bb1_ma + (TrailingStop*Point*DigiMultiplier), dgts)))
                              {
                                  Print("Lowest Up SMMA  ", bb1_ma);
                                  double TP1 = OrderTakeProfit();
                                  if (!OrderModify(OrderTicket(), OrderOpenPrice(), CheckStopLoss(OP_SELL,Symbol(), Ask, NormalizeDouble(bb1_ma + (TrailingStop*Point*DigiMultiplier), dgts)), TP1, 0, Red))
                                  {
                                      Print("OrderModify failed");
                                  }
                              }
                          }
                      }
                   }
               }
   
               if (OrderType() == OP_BUY)
               {
                   if( (UseBE == true) &&(NormalizeDouble((Bid-(BeActivationPips*Point*DigiMultiplier)),dgts)>NormalizeDouble(OrderOpenPrice(),dgts)) )
                   {
                     if ((OrderStopLoss() == 0) || (OrderStopLoss() > 0 && OrderStopLoss() < NormalizeDouble((OrderOpenPrice()+(BePlusPips*Point*DigiMultiplier)),dgts)))
                     {
                       if(!OrderModify(OrderTicket(),OrderOpenPrice(),NormalizeDouble((OrderOpenPrice()+(BePlusPips*Point*DigiMultiplier)),dgts),0,0,Green))
                       {
                           Print("OrderModify failed");
                       }
                     }
                   }
   
                   if (UseHybridStop == true)
                   {
                       if (Bid <= NormalizeDouble(OrderOpenPrice()+ActivationPips*Point*DigiMultiplier, dgts))
                       {
                           continue;
                       }
                   }
                   
                   if (UseAwesomeTrail == true)
                   {
                      if((UseAwesomeATRLevels == false) && (UseAwesomeSMMALevels == false))
                      {
                          if (Bid >= OrderOpenPrice() && Bid >= NormalizeDouble(HighestDownFrac - (TrailingStop*Point*DigiMultiplier), dgts))
                          {
                              if (DownFracTime > OrderOpenTime() + FractalsShift * 60)
                              {
                                  if (OrderStopLoss() == 0 || (OrderStopLoss() > 0 && OrderStopLoss() < NormalizeDouble(HighestDownFrac-(TrailingStop*Point*DigiMultiplier), dgts)))
                                  {
                                      Print("Highest Down Frac  ", HighestDownFrac);
                                      if (!OrderModify(OrderTicket(), OrderOpenPrice(), CheckStopLoss(OP_BUY,Symbol(), Bid, NormalizeDouble(HighestDownFrac -(TrailingStop*Point*DigiMultiplier), dgts)), OrderTakeProfit(), 0, Green))
                                      {
                                          Print("OrderModify failed");
                                      }
                                  }
                              }
                          }
                      } 
                      if((UseAwesomeATRLevels == true) && (UseAwesomeSMMALevels == false))
                      {
                          if (Bid >= OrderOpenPrice() && Bid >= NormalizeDouble(ATRlowest - (TrailingStop*Point*DigiMultiplier), dgts))
                          {
                              if (OrderStopLoss() == 0 || (OrderStopLoss() > 0 && OrderStopLoss() < NormalizeDouble(ATRlowest -(TrailingStop*Point*DigiMultiplier), dgts)))
                              {
                                  Print("Highest Down ATR  ", ATRlowest);
                                  double TP2 = OrderTakeProfit();
                                  if (TP2 != 0) TP2 = NormalizeDouble(ATRhighest, dgts);
                                  if (!OrderModify(OrderTicket(), OrderOpenPrice(), CheckStopLoss(OP_BUY,Symbol(), Bid, NormalizeDouble(ATRlowest - (TrailingStop*Point*DigiMultiplier), dgts)), TP2, 0, Green))
                                  {
                                      Print("OrderModify failed");
                                  }
                              }
                          }
                      } 
                      if((UseAwesomeSMMALevels == true) && (UseAwesomeATRLevels == false))
                      {
                          double bb1_ma = iMA(NULL,SMMALevelsTimeFrame,SMMALevelsMAPeriod,0,MODE_SMMA,PRICE_MEDIAN,1);
                          
                          if (bb1_ma <= 0)
                          {
                             Print(" ERROR: MT4 could not compute iMA index correclty SMMA: ["+string(bb1_ma)+"]");
                             return;
                          }

                          if (Bid >= OrderOpenPrice() && Bid >= NormalizeDouble(bb1_ma - (TrailingStop*Point*DigiMultiplier), dgts))
                          {
                              if (OrderStopLoss() == 0 || (OrderStopLoss() > 0 && OrderStopLoss() < NormalizeDouble(bb1_ma -(TrailingStop*Point*DigiMultiplier), dgts)))
                              {
                                  Print("Highest Down SMMA  ", bb1_ma);
                                  double TP2 = OrderTakeProfit();
                                  if (!OrderModify(OrderTicket(), OrderOpenPrice(), CheckStopLoss(OP_BUY,Symbol(), Bid, NormalizeDouble(bb1_ma - (TrailingStop*Point*DigiMultiplier), dgts)), TP2, 0, Green))
                                  {
                                      Print("OrderModify failed");
                                  }
                              }
                          }
                      }
                  }
               }
           }
       }
   }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsTradingPossible()
{
//Check if trading is possible
   bool tmpresponse=true;
   if(!IsConnected())
     {
      Print("URGENT ACTION REQUIRED : There is no connection to the server!");
      tmpresponse=false;
     }
   if(IsStopped())
     {
      Print("ERROR :Expert Advisor has been stopped");
      tmpresponse=false;
     }

   return(tmpresponse);
} //end function

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool EnoughMoney(string symbol_em,double lotsize_em)
{
   if(( AccountFreeMarginCheck(symbol_em,OP_BUY,lotsize_em)<10) ||
      (AccountFreeMarginCheck(symbol_em,OP_SELL,lotsize_em)<10) ||
      (GetLastError()==134))
   {
      Print("NOT ENOUGH MONEY TO TRADE. Free margin is insufficient to trade a lot size of ",lotsize_em,". Current Free Margin=",AccountFreeMargin());
      return(false);
   } else {
      return(true);
   }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string OrderTypetoString(int ordertypecode)
{
   if(ordertypecode==OP_BUY)
      return("OP_BUY");

   if(ordertypecode==OP_SELL)
      return("OP_SELL");

   if(ordertypecode==OP_BUYSTOP)
      return("OP_BUYSTOP");

   if(ordertypecode==OP_SELLSTOP)
      return("OP_SELLSTOP");

   if(ordertypecode==OP_BUYLIMIT)
      return("OP_BUYLIMIT");

   if(ordertypecode==OP_SELLLIMIT)
      return("OP_SELLLIMIT");

   return("Unknow order type");
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int BUY(string symbol_b,double lotsize_b,double takeprofit_b,double stoploss_b,double trailings_b,string condition_b,color TradeColor)
{
   if(ECNFriendly)
   {
      ExecuteOrderinTwo(OP_BUY,symbol_b,lotsize_b, stoploss_b,takeprofit_b,condition_b,MagicNumber,TradeColor,condition_b);
   } else {
      ExecuteOrder(OP_BUY,symbol_b,lotsize_b,stoploss_b,takeprofit_b,condition_b,MagicNumber,TradeColor,condition_b);
   }

   return(0);
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int SELL(string symbol_s,double lotsize_s,double takeprofit_s,double stoploss_s,double trailings_s,string condition_s,color TradeColor)
{
   if(ECNFriendly)
   {
      ExecuteOrderinTwo(OP_SELL,symbol_s,lotsize_s, stoploss_s,takeprofit_s,condition_s,MagicNumber,TradeColor,condition_s);
   } else {
      ExecuteOrder(OP_SELL,symbol_s,lotsize_s, stoploss_s,takeprofit_s,condition_s,MagicNumber,TradeColor,condition_s);
   }

   return(0);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void BUYP(string symbol_p,double offset_p,double lotsize_p,double takeprofit_p,double stoploss_p,int expiration_p,string condition_p)
{
   PENDINGORDER(OP_BUYSTOP,symbol_p,lotsize_p,offset_p,stoploss_p,takeprofit_p,TradeTag,MagicNumber,BuyColor,condition_p,expiration_p);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void SELLP(string symbol_p,double offset_p,double lotsize_p,double takeprofit_p,double stoploss_p,int expiration_p,string condition_p)
{
   PENDINGORDER(OP_SELLSTOP,symbol_p,lotsize_p,offset_p,stoploss_p,takeprofit_p,TradeTag,MagicNumber,SellColor,condition_p,expiration_p);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CLOSELONG(string symbol_c)
{
   CloseAllPositions(symbol_c,OP_BUY,MagicNumber);
   CloseAllPositions(symbol_c,OP_BUY,MagicNumber);
   return(0);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CLOSESHORT(string symbol_c)
{
   CloseAllPositions(symbol_c,OP_SELL,MagicNumber);
   CloseAllPositions(symbol_c,OP_SELL,MagicNumber);
   return(0);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int DELETEP(string symbol_c, string penType)
{
   if(penType=="All")
   {
      DeletePending(symbol_c,OP_BUYSTOP,MagicNumber);
      DeletePending(symbol_c,OP_SELLSTOP,MagicNumber);
      DeletePending(symbol_c,OP_BUYSTOP,MagicNumber);
      DeletePending(symbol_c,OP_SELLSTOP,MagicNumber);
   } else if(penType=="BUYP") {
      DeletePending(symbol_c,OP_BUYSTOP,MagicNumber);
      DeletePending(symbol_c,OP_BUYSTOP,MagicNumber);
   } else if(penType=="SELLP") {
      DeletePending(symbol_c,OP_SELLSTOP,MagicNumber);
      DeletePending(symbol_c,OP_SELLSTOP,MagicNumber);
   } else {
      Print("Warning: Could not delete pending orders. Order type is wrong!");
   }

   return(0);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int PENDINGORDER(int ordertype_p,string symbol_p,double lotsize_p,double price_offp,double stoploss_p,double takeprofit_p,string comment_p,int magic_p,color ordercolor_p,string condition_p,int expiration_p)
{
   bool golong_p=false;

   datetime myexpiration=iTime(Symbol(),PERIOD_CURRENT,0)+ExpSeconds;
   int digits_p;
   double points_p;
   double price_p=0;
   double price_p2=0;
   
   int ticket_p;
   int retrynumber_p=3;
   int errorcode_p;

   //Set ordertype boolean
   switch(ordertype_p)
   {
      case OP_BUYSTOP:
         golong_p=true;
         break;
      case OP_SELLSTOP:
         golong_p=false;
         break;
      default:
         Print("ERROR : Wrong pending order type ",ordertype_p);
         return(-1);
   }

   //Verify capital
   if(!EnoughMoney(symbol_p,lotsize_p))
   {
      Print("WARNING : You may not have enough money to cover the execution of the pending order ", OrderTypetoString(ordertype_p));
   }
   // To do: Add % at risk
   
   //Gets pair info to prepare price
   
   digits_p = int(Digits);
   points_p = MarketInfo(symbol_p, MODE_POINT);

   while(retrynumber_p>0)
   {
      RefreshRates();
      
      // go long set up
      if(golong_p)
      {
         // price_p=NormalizeDouble(MarketInfo(symbol_p,MODE_ASK)+price_offp*points_p,digits_p);//++5 digits
         price_p2 =NormalizeDouble(Close[0]+price_offp*Point*DigiMultiplier,Digits);//++5 digits
         price_p = price_p2 - (TS1*Point*DigiMultiplier);
         if(TS1==0)
         {
            stoploss_p=0;
         } 
         else if(stoploss_p>0)
         {
            //To do : Verify stop loss if valid
            stoploss_p=NormalizeDouble(price_p,Digits);
         }
         
         if(takeprofit_p>0)
         {
            //Todo : Verify take profit is valid
            takeprofit_p=NormalizeDouble(price_p2+takeprofit_p*Point*DigiMultiplier,Digits);
         }
         
         // Print("Preparing Buy pending order ",symbol_p, " triggered by ",condition_p);
      } else {  // go short set up
         // price_p=NormalizeDouble(MarketInfo(symbol_p,MODE_BID)-price_offp*points_p,digits_p);
         price_p2 =NormalizeDouble(Close[0]-price_offp*Point*DigiMultiplier,Digits);//++5 digits
         price_p = price_p2 + (TS1*Point*DigiMultiplier);
         if(TS1==0)
         {
            stoploss_p=0;
         } 
         else if(stoploss_p>0)
         {
            //To do: Verify stop loss is valid
            stoploss_p=NormalizeDouble(price_p,Digits);
         }

         if(takeprofit_p>0)
         {
            //To do :Verify take profit are valid
            takeprofit_p=NormalizeDouble(price_p2-takeprofit_p*Point*DigiMultiplier,Digits);
         }
      }
      
      //Sending Pending Order
      ticket_p=OrderSend(symbol_p,ordertype_p,lotsize_p,price_p2,Slippage,stoploss_p,takeprofit_p,comment_p,magic_p,myexpiration,CLR_NONE);
      //-
      if(ticket_p>=0)
      {
         Sleep(SLEEP_TIME);
         if(OrderSelect(ticket_p,SELECT_BY_TICKET))
         {
            return(ticket_p);
         }
      } else {
         errorcode_p=GetLastError();
         // Retry if server is busy
         if(errorcode_p==ERR_SERVER_BUSY || errorcode_p==ERR_TRADE_CONTEXT_BUSY || errorcode_p==ERR_BROKER_BUSY || errorcode_p==ERR_NO_CONNECTION
         || errorcode_p==ERR_TRADE_TIMEOUT || errorcode_p==ERR_INVALID_PRICE || errorcode_p==ERR_OFF_QUOTES || errorcode_p==ERR_PRICE_CHANGED || errorcode_p==ERR_REQUOTE)
         {
            Print("ERROR: Server error. Sending pending order to server again. Retry intent number = ",retrynumber_p);
            retrynumber_p++;
            
            if(retrynumber_p>10)
            {
               Print("ERROR: Could not open new pending order. Error=",errorcode_p,". Order Info : Order Type=", OrderTypetoString(ordertype_p), ". Symbol=", symbol_p, ". Lot Size=",lotsize_p,
               ". Price=",price_p, ". SL=",stoploss_p,". TP=",takeprofit_p, ". Expiration time=",TimeToStr(myexpiration));
               Alert("ERROR: Could not open new pending position. Error=",errorcode_p,". Order Info : Order Type=", OrderTypetoString(ordertype_p), ". Symbol=", symbol_p, ". Lot Size=",lotsize_p,
               ". Price=",price_p, ". SL=",stoploss_p,". TP=",takeprofit_p, ". Expiration time=",TimeToStr(myexpiration));
               
               return (-1);
            }
            Sleep(SLEEP_TIME);
         } else {
            Print("ERROR: Could not open new pending position. Error=",errorcode_p,". Order Info : Order Type=", OrderTypetoString(ordertype_p) , ". Symbol=", symbol_p, ". Lot Size=",lotsize_p,
            ". Price=",price_p, ". SL=",stoploss_p,". TP=",takeprofit_p, ". Expiration time=",TimeToStr(myexpiration));
            Alert("ERROR: Could not open new position. Error=",errorcode_p,". Order Info : Order Type=", OrderTypetoString(ordertype_p) , ". Symbol=", symbol_p, ". Lot Size=",lotsize_p,
            ". Price=",price_p, ". SL=",stoploss_p,". TP=",takeprofit_p, ". Expiration time=",TimeToStr(myexpiration));
            
            if(errorcode_p==ERR_INVALID_STOPS)
            {
               Print("Possible Problem : Market moved. SL or TP too close to current price.");
               Alert("Possible Problem : Market moved. SL or TP too close to current price.");
            }
            return (-1);
         }
      }
   }//while
   
   return(0);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int DeletePending(string symbolclose,int ordertypeclose,int magicclose)
{
   int cnt;
   int err;
   int retrynumberclose=0;
   bool magiccond=true;
//verify type is ok
   if(ordertypeclose==OP_BUYLIMIT || ordertypeclose==OP_SELLLIMIT || ordertypeclose==OP_BUYSTOP || ordertypeclose==OP_SELLSTOP)
     {
      //ok
        } else {
       Print("Deleting pending positions failed. Order type is wrong.");
       Alert("Deleting pending positions failed. Order type is wrong.");
      return(-1);
     }

   int orderstotal=OrdersTotal();
   bool loopcl=true;
   while(loopcl)
     {
      loopcl=false;
      orderstotal=OrdersTotal();
      for(cnt=0;cnt<orderstotal;cnt++)
        {
         if(OrderSelect(cnt,SELECT_BY_POS,MODE_TRADES)) //executes if gets valid order
           {

            if(magicclose==0)
            {
               magiccond=true;
            } else {
               if(OrderMagicNumber()==magicclose)
               {
                  magiccond=true;
               } else {
                  magiccond=false;
               }
            }
            if((OrderType()==ordertypeclose) && (OrderSymbol()==symbolclose) && (magiccond))
              {
               //get closing price
               RefreshRates();
               if(!IsTradingPossible())
               {
                  Print("Warning: Trading may not be possible. Trying to delete pending orders.");
               }
               if(OrderDelete(OrderTicket(),Violet)) // close position
                 {
                  Print("Pending Order Deleted. Symbol:",symbolclose,". Lots:",OrderLots(),". Ticket number:",OrderTicket());
                  loopcl=true;
                  retrynumberclose=1;
                  break; //break loop and restart again

                    }else {
                  err=GetLastError();
                  Print("Deleting Pending Order failed. Symbol:",symbolclose,". Lots:",OrderLots(),". Ticket number:",OrderTicket(),". Error:",err);
                  Alert("Deleting Pending Order failed. Symbol:",symbolclose,". Lots:",OrderLots(),". Ticket number:",OrderTicket(),". Error:",err);
                  loopcl=true;
                  retrynumberclose++;
                  break; //break loop and restart again
                 }

              }

           }
        }//for
      if(retrynumberclose>10)
        {
         Print("Halting. Too many errors when deleting orders. Symbol:",symbolclose);
         Print("URGENT:Please verify your Internet Connection and Server response.");
         Alert("Halting. Too many errors when deleting orders. Symbol:",symbolclose);
         Alert("URGENT:Please verify your Internet Connection and Server response.");
         return(-1);
        }
     }//while

   return(0); // exit
}// end function

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int ExecuteOrderinTwo(int ordertype_bn,string symbol_bn,double lotsize_bn,double stoploss_bn,double takeprofit_bn,string comment_bn,int magic_bn,color ordercolor_bn,string condition_bn) //1 is ok, -1 is not ok
{

   int errorcode_ts=0;
   int my_ticket=ExecuteOrder(ordertype_bn,symbol_bn,lotsize_bn,0,0,
                              comment_bn,magic_bn,ordercolor_bn,condition_bn);
   if(my_ticket>0 && (stoploss_bn!=0 || takeprofit_bn!=0))
   {
      if(OrderSelect(my_ticket,SELECT_BY_TICKET))
      {
         //adjusting TP/SL if needed
         RefreshRates();
         int digits_bn;
         double points_bn,price_bn;
         bool golong_bn;
         digits_bn=int(Digits);
         points_bn=MarketInfo(symbol_bn,MODE_POINT);
         //stoploss_bn=stoploss_bn*10;
         //takeprofit_bn=takeprofit_bn*10;
         stoploss_bn=stoploss_bn*DigiMultiplier;
         takeprofit_bn=takeprofit_bn*DigiMultiplier;

         switch(ordertype_bn)
           {
            case OP_BUY:
               golong_bn=true;
               break;
            case OP_SELL:
               golong_bn=false;
               break;
            default:
               Print("ERROR : Wrong order type. Cannot add SL/TP ",ordertype_bn);
               return(-1);
               break;
           }

         if(golong_bn)
         {
            price_bn=NormalizeDouble(MarketInfo(symbol_bn,MODE_ASK),digits_bn);
            if(stoploss_bn>0)
              {
               stoploss_bn = NormalizeDouble(price_bn-stoploss_bn*points_bn, digits_bn);
               stoploss_bn = CheckStopLoss(ordertype_bn,symbol_bn, price_bn, stoploss_bn);
              }
            if(takeprofit_bn>0)
              {
               takeprofit_bn= NormalizeDouble(price_bn+takeprofit_bn*points_bn,digits_bn);
               takeprofit_bn= CheckTakeProfit(symbol_bn,price_bn,takeprofit_bn);
              }
          } else {  // go short set up
            price_bn=NormalizeDouble(MarketInfo(symbol_bn,MODE_BID),digits_bn);
            if(stoploss_bn>0)
              {
               stoploss_bn = NormalizeDouble(price_bn+stoploss_bn*points_bn, digits_bn);
               stoploss_bn = CheckStopLoss(ordertype_bn,symbol_bn, price_bn, stoploss_bn);
              }
            if(takeprofit_bn>0)
              {
               takeprofit_bn= NormalizeDouble(price_bn-takeprofit_bn*points_bn,digits_bn);
               takeprofit_bn= CheckTakeProfit(symbol_bn,price_bn,takeprofit_bn);
              }
           }//closes if go long
         //modify order, adds TP/SL
         if(OrderModify(my_ticket,OrderOpenPrice(),stoploss_bn,takeprofit_bn,0,ordercolor_bn))
         {
            Print("Step 2 - TP/SL added. SL=",stoploss_bn," TP=",takeprofit_bn);
         }else {
            errorcode_ts=GetLastError();
            Print("Could not add SL/TP to order. Error:",errorcode_ts);
         }
       } else {//closes if order select
         errorcode_ts=GetLastError();
         Print("Could not select order. Error:",errorcode_ts);
       }
   }//closes if my_ticket >0
   return(1);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int ExecuteOrder(int ordertype_bn,string symbol_bn,double lotsize_bn,double stoploss_bn,double takeprofit_bn,string comment_bn,int magic_bn,color ordercolor_bn,string condition_bn) //Returns ticket, -1 is not ok
{
   int digits_bn;
   double points_bn;
   double price_bn;
   int ticket_bn;
   bool golong_bn;
   int errorcode_bn;
   int retrynumber_bn=1;

   stoploss_bn=stoploss_bn*DigiMultiplier;
   takeprofit_bn=takeprofit_bn*DigiMultiplier;

//Set ordertype boolean
   switch(ordertype_bn)
     {
      case OP_BUY:
         golong_bn=true;
         break;
      case OP_SELL:
         golong_bn=false;
         break;
      default:
         Print("ERROR : Wrong order type ",ordertype_bn);
         return(-1);
         break;
     }

// Check if there is enough money to close the position
   if(!EnoughMoney(symbol_bn,lotsize_bn))
     {
      Print("ERROR : Not enough money to open position!");
      //Alert("ERROR : Not enough money to open position!");
      return(-1);
     }

//Gets pair info to prepare price

   digits_bn = int(Digits);
   points_bn = MarketInfo(symbol_bn, MODE_POINT);

//adjust lot
   while(retrynumber_bn>0)
     {
      RefreshRates();

      // go long set up

      if(golong_bn)
      {
         price_bn=NormalizeDouble(MarketInfo(symbol_bn,MODE_ASK),digits_bn);

         if(stoploss_bn>0)
           {
            //Verify stop loss if valid

            stoploss_bn = NormalizeDouble(price_bn-stoploss_bn*points_bn, digits_bn);
            stoploss_bn = CheckStopLoss(ordertype_bn,symbol_bn, price_bn, stoploss_bn);

           }

         if(takeprofit_bn>0)
           {
            //Verify take profit is valid
            takeprofit_bn= NormalizeDouble(price_bn+takeprofit_bn*points_bn,digits_bn);
            takeprofit_bn= CheckTakeProfit(symbol_bn,price_bn,takeprofit_bn);

           }

           } else {  // go short set up
         price_bn=NormalizeDouble(MarketInfo(symbol_bn,MODE_BID),digits_bn);

         if(stoploss_bn>0)
           {
            //Verify stop loss is valid
            stoploss_bn = NormalizeDouble(price_bn+stoploss_bn*points_bn, digits_bn);
            stoploss_bn = CheckStopLoss(ordertype_bn,symbol_bn, price_bn, stoploss_bn);

           }

         if(takeprofit_bn>0)
           {
            //Verify take profit are valid
            takeprofit_bn= NormalizeDouble(price_bn-takeprofit_bn*points_bn,digits_bn);
            takeprofit_bn= CheckTakeProfit(symbol_bn,price_bn,takeprofit_bn);

           }

        }
      // Verify order execution
      if(!IsTradingPossible())
        {
         Print("Warning: Trading may not be possible. Trying to open a new position.");
        }
      ticket_bn=OrderSend(symbol_bn,ordertype_bn,lotsize_bn,price_bn,Slippage,stoploss_bn,takeprofit_bn,comment_bn,magic_bn,0,ordercolor_bn);
      if(ticket_bn>=0)
        {
         Sleep(SLEEP_TIME);
         if(OrderSelect(ticket_bn,SELECT_BY_TICKET))
           {
            return(ticket_bn);
           }
        } else {
         errorcode_bn=GetLastError();
         // Retry if server is busy
         if(errorcode_bn==ERR_SERVER_BUSY || errorcode_bn==ERR_TRADE_CONTEXT_BUSY || errorcode_bn==ERR_BROKER_BUSY || errorcode_bn==ERR_NO_CONNECTION
            || errorcode_bn==ERR_TRADE_TIMEOUT || errorcode_bn==ERR_INVALID_PRICE || errorcode_bn==ERR_OFF_QUOTES || errorcode_bn==ERR_PRICE_CHANGED || errorcode_bn==ERR_REQUOTE)
           {
            Print("ERROR: Server error. Sending order to server again. Retry intent number = ",retrynumber_bn);
            retrynumber_bn++;
            if(retrynumber_bn>10)
              {
               Print("ERROR: Could not open new position. Error=",errorcode_bn,". Order Info : Order Type=",OrderTypetoString(ordertype_bn),". Symbol=",symbol_bn,". Lot Size=",lotsize_bn,
                     ". Price=",price_bn,". SL=",stoploss_bn,". TP=",takeprofit_bn);
               Alert("ERROR: Could not open new position. Error=",errorcode_bn,". Order Info : Order Type=",OrderTypetoString(ordertype_bn),". Symbol=",symbol_bn,". Lot Size=",lotsize_bn,
                     ". Price=",price_bn,". SL=",stoploss_bn,". TP=",takeprofit_bn);
               return (-1);
              }
            Sleep(SLEEP_TIME);
              } else {
            Print("ERROR: Could not open new position. Error=",errorcode_bn,". Order Info : Order Type=",OrderTypetoString(ordertype_bn),". Symbol=",symbol_bn,". Lot Size=",lotsize_bn,
                  ". Price=",price_bn,". SL=",stoploss_bn,". TP=",takeprofit_bn);
            Alert("ERROR: Could not open new position. Error=",errorcode_bn,". Order Info : Order Type=",OrderTypetoString(ordertype_bn),". Symbol=",symbol_bn,". Lot Size=",lotsize_bn,
                  ". Price=",price_bn,". SL=",stoploss_bn,". TP=",takeprofit_bn);

            if(errorcode_bn==ERR_INVALID_STOPS)
              {
              Print("ERROR: Invalid Stops  ");
              }

            return (-1);
           }
        }
   } //close while
   
   return(1);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CloseAll(int ordertypeclose,int magicclose)
  {
   int cnt;
   int err;
   int retrynumberclose=0;
   double priceclose;
   bool magiccond=true;
//verify type is ok
   if(ordertypeclose==OP_BUY || ordertypeclose==OP_SELL)
     {
      //ok
        } else {
      Print("Closing all positions failed. Order type is wrong.");
      Alert("Closing all positions failed. Order type is wrong.");
      return(-1);
     }

   int orderstotal=OrdersTotal();
   bool loopcl=true;
   while(loopcl)
     {
      loopcl=false;
      orderstotal=OrdersTotal();
      for(cnt=0;cnt<orderstotal;cnt++)
        {
         if(OrderSelect(cnt,SELECT_BY_POS,MODE_TRADES)) //executes if gets valid order
           {

            if(magicclose==0)
              {
               magiccond=true;
                 } else {
               if(OrderMagicNumber()==magicclose)
                 {
                  magiccond=true;
                    } else {
                  magiccond=false;
                 }

              }
            if(OrderType()==ordertypeclose && magiccond)
              {
               //get closing price
               RefreshRates();
               if(OrderType()==OP_BUY) priceclose=MarketInfo(OrderSymbol(),MODE_BID);
               else priceclose=MarketInfo(OrderSymbol(),MODE_ASK);
               if(!IsTradingPossible())
                 {
                  Print("Warning: Trading may not be possible. Trying to close orders.");
                 }
               if(OrderClose(OrderTicket(),OrderLots(),priceclose,Slippage,Violet)) // close position
                 {
                  Print("Order Closed. Symbol:",OrderSymbol(),". Lots:",OrderLots(),". Ticket number:",OrderTicket(),". Closed at price:",OrderClosePrice(),". Position was opened at price:",OrderOpenPrice()," Profit:",OrderProfit());

                  loopcl=true;
                  retrynumberclose=1;
                  break; //break loop and restart again
                    }else {
                  err=GetLastError();
                  Print("Closing Order failed. Symbol:",OrderSymbol(),". Lots:",OrderLots(),". Ticket number:",OrderTicket(),". Error:",err);
                  Alert("Closing Order failed. Symbol:",OrderSymbol(),". Lots:",OrderLots(),". Ticket number:",OrderTicket(),". Error:",err);

                  loopcl=true;
                  retrynumberclose++;
                  break; //break loop and restart again
                 }

              }

           }
        }//for
      if(retrynumberclose>10)
        {
         Print("Halting. Too many errors when closing positions. Symbol:",OrderSymbol());
         Print("URGENT:Please verify your Internet Connection and Server response.");
         Alert("Halting. Too many errors when closing positions. Symbol:",OrderSymbol());
         Alert("URGENT:Please verify your Internet Connection and Server response.");
         return(-1);
        }
     }//while

   return(0);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CloseAllPositions(string symbolclose,int ordertypeclose,int magicclose)
  {
//Print("Closing all positions started...");
   int cnt;
   int err;
   int retrynumberclose=0;
   double priceclose;
   bool magiccond=true;
//verify type is ok
   if(ordertypeclose==OP_BUY || ordertypeclose==OP_SELL)
     {
      //ok
        } else {
      Print("Closing all positions failed. Order type is wrong.");
      Alert("Closing all positions failed. Order type is wrong.");
      return(-1);
     }

//Print("Closing all positions (",symbolclose,",",OrderTypetoString(ordertypeclose),",",magicclose,")");
   int orderstotal=OrdersTotal();
   bool loopcl=true;
   while(loopcl)
     {
      loopcl=false;
      orderstotal=OrdersTotal();
      for(cnt=0;cnt<orderstotal;cnt++)
        {
         if(OrderSelect(cnt,SELECT_BY_POS,MODE_TRADES)) //executes if gets valid order
           {

            if(magicclose==0)
              {
               magiccond=true;
                 } else {
               if(OrderMagicNumber()==magicclose)
                 {
                  magiccond=true;
                    } else {
                  magiccond=false;
                 }

              }
            if((OrderType()==ordertypeclose) && (OrderSymbol()==symbolclose) && (magiccond))
              {
               //get closing price
               RefreshRates();
               if(ordertypeclose==OP_BUY) priceclose=MarketInfo(symbolclose,MODE_BID);
               else priceclose=MarketInfo(symbolclose,MODE_ASK);
               if(!IsTradingPossible())
                 {
                  Print("Warning: Trading may not be possible. Trying to close orders.");
                 }
               if(OrderClose(OrderTicket(),OrderLots(),priceclose,Slippage,Violet)) // close position
                 {
                  Print("Order Closed. Symbol:",symbolclose,". Lots:",OrderLots(),". Ticket number:",OrderTicket(),". Closed at price:",OrderClosePrice(),". Position was opened at price:",OrderOpenPrice()," Profit:",OrderProfit());

                  loopcl=true;
                  retrynumberclose=1;
                  break; //break loop and restart again
                    }else {
                  err=GetLastError();
                  Print("Closing Order failed. Symbol:",symbolclose,". Lots:",OrderLots(),". Ticket number:",OrderTicket(),". Error:",err);
                  Alert("Closing Order failed. Symbol:",symbolclose,". Lots:",OrderLots(),". Ticket number:",OrderTicket(),". Error:",err);

                  loopcl=true;
                  retrynumberclose++;
                  break; //break loop and restart again
                 }

              }

           }
        }//for
      if(retrynumberclose>10)
        {
         Print("Halting. Too many errors when closing positions. Symbol:",symbolclose);
         Print("URGENT:Please verify your Internet Connection and Server response.");
         Alert("Halting. Too many errors when closing positions. Symbol:",symbolclose);
         Alert("URGENT:Please verify your Internet Connection and Server response.");
         return(-1);
        }
     }//while
//Print("Closing all positions finished. (",symbolclose,",",OrderTypetoString(ordertypeclose),",",magicclose,")");
   return(0);
}
