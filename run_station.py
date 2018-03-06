"""Runs Pi Weather Station (PiWS) to collect observations from Arduino-based
Sensor Control Board via Serial connection.
"""
from serial import SerialException
from piws import arduino_station

if __name__ == '__main__':
    while True:
        station = arduino_station.ArduinoStation()

        try:
            station.collect_data()
        except SerialException:
            # Serial conn failed, destroy station and try again
            station = None
