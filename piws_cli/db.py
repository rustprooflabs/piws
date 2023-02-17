import psycopg
import psycopg_pool

import config


pool_default = psycopg_pool.ConnectionPool(config.DATABASE_STRING,
                                            min_size=config.POOL_MIN_SIZE,
                                            max_size=config.POOL_MAX_SIZE,
                                            max_idle=config.POOL_MAX_IDLE,
                                            timeout=config.POOL_TIMEOUT)


def get_data(sql_raw, params=None, single_row=False):
    """Main query point for all read queries.
    """
    if single_row:
        return _select_one(sql_raw, params)
    else:
        return _select_multi(sql_raw, params)


def _select_one(sql_raw, params):
    """ Runs SELECT query that will return zero or 1 rows.
    `params` is required but can be set to None if a LIMIT 1 is used.

    Parameters
    --------------------
    sql_raw : str
        Query string to execute.

    params : dict
        Parameters to pass into `sql_raw`

    Returns
    --------------------
    results
    """
    results = _execute_query(sql_raw, params, 'sel_single')
    return results


def _select_multi(sql_raw, params=None):
    """ Runs SELECT query that will return multiple (all) rows.

    Parameters
    --------------------
    sql_raw : str
        Query string to execute.

    params : dict
        (Optional) Parameters to pass into `sql_raw`

    Returns
    --------------------
    results
    """
    results = _execute_query(sql_raw, params, 'sel_multi')
    return results


def _execute_query(sql_raw, params, qry_type):
    """ Handles executing queries based on the `qry_type` passed in.

    Returns False if there are errors during connection or execution.

        if results == False:
            print('Database error')
        else:
            print(results)

    You cannot use `if not results:` b/c 0 results is a false negative.

    Parameters
    ---------------------
    sql_raw : str
        Query string to execute.

    params : dict
        (Optional) Parameters to pass into `sql_raw`

    qry_type : str
        Defines how the query is executed. e.g. `sel_multi`
        uses `.fetchall()` while `sel_single` uses `.fetchone()`.
    """
    sel_pool = pool_default

    with sel_pool.connection() as conn:
        cur = conn.cursor(row_factory=psycopg.rows.dict_row)

        try:
            if qry_type == 'sel_multi':
                results = cur.execute(sql_raw, params).fetchall()
            elif qry_type == 'sel_single':
                results = cur.execute(sql_raw, params).fetchone()
            else:
                raise Exception('Invalid query type defined.')
        except psycopg.OperationalError as err:
            config.LOGGER.error(f'Error querying: {err}')
        except psycopg.ProgrammingError as err:
            config.LOGGER.error('Database error via psycopg.  %s', err)
            results = False
        except psycopg.IntegrityError as err:
            config.LOGGER.error('PostgreSQL integrity error via psycopg.  %s', err)
            results = False

    return results

