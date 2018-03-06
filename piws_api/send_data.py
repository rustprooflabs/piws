import sys
import time
import requests
from piws_api import config, db

LOGGER = config.LOGGER

def run():
    """Control module to run the program to check for new observations to
    send to API.
    """
    LOGGER.info('Running PiWS API (send_data.run()')
    while True:
        process_observations()
        loop_delay = 15 + (config.RUN_DELAY * 5)
        LOGGER.debug('Sleeping %s seconds between loops.', loop_delay)
        time.sleep(loop_delay)


def process_observations():
    observations = get_new_observations()
    LOGGER.info('%s new observations', len(observations))

    for observation in observations:
        observation = observation[0]
        LOGGER.debug('Observation object type:  %s', type(observation))
        status_code = send_observation(observation)
        LOGGER.debug('API POST status code:  %s', status_code)
        if status_code == 201:
            observation_submitted(observation['end_15min'])
        elif status_code == 401:
            sys.exit('API call returned Unauthroized.  Fix API Key and Sensor ID and try again.')
        else:
            LOGGER.warning('Unhandled HTTP status code: %s', status_code)
        time.sleep(config.RUN_DELAY)


def get_new_observations():
    """Retrieves new observations from database using specific function.

    Each row returned is in JSON format."""
    sql_raw = 'SELECT * FROM piws.quarterhour_json()'
    params = list
    results = db.sel_multi(sql_raw, params)
    return results


def send_observation(observation):
    observation['api_key'] = config.TYG_API_KEY
    observation['sensor_id'] = config.TYG_SENSOR_ID
    LOGGER.debug('Observation: %s', observation)
    url = '{api_host}/sensor/readings/'.format(api_host=config.API_HOST)
    method = 'POST'
    response = requests.request(method=method, url=url, json=observation)
    LOGGER.debug('Request response %s', response)
    return response.status_code

def observation_submitted(end_15min):
    sql_raw = "SELECT * FROM piws.mark_quarterhour_submitted(%s::TIMESTAMPTZ)"
    params = [end_15min]
    results = db.insert(sql_raw, params)
    LOGGER.debug('Observation submitted PK for tracking: %s', results[0])

