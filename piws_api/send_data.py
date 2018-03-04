from piws_api import config, db

LOGGER = config.LOGGER

def run():
    LOGGER.info('Running PiWS API (send_data.run()')
    observations = get_new_observations()
    LOGGER.info('%s new observations', len(observations))

    # Grab in groups of 10
    ##   Send to API one at a time, pause 2 seconds between sends
    ##   At end of group, pause 10 seconds before grabbing next group of 10

def get_new_observations():
    sql_raw = 'SELECT * FROM piws.quarterhour_json()'
    params = list
    results = db.sel_multi(sql_raw, params)
    LOGGER.debug('Observation results:\n%s', results)
    return results


