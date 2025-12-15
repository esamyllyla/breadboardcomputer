#include <stdio.h>

#define DATA 3
#define CLK 2
#define RCLK 4
#define EEPROM_D0 5
#define EEPROM_D7 12
#define EEPROM_WE 13
#define MAX_PAGE 32768 / 64

int incomingByte = 0;
int pageToWrite = 0;

byte data[64];
int index = 0;
bool gotSomething = false;

void setAddress(int address, bool outputEnable)
{
  shiftOut(DATA, CLK, MSBFIRST, (address >> 8) | (outputEnable ? 0x00 : 0x80));
  shiftOut(DATA, CLK, MSBFIRST, address);

  digitalWrite(RCLK, LOW);
  digitalWrite(RCLK, HIGH);
  digitalWrite(RCLK, LOW);
}

byte readEEPROM(int address)
{
  for(int pin = EEPROM_D0; pin <= EEPROM_D7; pin++)
  {
    pinMode(pin, INPUT);
  }

  setAddress(address, /*output enable*/ true);
  byte data = 0;
  for(int pin = EEPROM_D7; pin >= EEPROM_D0; pin--)
  {
    data = (data << 1) + digitalRead(pin);
  }

  return data;
}

void writeEEPROM(int address, byte data)
{
  for(int pin = EEPROM_D0; pin <= EEPROM_D7; pin++)
  {
    pinMode(pin, OUTPUT);
  }

  setAddress(address, /*output enable*/ false);
  for(int pin = EEPROM_D0; pin <= EEPROM_D7; pin++)
  {
    digitalWrite(pin, data & 1);
    data = data >> 1;
  }

  digitalWrite(EEPROM_WE, LOW);
  delayMicroseconds(1);
  digitalWrite(EEPROM_WE, HIGH);
  delay(10);
}

void printPage(int address)
{
  for(int base = 0 + address; base <= 255 + address; base += 16)
  {
    byte data[16];
    for(int offset = 0; offset <= 15; offset += 1)
    {
      data[offset] = readEEPROM(base + offset);
    }
    char Page[128];
    sprintf(Page, "%03x: %02x %02x %02x %02x %02x %02x %02x %02x  %02x %02x %02x %02x %02x %02x %02x %02x",
      base, data[0], data[1], data[2], data[3], data[4], data[5], data[6], data[7], data[8], data[9], data[10], data[11], 
      data[12], data[13], data[14], data[15]);
    Serial.println(Page);
  }
}

void readAndPrintEntireMemory()
{
  for(int base = 0; base <= 0x7ff0; base += 16)
  {
    byte data[16];
    for(int offset = 0; offset <= 15; offset += 1)
    {
      data[offset] = readEEPROM(base + offset);
    }
    char Page[128];
    sprintf(Page, "%04x: %02x %02x %02x %02x %02x %02x %02x %02x  %02x %02x %02x %02x %02x %02x %02x %02x",
      base, data[0], data[1], data[2], data[3], data[4], data[5], data[6], data[7], data[8], data[9], data[10], data[11], 
      data[12], data[13], data[14], data[15]);
    Serial.println(Page);
  }
}

// the setup function runs once when you press reset or power the board
void setup() {
  Serial.begin(9600);
  // initialize digital pin LED_BUILTIN as an output.
  pinMode(DATA, OUTPUT);
  pinMode(CLK, OUTPUT);
  pinMode(RCLK, OUTPUT);
  digitalWrite(EEPROM_WE, HIGH);
  pinMode(EEPROM_WE, OUTPUT);

  digitalWrite(DATA, LOW);
  digitalWrite(CLK, LOW);
  digitalWrite(RCLK, LOW);
  setAddress(0, 0);
  delay(1000);

  writeEEPROM(0x3f, 0xea);
  writeEEPROM(0x0, 0xa9);
  //Serial.println("Ready");
  printPage(0x0);
  //readAndPrintEntireMemory();
}

void loop() 
{
  if(Serial.available() > 0)
  {
    gotSomething = true;
    data[index] = Serial.read();
    index++;
  }
  if(gotSomething)
  {
    char debug[64];
    sprintf(debug, "bytes received: %d", index);
    Serial.println(debug);
  }
  if(index >= 64)
  {
    Serial.println("64 bytes received: ");
    for(int base = 0; base < 64; base += 16)
    {
      char Page[128];
      sprintf(Page, "%03x: %02x %02x %02x %02x %02x %02x %02x %02x  %02x %02x %02x %02x %02x %02x %02x %02x", base, 
        data[base + 0], data[base + 1], data[base + 2], data[base + 3], data[base + 4], data[base + 5], data[base + 6], data[base + 7], data[base + 8],
        data[base + 9], data[base + 10], data[base + 11], data[base + 12], data[base + 13], data[base + 14], data[base + 15]);
      Serial.println(Page);
    }
    Serial.println("Start writing to EEPROM...");
    if(pageToWrite < (32768 / 64)) // 512 pages fit in the EEPROM
    {
      for(int DataByte = 0; DataByte < 64; DataByte++)
      {
        int Address = (pageToWrite * 64) + DataByte;
        writeEEPROM(Address, data[DataByte]);        
      }
      pageToWrite++;
    }
    Serial.println("64 bytes written");
    index = 0;
    char buff[32];
    sprintf(buff, "Next page to write is: %d", pageToWrite);
    Serial.println(buff);
    Serial.println("MESSAGE END");
  }
  //index = 0;
  gotSomething = false;
}
