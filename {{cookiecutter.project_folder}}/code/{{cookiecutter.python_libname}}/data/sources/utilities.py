#!/usr/bin/env python
# -*- coding: utf-8 -*-
# pylint: disable=W1203

# STDlib imports
import os
import logging
# import datetime as dt

# 3rd party package imports
import numpy as np
import pandas as pd
from psycopg2 import connect as pc
from sqlalchemy import pool
from sqlalchemy import create_engine
# from pyedgar.utilities import localstore

# project imports
# from {{ cookiecutter.python_libname }} import constants as CONST
from {{ cookiecutter.python_libname }} import globals as GLOB


# Local logger
logger = logging.getLogger(__name__)
logger.setLevel(GLOB.LOG_LEVEL)


def string_to_int(x):
    """convert cik and gvkey to integers (ignoring nan and None)"""
    try:
        return int(x)
    except ValueError:
        return np.nan


class wrds_connection(object):
    """Creates a WRDS connection to the PostgreSQL server they run.
    Pulls username/password from the environmental variables WRDS_USER/WRDS_PASSWORD, which are set in globals.py if not already defined.

    Example usage::

        with wrds_connection() as conn:
            df_comp = conn.read_sql("SELECT * FROM comp.funda;", parse_dates=["datadate"])
    """
    wrds_user = None
    wrds_password = None
    psql_connection = None
    pool = None
    engine = None

    def __init__(self, wrds_user=None, wrds_password=None):
        """Creates a WRDS connection to the PostgreSQL server they run.
    Pulls username/password from the environmental variables WRDS_USER/WRDS_PASSWORD, which are set in globals.py if not already defined.

        Args:
            wrds_user (str, optional): WRDS Username. Defaults to `os.environ['WRDS_USER']`.
            wrds_password (str, optional): WRDS Password. Defaults to `os.environ['WRDS_PASSWORD']`.
        """
        self.wrds_user = wrds_user or os.environ.get('WRDS_USER', None)
        self.wrds_password = wrds_password or os.environ.get('WRDS_PASSWORD', None)

    def connect(self):
        self.psql_connection = pc(
            dbname="wrds",
            user=self.wrds_user,
            host='wrds-pgdata.wharton.upenn.edu',
            port=9737,
            password=self.wrds_password,
            sslmode='require')

        return self.psql_connection

    def get_engine(self):
        if self.pool is None:
            self.pool = pool.QueuePool(self.connect)

        self.engine = create_engine("postgresql://", pool=self.pool)

        return self.engine

    def __enter__(self):
        if self.psql_connection is None:
            self.connect()

        return self

    def __exit__(self, *args, **kwargs):
        try:
            self.psql_connection.close()
            self.psql_connection = None
        except:
            pass

    def read_sql(self, sql_statement, *args, **kwargs):
        return pd.read_sql(sql_statement, self.psql_connection, *args, **kwargs)
