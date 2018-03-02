"""The ArduinoStation module collects data from serial port connected to
Arduino weather station(s).
"""
import sys
import os
import datetime
import json
from serial import Serial, SerialException
from piws import db


# Set TimeZone
tzone = 'America/Denver'
os.environ['TZ'] = tzone

# Set Serial Connection parameters
port = '/dev/ttyACM0'
baudrate = 9600


def convert_c_to_f(temp_c):
    """Converts temp (C) to temp (F)."""
    try:
        temp_f = (temp_c * 1.8) + 32
        temp_f = round(temp_f, 2)
    except TypeError:
        temp_f = False
    return temp_f


class ArduinoStation():

    def __init__(self):
        super(ArduinoStation, self).__init__()
        self.ser = self._setup_serial_connection()

    def _setup_serial_connection(self):
        try:
            ser = Serial(port=port, baudrate=baudrate)
        except SerialException:
            sys.exit('Could not establish connection with weather sensors.')
        return ser

    def _add_observation(self, observation):
        tstamp = datetime.datetime.today()
        obs_date = tstamp.date()
        obs_date_sql = '{year}-{month}-{day}'
        obs_date_sql = obs_date_sql.format(year=obs_date.year,
                                           month=obs_date.month,
                                           day=obs_date.day)

        obs_time = tstamp.time()
        obs_time_sql = '{hour}:{minute}:{second}'
        obs_time_sql = obs_time_sql.format(hour=obs_time.hour,
                                           minute=obs_time.minute,
                                           second=obs_time.second)

        sql_raw = 'SELECT * FROM piws.insert_observation(%s::INT, %s::DATE, '
        sql_raw += '%s::TIME,  %s::TEXT, %s::JSONB) '
        params = [1,
                  obs_date_sql,
                  obs_time_sql,
                  tzone,
                  json.dumps(observation, ensure_ascii=False)]
        db.insert(sql_raw, params)


    def collect_data(self):

        lines = []
        lines_per_observation = 3 # Sensor 1 (DHT11) has 2 readings, Sensor 2 has 1
        key_value_sep = ':'

        while True:
            line = self.ser.readline()

            # Empty lines from serial always seems to have 2 spaces
            if len(line) > 2:
                lines.append(line)

            if len(lines) >= lines_per_observation:
                i = 0
                observation = dict()

                while i < lines_per_observation:
                    l = lines.pop()
                    l = l.decode('utf-8')
                    l = l.split(key_value_sep)
                    key = l[0]
                    value = float(l[1].rstrip())
                    observation[key] = value

                    i += 1

                self._add_observation(observation)

        ser.close()


station = ArduinoStation()
station.collect_data()
