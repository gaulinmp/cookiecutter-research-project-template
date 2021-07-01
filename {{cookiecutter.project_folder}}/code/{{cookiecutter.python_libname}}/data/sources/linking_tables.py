#!/usr/bin/env python
# -*- coding: utf-8 -*-
# pylint: disable=W1203

# STDlib imports
import os
import logging
import datetime as dt

# 3rd party package imports
# import numpy as np
import pandas as pd
# from psycopg2 import connect as pc
# from pyedgar.utilities import localstore
from reslib.data.cache import DataFrameCache

# project imports
from {{ cookiecutter.python_libname }} import globals as GLOB
from {{ cookiecutter.python_libname }}.data.sources.utilities import string_to_int, wrds_connection


# Local logger
logger = logging.getLogger(__name__)
logger.setLevel(GLOB.LOG_LEVEL)


class gvkey_cik_link(DataFrameCache):
    """
    Read GVKEY-CIK link from cache if it exists,
    or read from WRDS Postrgres server, and write out to
    `interim` cache folder.
    """
    # Arguments passed to pd.read_csv
    read_args = {'parse_dates': 'datadate'.split()}

    def make_dataset(self):
        funda_query = """
            SELECT CAST(gvkey AS integer) AS gvkey
                ,datadate, fyear, fyr, cik AS cik_funda
            FROM comp.funda
            WHERE INDFMT = 'INDL'
                AND (DATAFMT = 'STD')
                AND (POPSRC = 'D')
                AND (CONSOL = 'C')
                AND (fyear > 1990)
                AND gvkey IS NOT NULL
            ORDER BY gvkey, datadate, fyr;"""

        hist_query = """
                SELECT CAST(gvkey AS integer) AS gvkey,
                    hcik AS cik_comphist,
                    hchgdt AS link_start,
                    hchgenddt AS link_end
                FROM crsp.comphist
                ORDER BY gvkey, link_start;"""

        with wrds_connection() as conn:
            df_comp = conn.read_sql(funda_query, parse_dates='datadate '.split())
            df_hist = conn.read_sql(hist_query, parse_dates='link_start link_end'.split())

        _firmvar = 'gvkey'
        _datevar = 'datadate'

        # Beginning and ending link dates do not all exist, therefore
        # we fill them in when missing using extreme min/max dates
        df_hist.loc[df_hist.link_start.isnull(), 'link_start'] = dt.datetime(1970,1,1)
        df_hist.loc[df_hist.link_end.isnull(), 'link_end'] = dt.datetime(2030,1,1)
        df_hist['cik_comphist'] = df_hist.groupby(_firmvar)['cik_comphist'].ffill()
        df_hist['cik_comphist'] = df_hist.groupby(_firmvar)['cik_comphist'].bfill()
        df_hist = df_hist[df_hist.cik_comphist.notnull()]

        # Prepare comp for merging
        _unique = [_firmvar,]
        for c in [_datevar, 'fyr', 'fyear']:
            if df_comp.duplicated(_unique).any():
                if c in df_comp and c not in _unique:
                    _unique.append(c)

        _d = df_comp.merge(df_hist, on=_firmvar, how='inner')

        # Should only be one gvkey-cik link per period
        _d = (_d[_d[_datevar].between(_d.link_start, _d.link_end)]
                .drop('link_start link_end'.split(), axis=1)
                .sort_values(_unique))

        _fill = 'cik_funda cik_comphist'.split()

        _d[_fill] = _d.groupby(_firmvar)[_fill].fillna(method='ffill')
        _d[_fill] = _d.groupby(_firmvar)[_fill].fillna(method='bfill')

        _d['cik'] = _d['cik_comphist'].fillna(_d['cik_funda'])

        return _d[_d.cik.notnull()]
