#include "SmartBracelet.h"
#define NEW_PRINTF_SEMANTICS
#include "printf.h"

configuration SmartBraceletAppC {}

implementation {
  components MainC, SmartBraceletC as App;
  
  components new AMSenderC(AM_MY_MSG);
  components new AMReceiverC(AM_MY_MSG);
  components ActiveMessageC as RadioAM;
  
  components new TimerMilliC() as TimerPairing;
  components new TimerMilliC() as Timer10s;
  components new TimerMilliC() as Timer60s;

  
  components SerialActiveMessageC as AMSerial;
  components SerialPrintfC;
  components SerialStartC;
  components RandomC;
  
  // Boot interface
  App.Boot -> MainC.Boot;
  
  // Radio interface
  App.AMSend -> AMSenderC;
  App.Receive -> AMReceiverC;
  App.AMControl -> RadioAM;
  
  App.Packet -> AMSenderC;
  App.AMPacket -> AMSenderC;
  App.PacketAcknowledgements -> RadioAM;
  
  App.Random -> RandomC;

  // Timers
  App.TimerPairing -> TimerPairing;
  App.Timer10s -> Timer10s;
  App.Timer60s -> Timer60s;
  
/*
  // Serial port
  App.SerialControl -> AMSerial;
  App.SerialAMSend -> AMSerial.AMSend[AM_MY_SERIAL_MSG];
  App.SerialPacket -> AMSerial;*/
  
}


