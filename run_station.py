from serial import SerialException
from piws import ArduinoStation

if __name__ == '__main__':
    while True:
        station = ArduinoStation.ArduinoStation()

        try:
            station.collect_data()
        except SerialException:
            station = None #Serial conn failed, destroy station and try again


