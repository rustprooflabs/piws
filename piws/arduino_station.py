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



def add_observation(observation):
    """ Builds observation and sends to PostgreSQL function."""
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
        """ Setup ArudinoStation object, including Serial data connection."""
        # FIXME:  IS this needed?
        super(ArduinoStation, self).__init__()

        self.serial_port_pattern = '/dev/ttyACM{port_num}'
        self.serial_port_num = None
        self.baudrate = 9600
        self.ser = self._setup_serial_connection()

        # Sensor 1 (DHT11) has 2 readings, Sensor 2 has 1
        self.lines_per_observation = 3

    def _setup_serial_connection(self):
        """ Cycles through USB port numbers to attempt establishing connection
        to sensors.
        """
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

    def collect_data(self):
        """ Sets up lines list and loops to collect serial data and add
        observations.
        """
        self.lines = []

        while True:
            self._process_serial_data()


    def _process_serial_data(self):
        line = self.ser.readline()

        # Empty lines from serial always seems to have 2 spaces
        if len(line) > 2:
            self.lines.append(line)

        if len(self.lines) >= self.lines_per_observation:
            observation = self._get_observation()
            LOGGER.debug('Adding Observersion: %s', observation)
            add_observation(observation)

    def _get_observation(self):
        """Pulls sensor readings, stuffs into dict."""
        key_value_sep = ':'
        i = 0
        observation = dict()

        while i < self.lines_per_observation:
            line = self.lines.pop()
            line = line.decode('utf-8')
            line = line.split(key_value_sep)
            key = line[0]
            try:
                value = float(line[1].rstrip())
            except IndexError:
                msg = 'Error parsing observation. '
                msg += 'This is OK once or twice when starting up.'
                LOGGER.warning(msg)
            observation[key] = value
            i += 1

        return observation
