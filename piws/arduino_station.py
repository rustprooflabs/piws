"""The ArduinoStation module collects data from serial port connected to
Arduino weather station(s).
"""
import os
import time
import datetime
import pytz
import json
from serial import Serial, SerialException
from piws import db, config

LOGGER = config.LOGGER

def add_observation(observation):
    """ Builds observation and sends to PostgreSQL function.
    
    Parameters
    --------------------
    observation : dict
    """
    tstamp = datetime.datetime.now(tz=pytz.UTC)

    sql_raw = 'SELECT * FROM piws.insert_observation(%s::TIMESTAMPTZ, '
    sql_raw += ' %s::JSONB) '
    params = [tstamp,
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
        ## FIXME:  Should look for key pairs in list and submit when no more unique readings are coming through
        if config.SCB_CONFIGURATION == 'standard':
            self.lines_per_observation = 3
        else:
            self.lines_per_observation = 7 # Allows for up to 5 DS18B20 along w/ DHT-11.

    def _setup_serial_connection(self):
        """ Cycles through USB port numbers to attempt establishing connection
        to sensors.
        """
        conn_set = False
        serial_port_num = 0

        attempts = 0
        delay = 5

        LOGGER.info('Attempting to esablish connection with sensors...')

        while not conn_set:
            try:
                serial_port = self.serial_port_pattern.format(port_num=serial_port_num)
                ser = Serial(port=serial_port, baudrate=self.baudrate)
                self.serial_port_num = serial_port_num
                conn_set = True
            except SerialException:
                attempts += 1
                msg = 'Could not establish connection w/ SCB via serial port %s. '
                msg += 'Attempts: %s'

                LOGGER.debug(msg, serial_port, attempts)

                if serial_port_num < 2:
                    serial_port_num += 1
                else:
                    serial_port_num = 0

                time.sleep(delay)

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
        i = 0

        # Gets unique observation lines
        observation_lines = set()
        while i < self.lines_per_observation:
            line = self.lines.pop()
            observation_lines.add(line)
            i += 1

        LOGGER.debug('Observation lines:  %s', observation_lines)
        observation = self._parse_sensor_observation(observation_lines)                    
        return observation


    def _parse_sensor_observation(self, observation_lines):
        """Parses sensor observations and loads into dict.

        Parameters
        --------------------
        observation_lines : list
        
        Returns
        --------------------
        observation : dict
        """
        observation = dict()
        ds18b20_uq = list()

        for line in observation_lines:
            sensor_line = self._decode_sensor_line(line)
            key = sensor_line[0]

            try:
                value = float(sensor_line[1].rstrip())

                # If DS18B20 is part of Expanded firmware... the trailing underscore indicates unique ID is following
                if key[:10] == 'ds18b20_t_':
                    node_unique_id = key[10:]
                    uq_kv = {node_unique_id: value}
                    ds18b20_uq.append(uq_kv)
                else:
                    observation[key] = value

            except IndexError:
                msg = 'Error parsing observation. '
                msg += 'This is OK once or twice when starting up.'
                LOGGER.warning(msg)
            except ValueError as e:
                msg = 'Error parsing observation.  Invalid value:  %s'
                LOGGER.error(msg, e)




        if len(ds18b20_uq) > 0:
            observation['ds18b20_t_uq'] = ds18b20_uq

        return observation


    def _decode_sensor_line(self, line):
        """ Decodes a single line representing the individual observation from a single sensor node."""
        key_value_sep = ':'
        line = line.decode('utf-8')
        line = line.split(key_value_sep)
        return line

