/*
 Download SAS data
*/

%SYSEXEC cd "$((ROOTDIR))";

LIBNAME external "data/external";


%INCLUDE "code/sas/MACROS.SAS";



%WRDS("open");
RSUBMIT;

/* Run this to upload the MACROS.sas file */
PROC UPLOAD
  INFILE='MACROS.SAS'
  OUTFILE='~/MACROS.sas' ;
RUN;

%sysexec mkdir ~/{{cookiecutter.project_acronym}};
LIBNAME out "~/{{cookiecutter.project_acronym}}/";

%INCLUDE '~/MACROS.sas';

PROC SQL;
DROP TABLE out.all_crsp_data;
QUIT;



/* Make date table from DSI to handle holidays */
DATA dates;
  DO date='01JAN1988'D TO '01JAN2050'D BY 1;
  OUTPUT;
  FORMAT date YYMMDD10.;
  END;
RUN;

PROC SQL;
  CREATE TABLE dsi_n AS
    SELECT *, MONOTONIC() AS date_n
    FROM crsp.dsi
    ORDER BY date;

  CREATE TABLE trade_date_w_weekends AS
    SELECT a.date, b.date_n, b.date AS dsidate
    FROM dates AS a
    LEFT JOIN dsi_n AS b
        ON a.date BETWEEN b.date - 10 AND b.date
    GROUP BY a.date
    HAVING a.date - b.date = MAX(a.date - b.date);
QUIT;

/* Now get the CRSP data */

PROC SQL;
    CREATE TABLE fundq_dates AS
      SELECT DISTINCT gvkey, fyearq AS fyear, fyr
        ,datadate FORMAT YYMMDD10.
        ,rdq FORMAT YYMMDD10.
        ,INPUT(SUBSTR(datacqtr, 1, 4), 4.)*4 + INPUT(SUBSTR(datacqtr, 6, 1), 1.) as datacqtrn
        ,prccq * cshoq AS mve
      FROM comp.fundq
      WHERE (INDFMT = 'INDL')
        AND (DATAFMT = 'STD')
        AND (POPSRC = 'D')
        AND (CONSOL = 'C')
        AND (fyearq >= 1989)
        AND (fqtr = 4)
        AND NOT MISSING(datadate)
        AND NOT MISSING(datacqtr)
      GROUP BY gvkey
      HAVING COUNT(*) >= 2
      ORDER BY gvkey, datadate;

  CREATE TABLE crsp1 AS
    SELECT DISTINCT a.gvkey, b.lpermno AS permno, a.datadate, a.rdq, a.datacqtrn
      ,COALESCE(k.datadate, INTNX('MONTH', a.datadate, -12, 'E')) AS prev_yr FORMAT YYMMDD10.
      ,k.rdq AS prev_yr_rdq FORMAT YYMMDD10.
    FROM fundq_dates AS a
    LEFT JOIN fundq_dates AS k
      ON a.gvkey = k.gvkey
      AND a.datacqtrn = k.datacqtrn + 4
    INNER JOIN (SELECT DISTINCT * FROM crsp.ccmxpf_linktable WHERE linktype IN ('LU', 'LC')) AS b
      ON a.gvkey = b.gvkey
      AND a.datadate BETWEEN b.linkdt AND COALESCE(b.linkenddt, '01JAN2021'd)
    ORDER BY a.gvkey, a.datadate;

  CREATE TABLE crsp2 AS
    SELECT a.gvkey, a.permno, a.datadate
      ,ret, vol, idx.vwretd
      ,COALESCE(1+ret, 1)*COALESCE(1+dlret, 1)-1 AS dlret
      ,2*(ask - bid) / abs(ask + bid) AS baspread
      ,IFN(vol > 0, 1000000 * abs(ret) / abs(vol * prc), .) AS amihud
      ,IFN(dsf_n.date_n BETWEEN rdq_n.date_n - 1 AND rdq_n.date_n + 1, 1, ., .) AS rdq_m1_to_p1
      ,IFN(c.date BETWEEN datadate AND INTNX('DAY', rdq, -1), 1, ., .) AS dd_to_rdq
      ,IFN(c.date BETWEEN INTNX('DAY', prev_yr, 1) AND datadate, 1, ., .) AS dd_to_prev_dd
      ,IFN(c.date BETWEEN INTNX('DAY', prev_yr_rdq, 1) AND INTNX('DAY', rdq, -1), 1, ., .) AS rdq_to_prev_rdq
    FROM crsp1 AS a
    LEFT JOIN trade_date_w_weekends AS rdq_n
      ON a.rdq = rdq_n.date
    LEFT JOIN crsp.dsf AS c
      ON a.permno = c.permno
      AND c.date BETWEEN a.prev_yr AND INTNX('DAY', a.rdq, 10)
    LEFT JOIN trade_date_w_weekends AS dsf_n
      ON c.date = dsf_n.date
    LEFT JOIN dsi_n AS idx
      ON c.date = idx.date
    LEFT JOIN (SELECT permno, date, dlret FROM crsp.dse WHERE NOT missing(dlret)) AS dl
      ON c.permno = dl.permno
      AND c.date = dl.date
    ORDER BY gvkey, permno, datadate;

  CREATE TABLE crsp3 AS
    SELECT DISTINCT gvkey, permno, datadate
    /******************** RDQ 3 day window -1 to +1 **************************************/
      /* Returns */
      ,EXP(SUM(LOG(1+ret) * rdq_m1_to_p1))-1 AS cum_ret_rdq
      ,MEAN((ret) * rdq_m1_to_p1) AS ave_ret_rdq
      ,STD((ret) * rdq_m1_to_p1) AS std_ret_rdq
      ,COUNT((ret) * rdq_m1_to_p1) AS num_ret_rdq
      /* Returns - delisting returns */
      ,EXP(SUM(LOG(1+dlret) * rdq_m1_to_p1))-1 AS cum_dlret_rdq
      ,MEAN((dlret) * rdq_m1_to_p1) AS ave_dlret_rdq
      /* Market Returns */
      ,EXP(SUM(LOG(1+vwretd*SIGN(ret+2)) * rdq_m1_to_p1))-1 AS vwret_rdq
      ,MEAN((vwretd) * rdq_m1_to_p1) AS ave_vwret_rdq
      ,STD((ret-vwretd) * rdq_m1_to_p1) AS std_ret_minus_mkt_rdq
      /* Liquidity */
      ,MEAN((baspread) * rdq_m1_to_p1) AS baspread_rdq
      ,MEAN((amihud) * rdq_m1_to_p1) AS amihud_rdq
      ,SUM((vol) * rdq_m1_to_p1) AS tot_vol_rdq

    /******************** QTR end (datadate) to RDQ **************************************/
      /* Returns */
      ,EXP(SUM(LOG(1+ret) * dd_to_rdq))-1 AS cum_ret_dd_to_rdq
      ,MEAN((ret) * dd_to_rdq) AS ave_ret_dd_to_rdq
      ,STD((ret) * dd_to_rdq) AS std_ret_dd_to_rdq
      ,COUNT((ret) * dd_to_rdq) AS num_ret_dd_to_rdq
      /* Returns - delisting returns */
      ,EXP(SUM(LOG(1+dlret) * dd_to_rdq))-1 AS cum_dlret_dd_to_rdq
      ,MEAN((dlret) * dd_to_rdq) AS ave_dlret_dd_to_rdq
      /* Market Returns */
      ,EXP(SUM(LOG(1+vwretd*SIGN(ret+2)) * dd_to_rdq))-1 AS vwret_dd_to_rdq
      ,MEAN((vwretd) * dd_to_rdq) AS ave_vwret_dd_to_rdq
      ,STD((ret-vwretd) * dd_to_rdq) AS std_ret_minus_mkt_dd_to_rdq
      /* Liquidity */
      ,MEAN((baspread) * dd_to_rdq) AS baspread_dd_to_rdq
      ,MEAN((amihud) * dd_to_rdq) AS amihud_dd_to_rdq
      ,SUM((vol) * dd_to_rdq) AS tot_vol_dd_to_rdq

    /******************** Previous Year (datadate to datadate) ***************************/
      /* Returns */
      ,EXP(SUM(LOG(1+ret) * dd_to_prev_dd))-1 AS cum_ret
      ,MEAN((ret) * dd_to_prev_dd) AS ave_ret
      ,STD((ret) * dd_to_prev_dd) AS std_ret
      ,COUNT((ret) * dd_to_prev_dd) AS num_ret
      /* Returns - delisting returns */
      ,EXP(SUM(LOG(1+dlret) * dd_to_prev_dd))-1 AS cum_dlret
      ,MEAN((dlret) * dd_to_prev_dd) AS ave_dlret
      /* Market Returns */
      ,EXP(SUM(LOG(1+vwretd*SIGN(ret+2)) * dd_to_prev_dd))-1 AS vwret
      ,MEAN((vwretd) * dd_to_prev_dd) AS ave_vwret
      ,STD((ret-vwretd) * dd_to_prev_dd) AS std_ret_minus_mkt
      /* Liquidity */
      ,MEAN((baspread) * dd_to_prev_dd) AS baspread
      ,MEAN((amihud) * dd_to_prev_dd) AS amihud
      ,SUM((vol) * dd_to_prev_dd) AS tot_vol

    /******************** Previous RDQ Year (RDQ to RDQ) *********************************/
      /* Returns */
      ,EXP(SUM(LOG(1+ret) * rdq_to_prev_rdq))-1 AS cum_ret_rdq
      ,MEAN((ret) * rdq_to_prev_rdq) AS ave_ret_rdq
      ,STD((ret) * rdq_to_prev_rdq) AS std_ret_rdq
      ,COUNT((ret) * rdq_to_prev_rdq) AS num_ret_rdq
      /* Returns - delisting returns */
      ,EXP(SUM(LOG(1+dlret) * rdq_to_prev_rdq))-1 AS cum_dlret_rdq
      ,MEAN((dlret) * rdq_to_prev_rdq) AS ave_dlret_rdq
      /* Market Returns */
      ,EXP(SUM(LOG(1+vwretd*SIGN(ret+2)) * rdq_to_prev_rdq))-1 AS vwret_rdq
      ,MEAN((vwretd) * rdq_to_prev_rdq) AS ave_vwret_rdq
      ,STD((ret-vwretd) * rdq_to_prev_rdq) AS std_ret_minus_mkt_rdq
      /* Liquidity */
      ,MEAN((baspread) * rdq_to_prev_rdq) AS baspread_rdq
      ,MEAN((amihud) * rdq_to_prev_rdq) AS amihud_rdq
      ,SUM((vol) * rdq_to_prev_rdq) AS tot_vol_rdq
    FROM crsp2
    GROUP BY gvkey, permno, datadate
    ORDER BY gvkey, permno, datadate;
QUIT;

PROC MEANS SKEWNESS NOPRINT DATA=crsp2(WHERE=(NOT MISSING(dd_to_prev_dd)));
  OUTPUT OUT=crsp4 SKEW=;
  BY gvkey permno datadate;
RUN;

PROC SQL;
  CREATE TABLE out.all_crsp_data AS
    SELECT DISTINCT a.*, rets.*, m.hexcd AS exchange_crsp, cs.*
      ,k.ret AS skew_ret
      ,k.vol AS skew_vol
      ,k.dlret AS skew_klret
      ,k.baspread AS skew_baspread
      ,k.amihud AS skew_akihud
      ,ABS(m.prc) AS price_dd
      ,m.shrout AS shrout_dd
      ,ABS(mk.prc) AS price_lag_dd
      ,mk.shrout AS shrout_lag_dd
      ,NOT MISSING(dlnext.dlstdt) AS delist_next_yr
      ,dlnext.dlstdt AS delist_date
      ,dlnext.dlstcd AS delist_code FORMAT YYMMDD10.
    FROM crsp1 AS a
    LEFT JOIN crsp3 AS rets
      ON a.gvkey = rets.gvkey
      AND a.permno = rets.permno
      AND a.datadate = rets.datadate
    LEFT JOIN crsp4 AS k
      ON a.gvkey = k.gvkey
      AND a.permno = k.permno
      AND a.datadate = k.datadate
    /*LEFT JOIN (SELECT DISTINCT * FROM crsp.msedelist GROUP BY permno HAVING date = MIN(DATE)) AS dlnext*/
    LEFT JOIN crsp.msedelist AS dlnext
      ON a.permno = dlnext.permno
      AND dlnext.dlstdt BETWEEN a.datadate AND INTNX('DAY', a.datadate, 364)
    LEFT JOIN crsp.msf AS m
      ON a.permno = m.permno
      AND YEAR(a.datadate) = YEAR(m.date)
      AND MONTH(a.datadate) = MONTH(m.date)
    LEFT JOIN crsp.msf AS mk
      ON a.permno = mk.permno
      AND YEAR(a.prev_yr) = YEAR(mk.date)
      AND MONTH(a.prev_yr) = MONTH(mk.date)
    LEFT JOIN (SELECT DISTINCT permno, ABS(prc) AS crsp_start_price,
                  date AS crsp_start_date FORMAT YYMMDD10., shrout AS crsp_start_shrout
                FROM crsp.dsf
                GROUP BY permno
                HAVING date = MIN(date)) AS cs
      ON a.permno = cs.permno
    ORDER BY a.gvkey, a.permno, a.datadate;
QUIT;

/*
Delisting Code	Category
100	Active
200	Mergers
300	Exchanges
400	Liquidations
500	Dropped
600	Expirations
900	Domestics that became Foreign

*/


PROC DOWNLOAD
  DATA=out.all_crsp_data
  OUT=all_crsp_data;
RUN;

ENDRSUBMIT;
%WRDS("close");


%EXPORT_STATA(db_in=all_crsp_data, filename="data/external/all_crsp_data.dta");

/* fin */
