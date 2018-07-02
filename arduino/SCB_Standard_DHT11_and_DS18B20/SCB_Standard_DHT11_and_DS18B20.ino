#include <OneWire.h>
#include <DallasTemperature.h>
#include <dht.h>

// Pin for DS18B20 Temp sensor
#define ONE_WIRE_BUS 11
OneWire oneWire(ONE_WIRE_BUS); 
DallasTemperature sensors(&oneWire);

// Pin for DHT11 Temp/Humidity sensor
dht DHT;
#define DHT11_PIN 5

void setup(){
  Serial.begin(9600);
  sensors.begin(); // Starts DallasTemperature lib
}

void ds18b20(){
  sensors.requestTemperatures();
  Serial.print("ds18b20_t:"); 
  Serial.println(sensors.getTempCByIndex(0));
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
