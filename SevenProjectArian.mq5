#include <Trade/Trade.mqh>

CTrade trade;

int maxOrders=3;
int ordersOpened=0; //variable to count the number of opened orders
int totalPositions=PositionsTotal();
int openPositions=0;
int MACDDef;
int stopLoss=100;
int takeProfit=100;
input int magic=100;
double Lots=0.1;
double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
double bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);

int OnInit(){
   //MACD
   MACDDef= iMACD(_Symbol,PERIOD_M15,12,26,9,PRICE_CLOSE);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason){

}

void OnTick(){
   //MACD
   double MACDMainLine[];
   double MACDSignalLine[];
   
   ArraySetAsSeries(MACDMainLine,true);
   ArraySetAsSeries(MACDSignalLine,true);
   
   CopyBuffer(MACDDef,0,0,3,MACDMainLine);
   CopyBuffer(MACDDef,1,0,3,MACDSignalLine);
   
   float MACDMainLineVal= (MACDMainLine[0]);
   float MACDSignalLineVal= (MACDSignalLine[0]);
   
   //Trade
   double stopLevel=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*_Point;
   
   ask=NormalizeDouble(ask,_Digits);
   bid=NormalizeDouble(bid,_Digits);
   
   //Buying
   double slB=ask-stopLoss*_Point;
   double tpB=ask+takeProfit*_Point;
   
   slB=NormalizeDouble(slB,_Digits);
   tpB=NormalizeDouble(tpB,_Digits);
   
   //make sure that SL/TP has the minimun leven of stop
   double newSlB=ask-max(stopLoss*_Point,stopLevel);
   double newTpB=ask+max(takeProfit*_Point,stopLevel);
   
   newSlB=NormalizeDouble(newSlB,_Digits);
   newTpB=NormalizeDouble(newTpB,_Digits);
   
   //verify if the levels has the requisites
   if((ask-newSlB) >= stopLevel && (newTpB-ask) >= stopLevel){
     trade.Buy(Lots,_Symbol,ask,newSlB,newTpB);
   }else{
     Print("Adjusted SL/TP are still too close to the current price.");
   }
   
   //Selling
   double tpS=bid-takeProfit*_Point;
   double slS=bid+takeProfit*_Point;
   
   tpS=NormalizeDouble(tpS,_Digits);
   slS=NormalizeDouble(slS,_Digits);
   
   //make sure that SL/TP has the minimun leven of stop
   double newSlS=bid+max(stopLoss*_Point,stopLevel);
   double newTpS=bid-max(takeProfit*_Point,stopLevel);
   
   newSlS=NormalizeDouble(newSlS,_Digits);
   newTpS=NormalizeDouble(newTpS,_Digits);
   
   //verify if the levels has the requisites
   if((newSlS-bid) >= stopLevel && (bid - newTpS) >= stopLevel){
     trade.Sell(Lots,_Symbol,bid,newSlS,newTpS);
   }else{
     Print("Adjusted SL/TP are still too close to the current price.");
   }
   
   //Obtaining information using active orders
   for(int i=0; i<OrdersTotal(); i++){
     if(OrderSelect(i)){
       ulong ticket=OrderGetTicket(i);
       bool selected=OrderSelect(ticket);
       if(selected){
         double price_open=OrderGetDouble(ORDER_PRICE_OPEN);
         datetime time_setup=OrderGetInteger(ORDER_TIME_SETUP);
         string symbol=OrderGetString(ORDER_SYMBOL);
         PrintFormat("Open #%d fpr %s was set at %s",ticket,_Symbol,TimeToString(time_setup));
       }else{
         PrintFormat("Error selecting order with ticket %d. Error %d", ticket, GetLastError());
       }
     }
   }
   
   //Obtaining informtion on open positions
   for(int i=0; i<OrdersTotal(); i++){
     if(OrderSelect(i)){
       string symbol=_Symbol;
       bool selectedOne=PositionSelect(symbol);
       if(selectedOne){
         long pos_id=PositionGetInteger(POSITION_IDENTIFIER);
         double price=PositionGetDouble(POSITION_PRICE_OPEN);
         ENUM_POSITION_TYPE type=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         long pos_magic=PositionGetInteger(POSITION_MAGIC);
         string comment=PositionGetString(POSITION_COMMENT);
         PrintFormat("Position #%d by %s: POSITION_MAGIC=%d, price=%G, type=%s, commentary=%s",
         pos_id,symbol,pos_magic,price,EnumToString(type),comment);
       }else{
         PrintFormat("Unsuccessful selection of the position by the symbol %s. Error",symbol,GetLastError());
       }
     }
   }
   
   /*
   Strategy One=
   MACD main line > 0= Bullish Setup
   MACD main line < 0= Bearish Setup
   */
   if(MACDMainLineVal>0){
     Comment("Bullish Setup as MACD mainline is ",MACDMainLineVal);
   }
   if(MACDMainLineVal<0){
     Comment("Bearish Setup as MACD mainline is ",MACDMainLineVal);
   }
   
   //Stop infinite Orders
   int totalPositions = PositionsTotal();
   bool orderOpenBuy = false;
   bool orderOpenSell = false;

   for(int i = totalPositions - 1; i >= 0; i--) {
      if(PositionSelectByTicket(i)){
          if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == magic){
              if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY){
                 orderOpenBuy = true;
              }else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL){
                 orderOpenSell = true;
              }
          }
      }
   }
   
   /*
   Strategy Two=
   MACD main line > MACD signal line = Buying signal
   MACD main line < MACD signal line = Shorting signal
   */
   if(MACDMainLineVal>MACDSignalLineVal && !orderOpenBuy){
     //buying
     trade.Buy(Lots,_Symbol,ask,slB,tpB);
   }
   if(MACDMainLineVal<MACDSignalLineVal && !orderOpenSell){
     //selling
     trade.Sell(Lots,_Symbol,bid,slS,tpS);
   }
   
   //just three orders no more
   //if there are less than maxOrders open positions, open new orders
   for(int i=totalPositions-1; i>=0; i--){
     if(PositionSelect(i)){
       if(PositionGetString(POSITION_SYMBOL)==_Symbol){
         openPositions++;
       }
     }
   }
   
   if(openPositions<maxOrders){
     if(trade.Buy(Lots,_Symbol,ask,slB,tpB)|| trade.Sell(Lots,_Symbol,bid,slS,tpS)){
       ordersOpened++;
     }
   }
   
   if(openPositions>=maxOrders){
     ordersOpened=0;
   }
}

double max(double a, double b){
   return (a>b) ? a:b;
}