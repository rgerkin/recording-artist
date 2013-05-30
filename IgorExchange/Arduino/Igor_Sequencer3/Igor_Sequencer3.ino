
// CmdMessenger library available from https://github.com/dreamcat4/cmdmessenger
#include <CmdMessenger.h>

// Base64 library available from https://github.com/adamvr/arduino-base64
#include <Base64.h>

// Streaming5 library available from http://arduiniana.org/libraries/streaming/
#include <Streaming.h>



// Mustnt conflict / collide with our message payload data. Fine if we use base64 library ^^ above
char field_separator = ',';
char command_separator = ';';


// declare some arrays to hold each of the data for the 10 epochs
int epochtype[10] = {0,0,0,0,0,0,0,0,0,0};    // this will be 1 for off, 2 for DC and 3 for pulses
int epochduration[10] = {0,0,0,0,0,0,0,0,0,0};
int pulseduration[10] = {0,0,0,0,0,0,0,0,0,0};
int pulseinterval[10] = {0,0,0,0,0,0,0,0,0,0};
int pulsenumber[10] = {0,0,0,0,0,0,0,0,0,0};
int portDBitValue[10] = {0,0,0,0,0,0,0,0,0,0};
int portBBitValue[10] = {0,0,0,0,0,0,0,0,0,0};
int seqrepeats = 0;
long seqinterval = 0;
long seqduration = 0;


// Attach a new CmdMessenger object to the default Serial port
CmdMessenger cmdMessenger = CmdMessenger(Serial, field_separator, command_separator);

// ------------------ C M D L I S T I N G ( T X / R X ) ---------------------

// We can define up to a default of 50 cmds total, including both directions (send + recieve)
// and including also the first 4 default command codes for the generic error handling.
// If you run out of message slots, then just increase the value of MAXCALLBACKS in CmdMessenger.h

// Commands we send from the Arduino to be received on the PC
enum
{
  kCOMM_ERROR = 000, // Lets Arduino report serial port comm error back to the PC (only works for some comm errors)
  kACK = 001, // Arduino acknowledges cmd was received
  kARDUINO_READY = 002, // After opening the comm port, send this cmd 02 from PC to check arduino is ready
  kERR = 003, // Arduino reports badly formatted cmd, or cmd not recognised

  // For the above commands, we just call cmdMessenger.sendCmd() anywhere we want in our Arduino program.

  kSEND_CMDS_END, // Mustnt delete this line
};

// Commands we send from the PC and want to recieve on the Arduino.
// We must define a callback function in our Arduino program for each entry in the list below vv.
// They start at the address kSEND_CMDS_END defined ^^ above as 004
messengerCallbackFunction messengerCallbacks[] =
{
  Pulses_Out_4, // 004 in this example
  PWM_Out_5, // 005 in this example
  PinSet_6,
  ReadPin_7,
  SetZero_8,
  GetDC_9,
  GetPulse_10,
  ResetAll_11,
  GetRepsData_12,
  GetEpochData_13,
  StartSequence_14,
  NULL
};


// ------------------ C A L L B A C K M E T H O D S -------------------------

void Pulses_Out_4()
{
  // Message data is any ASCII bytes (0-255 value). But can't contain the field
  // separator, command separator chars you decide (eg ',' and ';')
  
  int counter;
  long value;
  int PinOut;
  int OnDuration;
  int OffDuration;
  int Cycles;
 cmdMessenger.sendCmd(kACK,"PulsesOut cmd received");
  for (counter = 0; cmdMessenger.available(); counter ++)
  {
    char buf[350] = { '\0' };
    cmdMessenger.copyString(buf, 350);
    if(buf[0])
      cmdMessenger.sendCmd(kACK, buf);
      value = strtol(buf, NULL, 10);
      switch (counter) {
        case 0:
          PinOut = value;
          break;
        
        case 1:
        OnDuration = value;
          break;
        
        case 2:
          OffDuration = value;
          break;
        
        case 3:
         Cycles = value;
         break;
    }
  }
    
  Serial.print("PinOut is ");
  Serial.println(PinOut);
  Serial.print("On Duration is ");
  Serial.println(OnDuration);
  Serial.print("Off Duration is ");
  Serial.println(OffDuration);
  Serial.print("Number of Cycles ");
  Serial.println(Cycles);
  counter=0;
  
  for (counter = 0; counter < Cycles; counter++)
  {
    digitalWrite(PinOut, HIGH);
    delay(OnDuration);
    digitalWrite(PinOut, LOW);
    delay(OffDuration);
  }

  Serial.println("Arduino Finished in function 4");
}

void PWM_Out_5()  // this will be a function that sets a pin at a certain rate
{
  // Message data is any ASCII bytes (0-255 value). But can't contain the field
  // separator, command separator chars you decide (eg ',' and ';')
  // this should only work for pins 3, 5, 6, 9, 10, and 11
  int counter;
  long value;
  int PinOut;  // this should only be certain pins
  float OnPc;
  int BitProportion;
 cmdMessenger.sendCmd(kACK,"PWM cmd received");
  for (counter = 0; cmdMessenger.available(); counter ++)
  {
    char buf[350] = { '\0' };
    cmdMessenger.copyString(buf, 350);
    if(buf[0])
      cmdMessenger.sendCmd(kACK, buf);  // this sends info to the serial print but it is not useful
      value = strtol(buf, NULL, 10);
      switch (counter) {
        case 0:
          PinOut = value;
          break;
        
        case 1:
          OnPc = value;
          break;       
    }
  }
  
  if (OnPc < 0 || OnPc > 100)
  {
    Serial.println("Values need to be between 0 and 100%"); 
    return;
  }
  
    if (PinOut == 3 || PinOut == 5 || PinOut == 6 || PinOut == 9 || PinOut == 10 || PinOut == 11)
    {
      BitProportion = (OnPc/100)*255;  // doesn't work because this forms a value less than 1
      Serial.print("PinOut is ");
      Serial.println(PinOut);
      Serial.print("On Duration is ");
      Serial.println(BitProportion);
      analogWrite(PinOut, BitProportion);
      Serial.println("Arduino PWM Set");
    }
    else
    {
      Serial.println("You cannot set this pin as an analogue output");
    }  
}


void PinSet_6()  // this will be a function that sets a pin at a certain rate
{
  // Message data is any ASCII bytes (0-255 value). But can't contain the field
  // separator, command separator chars you decide (eg ',' and ';')
  // this should only work for pins 3, 5, 6, 9, 10, and 11
  int counter;
  long value;
  int PinOut;  // this should only be certain pins
  int LowHigh;
 
 cmdMessenger.sendCmd(kACK,"Pin high-lo cmd received");
  for (counter = 0; cmdMessenger.available(); counter ++)
  {
    char buf[350] = { '\0' };
    cmdMessenger.copyString(buf, 350);
    if(buf[0])
      cmdMessenger.sendCmd(kACK, buf);  // this sends info to the serial print but it is not useful
      value = strtol(buf, NULL, 10);
      switch (counter) {
        case 0:
          PinOut = value;
          break;
        
        case 1:
          LowHigh = value;
          break;       
    }
  }
  if (LowHigh == 0)
  {
    digitalWrite(PinOut, LOW);
  }
  else
  {
    digitalWrite(PinOut, HIGH);
  }
}

void ReadPin_7()  // this will be a function that sets a pin at a certain rate
{
  // Message data is any ASCII bytes (0-255 value). But can't contain the field
  // separator, command separator chars you decide (eg ',' and ';')
  // this should only work for pins 3, 5, 6, 9, 10, and 11
  int counter;
  long value;
  int WhichPin;  // this should only be certain pins
  int PinValue;
 
 cmdMessenger.sendCmd(kACK,"Read pin cmd received");
  for (counter = 0; cmdMessenger.available(); counter ++)
  {
    char buf[350] = { '\0' };
    cmdMessenger.copyString(buf, 350);
    if(buf[0])
    //  cmdMessenger.sendCmd(kACK, buf);  // this sends info to the serial print but it is not useful
      value = strtol(buf, NULL, 10);
      switch (counter) {
        case 0:
          WhichPin = value;
          break;   
    }
  }
  PinValue = analogRead(WhichPin);
  Serial.println(PinValue);
}

void SetZero_8()
{
  int counter;
  long value;
  int whichepoch;
  cmdMessenger.sendCmd(8,"Set zero cmd received");
  for (counter = 0; cmdMessenger.available(); counter ++)
  {
    char buf[350] = { '\0' };
    cmdMessenger.copyString(buf, 350);
    if(buf[0])
      cmdMessenger.sendCmd(kACK, buf);
      value = strtol(buf, NULL, 10);
      switch (counter) {
        case 0:
          whichepoch = value;
          break;        
    }
  }
  
   epochduration[whichepoch] = 0;
   pulseduration[whichepoch] = 0; 
   pulseinterval[whichepoch] = 0;
   pulsenumber[whichepoch] = 0;
   portDBitValue[whichepoch] = 0;
   portBBitValue[whichepoch] = 0;
  Serial.print("Reset Epoch ");
  Serial.println(whichepoch);
}



void GetDC_9()
{
  int counter;
  long value;
  int whichepoch;
  cmdMessenger.sendCmd(9,"DC cmd received");
  for (counter = 0; cmdMessenger.available(); counter ++)
  {
    char buf[350] = { '\0' };
    cmdMessenger.copyString(buf, 350);
    if(buf[0])
      cmdMessenger.sendCmd(kACK, buf);
      value = strtol(buf, NULL, 10);
      switch (counter) {
        case 0:
          whichepoch = value;
          break;
        case 1:
          epochduration[whichepoch] = value;
          break;
        case 2:
          portDBitValue[whichepoch] = value;
          break;
        case 3:
          portBBitValue[whichepoch] = value;
          break;
    }
  }
  Serial.print("Which Epoch is ");
  Serial.println(whichepoch);
  Serial.print("Epoch Duration is ");
  Serial.println(epochduration[whichepoch]);
  Serial.print("portDBitValue is ");
  Serial.println(portDBitValue[whichepoch]);
  Serial.print("portBBitValue is ");
  Serial.println(portBBitValue[whichepoch]);
}

void GetPulse_10()
{
  int counter;
  long value;
  int whichepoch;

   cmdMessenger.sendCmd(10,"Pulse cmd received");
  for (counter = 0; cmdMessenger.available(); counter ++)
  {
    char buf[350] = { '\0' };
    cmdMessenger.copyString(buf, 350);
    if(buf[0])
      cmdMessenger.sendCmd(kACK, buf);
      value = strtol(buf, NULL, 10);
      switch (counter) {
        case 0:
          whichepoch = value;
          break;
        case 1:
          epochduration[whichepoch] = value;
          break;
        case 2:
          pulseduration[whichepoch] = value;
          break;
        case 3:
          pulseinterval[whichepoch] = value;
          break;
        case 4:
          pulsenumber[whichepoch] = value;
          break;
        case 5:
          portBBitValue[whichepoch] = value;
          break;
        case 6:
          portDBitValue[whichepoch] = value;
          break;
    }
  }
    
  Serial.print("Which Epoch is ");
  Serial.println(whichepoch);
  Serial.print("Epoch Duration is ");
  Serial.println(epochduration[whichepoch]);
  Serial.print("Pulse duration is ");
  Serial.println(pulseduration[whichepoch]);
  Serial.print("Pulse Interval is ");
  Serial.println(pulseinterval[whichepoch]);
  Serial.print("Pulse Number is ");
  Serial.println(pulsenumber[whichepoch]);
  Serial.print("portDBitValue is ");
  Serial.println(portDBitValue[whichepoch]);
  Serial.print("portBBitValue is ");
  Serial.println(portBBitValue[whichepoch]);
}




void ResetAll_11()    // this sets all of the data to zero. It can be called before number 12 to simplify things
{
  int counter;
  long value;
  int whichepoch;

  cmdMessenger.sendCmd(11,"Epochs Reset");
  for (counter = 0; cmdMessenger.available(); counter ++)
  {
    char buf[350] = { '\0' };
    cmdMessenger.copyString(buf, 350);
    if(buf[0])
      cmdMessenger.sendCmd(kACK, buf);
      value = strtol(buf, NULL, 10);
      switch (counter) {
        case 0:
          whichepoch = value;   
          break;        
    }
  }
  
  for (counter = 0; counter <10; counter ++)
  {
    epochtype[counter] = 0;
    epochduration[counter] = 0;
    pulseduration[counter] = 0;
    pulseinterval[counter] = 0;
    pulsenumber[counter] = 0;
    portDBitValue[counter] = 0;
    portBBitValue[counter] = 0;
  }
}

void GetRepsData_12()    // this receives information about the number of repeats, the sequence duration and the start-start interval
{
  int counter;
  long value;
    cmdMessenger.sendCmd(12,"Reps Cmd Received");
  for (counter = 0; cmdMessenger.available(); counter ++)
  {
    char buf[350] = { '\0' };
    cmdMessenger.copyString(buf, 350);
    if(buf[0])
      cmdMessenger.sendCmd(kACK, buf);
      value = strtol(buf, NULL, 10);
      switch (counter) {
        case 0:
          seqrepeats = value;
          break;
        case 1:
          seqduration  = value;  // the duration of the entire sequence
          break;
        case 2:
          seqinterval  = value;  // the interval between the start of the first and the next sequence
          break;
          
          
  
       
    }
  }
}

void GetEpochData_13()
{
  int counter;
  long value;
  int whichepoch;

   cmdMessenger.sendCmd(13,"Epoch Data Received");
  for (counter = 0; cmdMessenger.available(); counter ++)
  {
    char buf[350] = { '\0' };
    cmdMessenger.copyString(buf, 350);
    if(buf[0])
      cmdMessenger.sendCmd(kACK, buf);
      value = strtol(buf, NULL, 10);
      switch (counter) {
        case 0:
          whichepoch = value;
          break;
        case 1:
          epochtype[whichepoch]  = value;
          break;
        case 2:
          epochduration[whichepoch] = value;
          break;
        case 3:
          pulseduration[whichepoch] = value;
          break;
        case 4:
          pulseinterval[whichepoch] = value;
          break;
        case 5:
          pulsenumber[whichepoch] = value;
          break;
        case 6:
          portBBitValue[whichepoch] = value;
          break;
        case 7:
          portDBitValue[whichepoch] = value;
          break;
    }
  }
}



void StartSequence_14()  // this starts the sequence off.
{
  int counter;
  int pulsecounter;
  int seqcounter;
  int EpochType;
  int EpochDuration;
  int PulseDuration;
  int PulseInterval;
  int PulseNumber;
  int portD;  // pins 0:7
  int portB;  // pins 8:13
  int PulsesDuration;
  long Remainder;
  long SeqRemainder;
  
  cmdMessenger.sendCmd(14,"Sequence Started");
//  Serial.println("Sequence Started");
  for (seqcounter = 0; seqcounter < seqrepeats; seqcounter ++)
  {
   
    counter = 0;
    pulsecounter = 0;
     for (counter = 0; counter < 10; counter ++)
     {
        EpochType = epochtype[counter];    // this will be 1, 2 or 3
        EpochDuration = epochduration[counter];
        PulseDuration = pulseduration[counter];
        PulseInterval = pulseinterval[counter];
        PulseNumber = pulsenumber[counter];
        portD = portDBitValue[counter];
        portB = portBBitValue[counter];
        
        switch (EpochType) {
          case 1:    // here the epoch is off so do nothing
            break;
          case 2:    // this is DC so just set the bit patterns for the appropriate duration
            PORTB = portB;
            PORTD = portD;
            delay(EpochDuration);
           
            break;
          case 3:    // this is a pulse so need to send n pulses at an appropriate interval
             for (pulsecounter = 0; pulsecounter < PulseNumber; pulsecounter++)
             {
               PORTB =  portB;
               delay(PulseDuration);
               PORTB = 0;
               delay(PulseInterval);
             }
             // Need to check if there is more time in this epoch
             PulsesDuration = PulseInterval*PulseNumber;  // don't count the pulse duration because the pulse interval is the start to start interval
             Remainder = (EpochDuration-PulsesDuration);
             if (Remainder > 0){
               delay(Remainder);
             }
           break;
        }
     }
    // This is the delay between repetitions
    
        
    
    SeqRemainder = (seqinterval-seqduration);  // this will be in milliseconds
     Serial.print("SeqRepeats ");
        Serial.println(seqrepeats);
    Serial.print("SeqRemainder ");
        Serial.println(SeqRemainder);
        Serial.print("duration ");
        Serial.println(seqduration);
        Serial.print("interval ");
        Serial.println(seqinterval);
        
    if (SeqRemainder > 0){
       PORTB = 0;
       PORTD = 0; 
      delay(SeqRemainder);
     }
  }  
}



// ------------------ D E F A U L T C A L L B A C K S -----------------------

void arduino_ready()
{
  // In response to ping. We just send a throw-away Acknowledgement to say "im alive"
  cmdMessenger.sendCmd(kACK,"Arduino ready");
}

void unknownCmd()
{
  // Default response for unknown commands and corrupt messages
  cmdMessenger.sendCmd(kERR,"Unknown command");
}

// ------------------ E N D C A L L B A C K M E T H O D S ------------------



// ------------------ S E T U P ----------------------------------------------

void attach_callbacks(messengerCallbackFunction* callbacks)
{
  int i = 0;
  int offset = kSEND_CMDS_END;
  while(callbacks[i])
  {
    cmdMessenger.attach(offset+i, callbacks[i]);
    i++;
  }
}

void setup()
{
  // Listen on serial connection for messages from the pc
  Serial.begin(115200); // Arduino Uno, Mega, with AT8u2 USB

  // cmdMessenger.discard_LF_CR(); // Useful if your terminal appends CR/LF, and you wish to remove them
  cmdMessenger.print_LF_CR(); // Make output more readable whilst debugging in Arduino Serial Monitor
  
  // Attach default / generic callback methods
  cmdMessenger.attach(kARDUINO_READY, arduino_ready);
  cmdMessenger.attach(unknownCmd);

  // Attach my application's user-defined callback methods
  attach_callbacks(messengerCallbacks);

  arduino_ready();

  DDRD = DDRD | B11111100;  // this is safer as it sets pins 2 to 7 as outputs
  DDRB = DDRB | B00111111;  // this is safer as it sets pins 8 to 13 as outputs
  
  int PinNum;
  for (PinNum = 2; PinNum <=13; PinNum +=1)
  {
  pinMode(PinNum, OUTPUT);
    digitalWrite(PinNum, LOW);
  }
}


// ------------------ M A I N ( ) --------------------------------------------

// Timeout handling
long timeoutInterval = 2000; // 2 seconds
long previousMillis = 0;
int counter = 0;

void timeout()
{
  // blink
  if (counter % 2)
    digitalWrite(13, HIGH);
  else
    digitalWrite(13, LOW);
  counter ++;
}

void loop()
{
  // Process incoming serial data, if any
  cmdMessenger.feedinSerialData();

  // handle timeout function, if any
  if ( millis() - previousMillis > timeoutInterval )
  {
    timeout();
    previousMillis = millis();
  }

  // Loop.
}
