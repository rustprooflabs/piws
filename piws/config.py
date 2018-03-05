""" Configuration for Pi Weather Station (PiWS).
"""
import os
import logging

CURR_PATH = os.path.abspath(os.path.dirname(__file__))
PROJECT_BASE_PATH = os.path.abspath(os.path.join(CURR_PATH, os.pardir))

try:
    APP_LOG_LEVEL = os.environ['APP_LOG_LEVEL']
except KeyError:
    APP_LOG_LEVEL = 'INFO'


LOGGER = logging.getLogger(__name__)
LOG_FORMAT = '%(levelname)s - %(asctime)s - %(name)s - %(message)s'
LOG_PATH = '/var/log/piws/piws.log'
HANDLER = logging.FileHandler(filename=LOG_PATH, mode='a+')
FORMATTER = logging.Formatter(LOG_FORMAT)
HANDLER.setFormatter(FORMATTER)
LOGGER.addHandler(HANDLER)
LOGGER.setLevel(APP_LOG_LEVEL)


try:
    DB_HOST, DB_NAME, DB_USER, DB_PW = (os.environ['DB_HOST'],
                                        os.environ['DB_NAME'], os.environ['DB_USER'],
                                        os.environ['DB_PW'])
    DB_CONN_AVAILABLE = True
except KeyError:
    key_msg = ('Database environment variables not set.  All values are required for proper operation.\n'
               'DB_HOST\nDB_NAME\nDB_USER\nDB_PW\n')
    LOGGER.error(key_msg)
    DB_HOST, DB_NAME, DB_USER, DB_PW = ('127.0.0.1', 'NotSet', 'Invalid', 'Invalid')


try:
    DB_PORT = os.environ['DB_PORT']
except KeyError:
    DB_PORT = 5432
    msg = 'DB Port not set.  Defaulting to 5432'
    LOGGER.debug(msg)


def get_db_string():
    """ Builds the database connection string based on set parameters."""
    database_string = 'postgresql://{user}:{pw}@{host}:{port}/{dbname}'

    return database_string.format(user=DB_USER, pw=DB_PW, host=DB_HOST,
                                  port=DB_PORT, dbname=DB_NAME)


DATABASE_STRING = get_db_string()

