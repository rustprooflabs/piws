import sys
import time
import requests
from piws_api import config, db

LOGGER = config.LOGGER

def run():
    """Control module to run the program to check for new observations to
    send to API.
    """
    run_delay = 1.0
    LOGGER.info('Running PiWS API (send_data.run()')
    observations = get_new_observations()
    LOGGER.info('%s new observations', len(observations))

    for observation in observations:
        observation = observation[0]
        LOGGER.debug('Observation object type:  %s', type(observation))
        status_code = send_observation(observation)
        LOGGER.debug('API POST status code:  %s', status_code)
        if status_code == 401:
            sys.exit('API call returned Unauthroized.  Fix API Key and Sensor ID and try again.')
        time.sleep(run_delay)


    # Grab in groups of 10
    ##   Send to API one at a time, pause 2 seconds between sends
    ##   At end of group, pause 10 seconds before grabbing next group of 10

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
    return response.status_code

