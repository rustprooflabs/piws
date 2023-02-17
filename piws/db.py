# -*- coding: utf-8 -*-
""" Database helper module to make interactions with psycopg2 easier. """
import psycopg

from piws import config


def insert(sql_raw, params):
    """ Runs Insert query, returns result.

     Returned result is typically the newly created PRIMARY KEY value from
     the database.
     """
    return _execute_query(sql_raw, params, 'insert')


def _execute_query(sql_raw, params, qry_type):
    """ Handles executing all types of queries based on the `qry_type`
    passed in.
    """
    conn = psycopg.connect(config.DATABASE_STRING)
    cur = conn.cursor(row_factory=psycopg.rows.dict_row)
    cur.execute(sql_raw, params)

    if qry_type == 'sel_single':
        results = cur.fetchone()
    elif qry_type == 'sel_multi':
        results = cur.fetchall()
    elif qry_type == 'insert':
        results = cur.fetchone()
        conn.commit()
    elif qry_type == 'update':
        results = cur.fetchone()
        conn.commit()
    else:
        raise Exception('Invalid query type defined.')

    conn.close()
    return results
