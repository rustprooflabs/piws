#include <OneWire.h>
#include <DallasTemperature.h>
#include <dht.h>

// Pin for DS18B20 Temp sensor
#define ONE_WIRE_BUS 11
#define MAX_DS18B20 10
OneWire oneWire(ONE_WIRE_BUS); 
DallasTemperature sensors(&oneWire);

// Pin for DHT11 Temp/Humidity sensor
dht DHT;
#define DHT11_PIN 5

// Parameters for multiple DS18B20 sensors
uint8_t num_sensors = 0;
DeviceAddress ds_addresses[MAX_DS18B20];
String adr[10];

void setup(){
  Serial.begin(9600);
  sensors.begin(); // Starts DallasTemperature lib
}

void printAddress(DeviceAddress deviceAddress, uint8_t m)
{
  adr[m] = "";
  
  for (uint8_t i = 0; i < 8; i++)
  {
    // zero pad the address if necessary
    
    if (deviceAddress[i] < 16) Serial.print("0");
    Serial.print(deviceAddress[i], HEX);
    
    if (deviceAddress[i] < 16 ) adr[m] = adr[m] + 0;
    adr[m] = adr[m] + (deviceAddress[i], HEX);
  }
}

void ds18b20(){
  sensors.requestTemperatures();
  
  for (int i=0; i<num_sensors; i++) {
    Serial.print("ds18b20_t_");
    printAddress(ds_addresses[i], i);
    Serial.print(":"); 
    Serial.println(sensors.getTempCByIndex(i));
  }
}

void dht11(){
  int chk = DHT.read11(DHT11_PIN);
  Serial.print("dht11_t:");
  Serial.println(DHT.temperature);
  Serial.print("dht11_h:");
  Serial.println(DHT.humidity);
}

void loop() {
   dht11();
   ds18b20();
   delay(5000);
}
