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
from reslib.data.cache import DataFrameCache

# project imports
# from {{ cookiecutter.python_libname }} import constants as CONST
from {{ cookiecutter.python_libname }} import globals as GLOB
from {{ cookiecutter.python_libname }}.data.sources.utilities import wrds_connection


# Local logger
logger = logging.getLogger(__name__)
logger.setLevel(GLOB.LOG_LEVEL)


class CRSP(DataFrameCache):
    """
    Read Compustat data from cache if it exists,
    or read from WRDS Postrgres server, and write out to
    `interim` cache folder.
    """
    # Arguments passed to pd.read_csv
    read_args = {'parse_dates': 'datadate lag_datadate'.split()}

    def make_dataset(self):
        # Build sub-queries
        sql_comp_dates = """
            SELECT a.*, b.datadate, b.fyear
                ,make_date(CAST(extract(year from b.datadate) - 1 AS INTEGER),
                        CAST(extract(month from b.datadate) AS INTEGER),
                        CAST(extract(day from b.datadate) AS INTEGER) - 1 ) + 2 AS lag_datadate
            FROM (SELECT * FROM crsp.ccm_lookup WHERE lpermno IS NOT NULL) AS a
            INNER JOIN (SELECT gvkey, datadate, fyear FROM comp.funda
                        WHERE datadate > '1990-01-01'::date
                        AND INDFMT = 'INDL' AND DATAFMT = 'STD' AND POPSRC = 'D' AND CONSOL = 'C') AS b
                ON a.gvkey = b.gvkey
                AND b.datadate BETWEEN a.linkdt AND COALESCE(a.linkenddt, CURRENT_DATE)
            WHERE a.gvkey IS NOT NULL
                AND a.lpermno IS NOT NULL
                AND b.datadate IS NOT NULL
        """

        sql_msf = f"""
            SELECT b.gvkey, b.datadate, b.lag_datadate, b.fyear
                , a.permno, a.permco, a.date, ABS(a.prc) AS prc, a.vol, a.ret, a.shrout
            FROM crsp.msf AS a
            INNER JOIN ({sql_comp_dates}) AS b
                ON a.permno = b.lpermno
                AND a.date BETWEEN b.lag_datadate AND b.datadate
        """

        sql_crsp = f"""
            SELECT DISTINCT gvkey, datadate, lag_datadate, fyear, permno, permco
                ,SUM(vol) AS total_vol
                ,EXP(SUM(LOG(ret + 1)))-1 as cum_ret
                ,AVG(ret) as ave_ret
                ,AVG(shrout) AS ave_shrout
            FROM ({sql_msf}) AS c
            GROUP BY gvkey, datadate, lag_datadate, fyear, permno, permco
        """

        with wrds_connection() as conn:
            df = conn.read_sql(sql_crsp,
                parse_dates='datadate lag_datadate'.split())

        return df
