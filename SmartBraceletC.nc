#include "Timer.h"
#include "SmartBracelet.h"
#include "printf.h"	

module SmartBraceletC @safe() {
  uses {
    interface Boot;
    
    interface AMSend;
    interface Receive;
    interface SplitControl as AMControl;
    interface Packet;
    interface AMPacket;
    interface PacketAcknowledgements;
    interface Random;
    
    interface Timer<TMilli> as TimerPairing;
    interface Timer<TMilli> as Timer10s;
    interface Timer<TMilli> as Timer60s;
     
  }
}

implementation {
  
  // Radio control
  bool busy = FALSE;
  message_t packet;
  am_addr_t address_coupled_device;
  uint8_t attempt = 0;
  uint8_t value;
  
  uint16_t last_x;
  uint16_t last_y;
  
  // Current phase
  uint8_t phase = 0;
  
  
  void send_confirmation();
  void send_info_message();
  
  // Program start
  event void Boot.booted() {
    call AMControl.start();
  }

  // called when radio is ready
  event void AMControl.startDone(error_t err) {
    if (err == SUCCESS) {
    	if (TOS_NODE_ID % 2 == 0){
          printf("Parent bracelet ready, pairing phase started\n");
        } else {
          printf("Child bracelet ready, pairing phase started\n");
        }
      // Start pairing phase
      call TimerPairing.startPeriodic(250);
    } else {
      call AMControl.start();
    }
  }
  
  event void AMControl.stopDone(error_t err) {}
  
 
  event void TimerPairing.fired() {
   
    if (!busy) {
      my_msg_t* sb_pairing_message = (my_msg_t*)call Packet.getPayload(&packet, sizeof(my_msg_t));
      
      // Fill payload
      sb_pairing_message->msg_type = KEY; 
      //The node ID is divided by 2 so every 2 nodes will be the same number (0/2=0 and 1/2=0)
      //we get the same key for every 2 nodes: parent and child
      strcpy(sb_pairing_message->msg_key, RANDOM_KEY[(TOS_NODE_ID-1)/2]);
      
      if (call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(my_msg_t)) == SUCCESS) {
	      printf("Radio: sending pairing packet, key=%s\n", RANDOM_KEY[(TOS_NODE_ID-1)/2]);	
	      busy = TRUE;
      }
    }
  }
  
  // Timer10s fired
  event void Timer10s.fired() {
    printf("Timer10s: timer fired\n");
    send_info_message();
    
  }

  // Timer60s fired
  event void Timer60s.fired() {
    printf("Timer60s: timer fired\n");
    printf("ALERT: MISSING\n");
    printf("Last position (X,Y) = (%d,%d)\n", last_x, last_y);
  }

 
  event void AMSend.sendDone(message_t* bufPtr, error_t error) {
    if (&packet == bufPtr && error == SUCCESS) {
      printf("Packet sent\n");
      busy = FALSE;
      
      if (phase == 1 && call PacketAcknowledgements.wasAcked(bufPtr) ){
        // Phase == 1 and ack received
        phase = 2; // Pairing phase 1 completed
        printf("Pairing ack received\n");
        printf("Pairing phase 1 completed for node: %d\n", address_coupled_device);
        
        // Start operational phase
        if (TOS_NODE_ID % 2 == 0){
          // Parent bracelet
          //printf("Parent bracelet\n");
          //call SerialControl.start();
          call Timer60s.startOneShot(60000);
        } else {
          // Child bracelet
          //printf("Child bracelet\n");
          call Timer10s.startPeriodic(10000);
        }
      
      } else if (phase == 1){
        // Phase == 1 but ack not received
        printf("Pairing ack not received\n");
        send_confirmation(); // Send confirmation again
      
      } else if (phase == 2 && call PacketAcknowledgements.wasAcked(bufPtr)){
        // Phase == 2 and ack received
        printf("INFO ack received\n");
        attempt = 0;
        
      } else if (phase == 2){
        // Phase == 2 and ack not received
        printf("INFO ack not received\n");
        send_info_message();
      }
        
    }
  }
  
  event message_t* Receive.receive(message_t* bufPtr, void* payload, uint8_t len) {
    my_msg_t* mess = (my_msg_t*)payload;
    // Print data of the received packet
	  printf("Message received from node %d with type = %d\n", call AMPacket.source( bufPtr ), mess->msg_type);
	 
    if (call AMPacket.destination( bufPtr ) == AM_BROADCAST_ADDR && phase == 0 && strcmp(mess->msg_key, RANDOM_KEY[(TOS_NODE_ID-1)/2]) == 0){
      // controlla che sia un broadcast e che siamo nella fase di pairing phase == 0
      // e che la chiave corrisponda a quella di questo dispositivo
      
      address_coupled_device = call AMPacket.source( bufPtr );
      phase = 1; // 1 for confirmation of pairing phase
      printf("Message for pairing phase 0 received. Address: %d\n", address_coupled_device);
      send_confirmation();
    
    } else if (call AMPacket.destination( bufPtr ) == TOS_NODE_ID && mess->msg_type == DONE) {
      // Enters if the packet is for this destination and if the msg_type == 1
      printf("Message for pairing phase 1 received\n");
      call TimerPairing.stop();
      
    } else if (call AMPacket.destination( bufPtr ) == TOS_NODE_ID && call AMPacket.source( bufPtr ) == address_coupled_device && mess->msg_type == INFO) {
      // Enters if the packet is for this destination and if msg_type == 2
      printf("INFO message received\n");
      printf("Position X: %d, Y: %d\n", mess->msg_x, mess->msg_y);
      printf("Sensor status: %d\n", mess->msg_status);
      last_x = mess->msg_x;
      last_y = mess->msg_y;
      call Timer60s.startOneShot(60000);
      
      // check if FALLING
      if (mess->msg_status == FALLING){
        printf("ALERT: FALLING!\n");
        printf("Position: (X,Y) = (%d,%d)\n", mess->msg_x, mess->msg_y);
      }
    }
    return bufPtr;
  }

 
  // Send confirmation in phase 1
  void send_confirmation(){
    if (!busy) {
      my_msg_t* sb_pairing_message = (my_msg_t*)call Packet.getPayload(&packet, sizeof(my_msg_t));
      
      // Fill payload
      sb_pairing_message->msg_type = DONE; 
      
      strcpy(sb_pairing_message->msg_key, RANDOM_KEY[(TOS_NODE_ID-1)/2]);
      
      // Require ack
      call PacketAcknowledgements.requestAck( &packet );
      
      if (call AMSend.send(address_coupled_device, &packet, sizeof(my_msg_t)) == SUCCESS) {
        printf("Radio: sanding pairing confirmation to node %d\n", address_coupled_device);	
        busy = TRUE;
      }
    }
  }
  
  // Send INFO message from child's bracelet
  void send_info_message(){
    
    if (attempt < 3){
      if (!busy) {
        my_msg_t* rcm = (my_msg_t*)call Packet.getPayload(&packet, sizeof(my_msg_t));
        
       	rcm->msg_type = INFO;
	    rcm->msg_x = call Random.rand16();
	    rcm->msg_y = call Random.rand16();
	    
	    value = call Random.rand16() % 10;
	    if(value == 0 || value == 1 || value == 2)
    		rcm->msg_status = STANDING;
    	else if(value == 3 || value == 4 || value == 5)
    		rcm->msg_status = WALKING;
    	else if(value == 6 || value == 7 || value == 8)
    		rcm->msg_status = RUNNING;
    	else // value == 9
    	    rcm->msg_status = FALLING;
	    
        // Require ack
        attempt++;
        call PacketAcknowledgements.requestAck( &packet );
        
        if (call AMSend.send(address_coupled_device, &packet, sizeof(my_msg_t)) == SUCCESS) {
          printf("Radio: sanding INFO packet to node %d, attempt: %d\n", address_coupled_device, attempt);	
          busy = TRUE;
        }
      }
    } else {
      attempt = 0;
    }
  } 
}
