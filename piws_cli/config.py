"""" Configuration for Pi Weather Station (PiWS) CLI application.
"""
import os
import sys
import logging


APP_NAME = 'PiWS-CLI'


try:
    APP_LOG_LEVEL = os.environ['APP_LOG_LEVEL']
except KeyError:
    APP_LOG_LEVEL = 'INFO'


# Setup Logging
LOGGER = logging.getLogger(__name__)
LOG_FORMAT = '%(levelname)s - %(asctime)s - %(name)s - %(message)s'
LOG_FILENAME = 'piws_cli.log'
LOG_PATH = f'/var/log/piws/{LOG_FILENAME}'
try:
    HANDLER = logging.FileHandler(filename=LOG_PATH, mode='a+')
except FileNotFoundError:
    HANDLER = logging.FileHandler(filename=f'./{LOG_FILENAME}', mode='a+')
FORMATTER = logging.Formatter(LOG_FORMAT)
HANDLER.setFormatter(FORMATTER)
LOGGER.addHandler(HANDLER)
LOGGER.setLevel(APP_LOG_LEVEL)

LOGGER.debug('Logger configured')


try:
    DB_HOST, DB_NAME, DB_USER, DB_PW = (os.environ['DB_HOST'],
                                        os.environ['DB_NAME'],
                                        os.environ['DB_USER'],
                                        os.environ['DB_PW'])
    DB_CONN_AVAILABLE = True
except KeyError:
    key_msg = 'Database environment variables not set. '
    key_msg += 'All values are required for proper operation.\n'
    key_msg += 'DB_HOST\nDB_NAME\nDB_USER\nDB_PW\n'
    LOGGER.error(key_msg)
    DB_HOST, DB_NAME, DB_USER, DB_PW = ('127.0.0.1', 'NotSet',
                                        'Invalid', 'Invalid')

POOL_MIN_SIZE = 0
"""int : minimum size for the psycopg DB pool"""
POOL_MAX_SIZE = 2
"""int : maximum size for the psycopg DB pool"""
POOL_MAX_IDLE = 120
"""int : number of seconds before downsizing the pool due to inactivity"""
POOL_TIMEOUT = 5


try:
    DB_PORT = os.environ['DB_PORT']
except KeyError:
    DB_PORT = 5432
    msg = 'DB Port not set.  Defaulting to 5432'
    LOGGER.info(msg)


def get_db_string():
    """ Builds the database connection string based on set parameters."""
    database_string = 'postgresql://{user}:{pw}@{host}:{port}/{dbname}?application_name={app}'

    return database_string.format(user=DB_USER, pw=DB_PW, host=DB_HOST,
                                  port=DB_PORT, dbname=DB_NAME,
                                  app=APP_NAME)


DATABASE_STRING = get_db_string()
