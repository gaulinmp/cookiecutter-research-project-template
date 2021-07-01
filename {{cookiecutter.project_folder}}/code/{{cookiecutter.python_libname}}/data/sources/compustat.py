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


class CompustatAnnual(DataFrameCache):
    """
    Read Compustat data from cache if it exists,
    or read from WRDS Postrgres server, and write out to
    `interim` cache folder.
    """
    # Arguments passed to pd.read_csv
    read_args = {'parse_dates': 'datadate rdq funda_start fundq_start'.split()}

    def make_dataset(self):
        # Build sub-queries
        gics = """
            SELECT gvkey AS gvkey_hgic, ggroup AS ggroup_hgic, gind AS gind_hgic,
                    gsector AS gsector_hgic, gsubind AS gsubind_hgic,
                    indfrom AS indfrom_hgic, indthru AS indthru_hgic
            FROM comp.co_hgic"""

        company = """
            SELECT DISTINCT gvkey AS gvkey_cmpn, costat, dlrsn, fic, idbflag, incorp,
                loc, naics, sic AS sic_cmpn, dldte, ipodate,
                ggroup AS ggroup_cmpn, gind AS gind_cmpn,
                gsector AS gsector_cmpn, gsubind AS gsubind_cmpn
            FROM comp.company
            ORDER BY gvkey"""

        # final FUNDA query
        funda_query = """
            SELECT CAST(a.gvkey AS integer) as gvkey
                ,a.datadate, a.fyear, a.fyr, 4 AS fqtr
                ,q.datafqtr, q.datacqtr, q.rdq
                ,ast.funda_start, qst.fundq_start
                ,a.tic, a.cusip, a.exchg
                ,a.sich, a.cik AS cikh
                ,a.conm AS name_compustat
                ,aco, acqmeth, act, aoloch, ap, apalch, aqc, aqs, at
                ,capx, ceq, che, cogs, dlc, dltt, dp, dpc, dv, dvc
                ,dvt, ebit, ebitda, emp, epspx, fincf, gdwl, ib
                ,intan, intano, invch, invt, ivncf, lco, lct, lt
                ,ni, oancf, oiadp, oibdp, pi, ppegt, ppent, re
                ,recch, rect, sale, sppe, txach, txdb, txp, wcap
                ,xad, xrd, xsga
                ,(oancf - xidoc) AS cfo
                ,(COALESCE(dltt, 0) + COALESCE(dlc, 0)) AS total_debt
                ,prcc_f AS comp_price, csho AS comp_shrout
                ,a.prcc_f * a.csho  AS mve
                ,prstkc - pstkrv AS repo
                ,COALESCE(seq /* Shareholder Equity is reported SE if not missing */
                    /* if SEQ missing, use Total Common Equity plus Preferred Stock Par Value  */
                    ,ceq + pstk
                    /* otherwise, Total Assets-(Total Liabilities+Minority Interest) */
                    ,at - lt - COALESCE(mib, 0))
                    AS seq
                /* BE is the book value of stockholders equity */
                ,COALESCE(seq, ceq + pstk, at - lt - COALESCE(mib, 0)) /* seq */
                    /* plus balance sheet deferred taxes and investment tax credit (if available) */
                    + COALESCE(txditc, 0)
                    /* minus the book value of preferred stock. Depending on availability,
                    we use the redemption, liquidation, or par value (in that order)
                    to estimate the book value of preferred stock. */
                    - COALESCE(pstkr, pstk, 0)
                    AS bve
                ,CASE
                    WHEN CAST (a.au AS INTEGER) IN (1, 4, 5, 6, 7) THEN 1
                    ELSE 0
                END AS bign
                ,auop
                ,cmpn.*
                ,gics.*
            FROM (
                SELECT *
                FROM comp.funda
                WHERE INDFMT = 'INDL'
                    AND (DATAFMT = 'STD')
                    AND (POPSRC = 'D')
                    AND (CONSOL = 'C')
                    AND (fyear > 1990)
                    AND gvkey IS NOT NULL
                    AND fyr IS NOT NULL
                ) a
            LEFT JOIN (
                SELECT *
                FROM comp.fundq
                WHERE (INDFMT = 'INDL')
                    AND (DATAFMT = 'STD')
                    AND (POPSRC = 'D')
                    AND (CONSOL = 'C')
                    AND (fyearq > 1990)
                    AND gvkey IS NOT NULL
                    AND fyr IS NOT NULL
                    AND fqtr = 4
                ) q
                ON (q.gvkey = a.gvkey)
                AND (q.fyearq = a.fyear)
                AND (q.fyr = a.fyr)
            LEFT JOIN (SELECT gvkey, MIN(datadate) AS funda_start
                    FROM comp.funda GROUP BY gvkey) ast
                ON (COALESCE(q.gvkey, a.gvkey) = ast.gvkey)
            LEFT JOIN (SELECT gvkey, MIN(datadate) AS fundq_start
                    FROM comp.fundq GROUP BY gvkey) qst
                ON (COALESCE(q.gvkey, a.gvkey) = qst.gvkey)
            LEFT JOIN ({0}) AS cmpn
                ON (COALESCE(q.gvkey, a.gvkey) = cmpn.gvkey_cmpn)
            LEFT JOIN ({1}) AS gics
                ON (COALESCE(a.gvkey, q.gvkey) = gics.gvkey_hgic
                    AND gics.indfrom_hgic <= a.datadate
                    AND a.datadate <= COALESCE(gics.indthru_hgic, current_date))
            ORDER BY a.gvkey, a.datadate, a.fyr;""".format(company, gics)


        with wrds_connection() as conn:
            df_comp = conn.read_sql(funda_query,
                parse_dates='datadate rdq funda_start fundq_start indfrom_hgic indthru_hgic'.split())


        for c in 'gvkey_seg fyear_seg'.split():
            if c in df_comp:
                del df_comp[c]

        return df_comp

    def _post_read_hook(self, read_data=None, **kwargs):
        # kwargs = {**self.postread_args, **kwargs}
        # Duplicate named column from sql read have .1 appended. Delete them.
        for c in read_data.filter(like='.1'):
            del read_data[c]

        df = read_data.sort_values('gvkey fyear'.split()).reset_index(drop=True)

        # Add lags
        for c in 'at sale epspx xrd xsga'.split():
            df[f'lag_{c}'] = pd.merge(df['gvkey fyear'.split()],
                                      df[f'gvkey fyear {c}'.split()]
                                            .assign(fyear=lambda x: x.fyear+1),
                                    on='gvkey fyear'.split(), how='left')[c]

        # Following Collins et. al 2017 TAR, set some vars =  0 if missing;
        sel = df['aoloch'].notnull()
        fill_cols = 'recch invch apalch txach'.split()
        for c in fill_cols:
            df.loc[sel & df[c].isnull(), c] = 0
        df[df[fill_cols].notnull().all(axis=1) & df['aoloch'].isnull()] = 0

        fill_cols = 'xrd capx aqc sppe xsga'.split()
        df[fill_cols] = df[fill_cols].fillna(0)

        # Add simple eval-able calculations:
        equations = """
        log_at             =  log(at)                         # log is natural log
        log_mve            =  log(mve)
        ave_at             =  (at + lag_at)/2
        act_comp           =  che + aco + invt + rect         # Computed ACT for when it's missing
        lct_comp           =  ap + lco + dlc + txp            # Computed LCT for when it's missing
        wcap_del_na       =  act.fillna(act_comp) - lct.fillna(lct_comp)    # eval fillNA workaround
        wcap               =  wcap.fillna(wcap_del_na)                      # delete _del_na var after
        # ratios
        lev_book           =  total_debt / at                 # Book leverage: debt / assets
        lev_mkt            =  total_debt / (at + mve - bve)   # Market leverage: debt over market assets
        btm                =  bve / mve                       # Book to Market: Book equity / market equity
        tobinsq            =  (at + mve - bve) / at
        zscore_private     =  (.717*wcap + 0.847*re + 3.107*pi + 0.998*sale)/at + 0.42*bve/lt
        zscore_public      =  ( 1.2*wcap +   1.4*re +   3.3*pi + 0.999*sale)/at + 0.60*mve/lt
        zscore_modified    =  ( 1.2*wcap +   1.4*re +   3.3*pi + 0.999*sale)/at
        liquidity          =  act.fillna(act_comp) / lct.fillna(lct_comp)
        tangibility        =  ppent / at
        tangibility_berger =  (0.715*rect + 0.547 * invt + 0.535 * ppent + che) / at # Berger et al
        asset_maturity     =  (ppegt**2 / (at * dp)) + (act.fillna(act_comp)**2 / (at * cogs))
        k_structure        =  dltt / (dltt + mve)
        cfo_sale           =  cfo / sale
        slack              =  che / ppent
        cash_at            =  che / at
        sales_growth       =  (sale - lag_sale) / lag_sale
        assets_growth      =  (at - lag_at) / lag_at
        roa_ib             =  ib / at
        roa_oiadp          =  oiadp / at
        roe_ib             =  ib / seq
        roe_oiadp          =  oiadp / seq
        profitmargin_ib    =  ib / sale
        profitmargin_oiadp =  oiadp / sale
        asset_turnover     =  sale / at
        rd_at              =  xrd / lag_at
        investment_at      =  (xrd + capx + aqc - sppe) / lag_at
        investment_sga_at  =  (xsga + capx + aqc - sppe) / lag_at
        cfo_ave_at         =  cfo / ave_at
        sale_ave_at        =  sale / ave_at
        ch_sale_ave_at     =  (sale - lag_sale) / ave_at
        ppe_ave_at         =  ppegt / ave_at
        ch_eps             =  (epspx - lag_epspx) / lag_epspx
        emp_ave_at         =  emp / ave_at
        div_ib             =  dvc / ib
        capx_mve           =  capx / (mve + dltt)
        operatingcycle     =  log(((rect/sale) + (invt/cogs)) * 360)
        invgrowth          =  log(xrd) - log(lag_xrd)
        invgrowth_sga      =  log(xsga) - log(lag_xsga)
        accruals           =  -(recch + invch + apalch + txach + aoloch + dpc)
        # accruals from Hribar & Collins (2002), based on Statement of CF
        """.strip()

        # Remove comment lines
        equations = [x for x in equations.split('\n')
                        # if empty line, (x.strip or #) will == #, gets dropped
                     if (x.strip() or '#')[0] != '#']
        # Now add variables, all at once!
        df.eval('\n'.join(equations), inplace=True, engine='python')


        # Add complex calculations
        # Note: comparisons with NaN result in False.
        # e.g. loss=IB < 0 will be False when IB is missing.
        # So one must manually set the outcome to missing.

        # dividend =  0; IF dvc > 0 or dv > 0 THEN dividend = 1;
        df['dividend'] = (df['dvc'].fillna(0) + df['dv'].fillna(0))>0+0.0
        df.loc[df['dvc'].isnull() & df['dv'].isnull(), 'dividend'] = np.nan
        # loss = 0; IF ib < 0 THEN loss = 1;
        df['loss'] = df['ib']<0+0.0
        df.loc[df['ib'].isnull(), 'loss'] = np.nan
        # invgrowth_total    =  log(xrd + capx + aqc - sppe) - log(lag_totinv)  * where    lag_totinv    =     lag(xrd + capx + aqc - sppe)

        # Add rolling stats:
        for c in 'sale_ave_at cfo_ave_at investment_at'.split():
            df[f'std_5yr_{c}'] = (df.groupby('gvkey')
                                    [c]
                                    .rolling(5)
                                    .std()
                                    .reset_index(drop=True))

        # Life Cycle as in Dickinson (2011):
        lc_lookup = {
            'nnp':(1, 'Introduction'),   # 1) -1, -1,  1: Introduction
            'pnp':(2, 'Growth'),         # 2)  1, -1,  1: Growth
            'pnn':(3, 'Mature'),         # 3)  1, -1, -1: Mature
            'nnn':(4, 'Out'),            # 4) -1, -1, -1: Out
            'ppp':(4, 'Out'),            # 4)  1,  1,  1: Out
            'ppn':(4, 'Out'),            # 4)  1,  1, -1: Out
            'npp':(5, 'Decline'),        # 5) -1,  1,  1: Decline
            'npn':(5, 'Decline'),        # 5) -1,  1, -1: Decline
        }
        cols = 'oancf ivncf fincf'.split()
        sel = pd.Series(['']*len(df))
        for c in cols:
            sel[df[c] <  0] += 'n'
            sel[df[c] >= 0] += 'p'
        df['life_cycle'] = sel.apply(lambda x: lc_lookup.get(x, [None, None])[0])
        df['life_cycle_legend'] = sel.apply(lambda x: lc_lookup.get(x, [None, None])[1])
        # Now manually set to None where missing one of the columns
        df.loc[df[cols].isnull().any(axis=1),
               'life_cycle life_cycle_legend'.split()] = None

        delete_cols = 'lag_epspx lag_xrd lag_xsga'.split()
        for c in df.columns:
            if c in delete_cols or c.endswith('_del_na'):
                del df[c]

        return df.replace([np.inf, -np.inf], np.nan)
