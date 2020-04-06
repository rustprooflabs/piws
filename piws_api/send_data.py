import sys
import time
import requests
from piws_api import config, db

LOGGER = config.LOGGER


def run():
    """Control module to run the program to check for new observations to
    send to API.
    """
    LOGGER.info('Running PiWS API ( `send_data.run()` )')
    while True:
        try:
            process_observations()
        except Exception as e:
            LOGGER.error('There was an unhandled error while running.  %s', e)
        loop_delay = 15 + (config.RUN_DELAY * 5)
        LOGGER.debug('Sleeping %s seconds between loops.', loop_delay)
        time.sleep(loop_delay)


def process_observations():
    """ Loops through any pending observations and submits to API."""
    observations = get_new_observations()
    observation_count = len(observations)
    if observation_count > 0:
        LOGGER.info('%s new observations', observation_count)
    else:
        LOGGER.debug('0 new observations')

    for observation in observations:
        observation = observation[0]
        LOGGER.debug('Observation object type:  %s', type(observation))
        status_code = send_observation(observation)
        LOGGER.debug('API POST status code:  %s', status_code)
        if status_code == 201:
            observation_submitted(id=observation['id'])
        elif status_code == 401:
            error_msg = 'API call returned Unauthroized. '
            error_msg += 'Fix API Key and Sensor ID and try again.'
            sys.exit(error_msg)
        elif status_code == 404:
            error_msg = 'API URL not found.  Please check PiWS configuration and your internet connection.'
            LOGGER.warning(error_msg)
            extra_delay = config.RUN_DELAY * 10
            LOGGER.info('Delaying an extra %s seconds...', extra_delay)
            time.sleep(extra_delay)
        else:
            LOGGER.warning('Unhandled HTTP status code: %s', status_code)
        time.sleep(config.RUN_DELAY)


def get_new_observations():
    """Retrieves new observations from database using specific function.

    Each row returned is in JSON format."""
    sql_raw = 'SELECT * FROM piws.api_json()'
    params = list
    results = db.sel_multi(sql_raw, params)
    return results


def send_observation(observation):
    """Sends sensor observation to TYG API in JSON format."""
    observation['api_key'] = config.TYG_API_KEY
    observation['sensor_id'] = config.TYG_SENSOR_ID
    LOGGER.debug('Observation: %s', observation)

    url = '{api_host}/api/v1/sensor/'
    url = url.format(api_host=config.API_HOST)
    method = 'POST'
    try:
        response = requests.request(method=method,
                                    url=url,
                                    json=observation)
    except requests.exceptions.ConnectionError as e:
        LOGGER.error('API HTTP request error. URL.  %s \n Error: %s', url, e)
        return 404

    LOGGER.debug('Request response %s', response)
    return response.status_code


def observation_submitted(id):
    """Marks the quarter-hour observation as submitted in the
    PiWS database.
    """
    sql_raw = "SELECT * FROM piws.mark_submitted(%s::BIGINT)"
    params = [id]
    results = db.update(sql_raw, params)
    LOGGER.debug('Observation submitted for id: %s', id)
    LOGGER.debug('Query for marking submission complete: %s, %s', sql_raw, params)

