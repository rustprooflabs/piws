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
        send_observation(observation)
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
    LOGGER.debug('Observation: %s', observation)
    url = '{api_host}/sensor/readings/'.format(api_host=config.API_HOST)
    method = 'POST'
    response = requests.request(method=method, url=url, json=observation)
    LOGGER.debug(response)
    LOGGER.debug(response.status_code)

