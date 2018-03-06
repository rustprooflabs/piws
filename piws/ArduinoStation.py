"""The ArduinoStation module collects data from serial port connected to
Arduino weather station(s).
"""
import os
import time
import datetime
import json
from serial import Serial, SerialException
from piws import db, config

LOGGER = config.LOGGER
# Set TimeZone
tzone = 'America/Denver'
os.environ['TZ'] = tzone



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

        # Set Serial Connection parameters
        self.serial_port_pattern = '/dev/ttyACM{port_num}'
        self.serial_port_num = None
        self.baudrate = 9600
        self.ser = self._setup_serial_connection()
        self.lines_per_observation = 3 # Sensor 1 (DHT11) has 2 readings, Sensor 2 has 1

    def _setup_serial_connection(self):
        """ Cycles through USB port numbers to attempt establishing connection to sensors."""
        conn_set = False
        serial_port_num = 0

        while not conn_set:
            try:
                serial_port = self.serial_port_pattern.format(port_num=serial_port_num)
                ser = Serial(port=serial_port, baudrate=self.baudrate)
                self.serial_port_num = serial_port_num
                conn_set = True
            except SerialException:
                msg = 'Could not establish connection with weather sensors on serial port %s.'
                LOGGER.warning(msg, serial_port)
                if serial_port_num < 4:
                    serial_port_num += 1
                else:
                    serial_port_num = 0

                time.sleep(1)

        msg = 'Connection established on port %s'
        LOGGER.info(msg, serial_port)
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

        self.lines = []

        while True:
            self._process_serial_data()

        ser.close()


    def _process_serial_data(self):
        line = self.ser.readline()

        # Empty lines from serial always seems to have 2 spaces
        if len(line) > 2:
            self.lines.append(line)

        if len(self.lines) >= self.lines_per_observation:
            observation = self._get_observation()
            LOGGER.debug('Adding Observersion: %s', observation)
            self._add_observation(observation)


    def _get_observation(self):

        key_value_sep = ':'
        i = 0
        observation = dict()

        while i < self.lines_per_observation:
            l = self.lines.pop()
            l = l.decode('utf-8')
            l = l.split(key_value_sep)
            key = l[0]
            try:
                value = float(l[1].rstrip())
            except IndexError:
                msg = 'Error parsing observation.  This is OK if it occurs once or twice when starting up.'
                LOGGER.warning(msg)
            observation[key] = value
            i += 1

        return observation

