*INCLUDE "$((ROOTDIR))/code/sas/MACROS.SAS";
%MACRO example_wrds_pull();
%WRDS("open");
RSUBMIT;
    PROC SQL;
        CREATE TABLE funda AS
        SELECT f.gvkey, f.datadate AS date, f.fyear AS YEAR
            ,nam.sic
            ,dvp AS DIVIDENDS /* 19: Dividends (Preferred/Preference) */
            ,dvc AS DIVIDENDS /* 21: Dividends (Common/Ordinary) */
            ,dlc AS DEBT_ST /* 34: Short Term Debt */
            ,dltt AS DEBT_LT /* 9: Long Term Debt */
            ,at  /* 6: Book Assets (Total Assets) */
            ,lt  /* 181: Book Liabilities (Total Liabilities) */
            ,oibdp /* 13: Operating Income Before Depreciation */
            ,prcc_f AS PRCC /* 199: Stock Price Fiscal YE */
            ,cshpri AS SHARES /* 54: Shares Outstanding */
            ,pstkl /* 10: Preferred Stock Liquidating Value */
            ,txditc /* 35: Deferred Taxes and Invst. Tax Credits */
            ,invt /* 3: Inventory */
            ,ppent /* 8: PPE Net */
            ,pi /* 170: Pre Tax Income */
            ,sale /* 12: Sales */
            ,re /* 36: Retained earnings */
            ,act /* 4: Current Assets - Total */
            ,lct /* 5: Current Liabilities - Total */
            ,csho /* 25: Common shares outstanding */
            ,xrd  /* 46: Research and Development Expense */
            ,ajex /* 27: Adjustment Factor - Cumulative by Ex-Date */
        FROM comp.funda AS f
        LEFT JOIN comp.NAMES as nam
            ON f.gvkey = nam.gvkey
        WHERE %COMPWHERE(f)
        AND DATADATE >= '01JAN1960'd
        AND DATADATE <= '01JAN2012'd
        /*AND nam.sic NOT LIKE "6%"*/;

    CREATE TABLE crsp AS
        SELECT DISTINCT t1.gvkey, dsf.permno, dsf.date
            ,ABS(dsf.prc) AS price, dsf.ret, dsf.retx
        FROM (SELECT DISTINCT gvkey FROM funda) AS t1
        LEFT JOIN crsp.CCMXPF_LINKTABLE AS lnk
            ON lnk.gvkey = t1.gvkey
        LEFT JOIN crsp.dsf AS dsf
            ON dsf.permno = lnk.lpermno;
    QUIT;
    PROC DOWNLOAD
        DATA= funda
        OUT= c.funda;
    RUN;
    PROC DOWNLOAD
        DATA= crsp
        OUT= c.crsp;
    RUN;
ENDRSUBMIT;
%WRDS("close");
%MEND example_wrds_pull;



%PUT %NRSTR(%%)WRDS("open/close");
%MACRO WRDS(action);

  *This bit sets up the password file.;
  %LET remotepwf = %STR(%SYSFUNC(GETOPTION(autoexec)));
  %LET remotepwf = %SUBSTR(&remotepwf, 1, %EVAL(%LENGTH(&remotepwf)-12))wrds_password.sas;
  filename remotepw "&remotepwf";

  /* *Run this comment once to save your password into an encoded file;
    * %WINDOW defines the prompt *;
    %window info
      #3 @5 'Please enter password:'
      #3 @28 pass 32 attr=underline display=no;
    * %DISPLAY invokes the prompt *;
    %display info;

    proc pwencode in="&password" out=remotepw;
    run;
  */

  %IF &action = "open" %THEN %DO;
    %IF %SYSFUNC(FEXIST(remotepw)) %THEN %DO;
      options symbolgen;
      data _null_;
         infile remotepw obs=1 length=l;
         input @;
         input @1 line $varying1024. l;
         call symput('dbpass',substr(line,1,l));
      run;
      options nosymbolgen;
    %END;%ELSE %LET dbpass=_PROMPT_;

    %LET WRDS=wrds-cloud.wharton.upenn.edu 4016;
      /*%LET &dbpass=%STR({sasenc}HARDCODEPASSWORDHEREIFITSUITSYOU);*/
      OPTIONS comamid=TCP remote=WRDS;
      SIGNON USERNAME="gaulinmp" PASSWORD="&dbpass";
  %END;
  %ELSE SIGNOFF;
%MEND WRDS;


%PUT %NRSTR(%%)COMPWHERE(libname);
%MACRO COMPWHERE(libname);
  /* EXAMPLE:
  PROC SQL;
    CREATE TABLE tmp AS
    SELECT gvkey, datadate
    FROM comp.funda
    WHERE %COMPWHERE()
      AND gvkey EQ '001004'
    ORDER BY gvkey;
  QUIT;
   */
  %IF "&libname." ne "" %THEN %LET libname=&libname..;
  %IF "" EQ "" %THEN %DO;
      &libname.INDFMT = 'INDL'
  AND &libname.DATAFMT = 'STD'
  AND &libname.POPSRC = 'D'
  AND &libname.CONSOL = 'C'
  %END;
%MEND COMPWHERE;


%PUT %NRSTR(%%)CONCATABLES(train, caboose);
%MACRO CONCATABLES(train, caboose);
    %IF NOT %SYSFUNC(EXIST(&train)) %THEN %DO;
        DATA &train;
            SET &caboose;
            RUN;
    %END;
    %ELSE %DO;
        DATA &train;
            SET &train &caboose;
            RUN;
    %END;
%MEND CONCATABLES;



%PUT %NRSTR(%%)DROPTABLES(table_list) %NRSTR(*Separated by commas;);
%MACRO DROPTABLES/PARMBUFF;
/* Here syspbuff contains the comma separated list within parens, so just strip the parens */
%LET local_var_list = %SUBSTR (&syspbuff, 2, %EVAL(%LENGTH(&syspbuff)-2));
%PUT Syspbuff contains: &local_var_list;
PROC SQL;
    DROP TABLE &local_var_list;
QUIT;
%MEND DROPTABLES;





%PUT %NRSTR(%%)PRINT_COLUMNS(table);
%MACRO PRINT_COLUMNS(tabnam);
   PROC CONTENTS DATA=&tabnam OUT=tmp_meta_delete_this (KEEP=name);RUN;
   PROC PRINT DATA=tmp_meta_delete_this;RUN;
%MEND PRINT_COLUMNS;





%PUT %NRSTR(%%)IS_UNIQUE(db_in, %NRSTR(%%)(val1,val2,...));
%MACRO IS_UNIQUE(db_in, table_list);
PROC SQL;
    CREATE TABLE check_unique_tmp_table AS
    SELECT *
    FROM &db_in
    GROUP BY &table_list
    HAVING COUNT(*) > 1;
QUIT;
%MEND IS_UNIQUE;





%PUT %NRSTR(%%)DUP(var1, var2, ... , db_in=%NRSTR(&)syslast);
%MACRO DUP/parmbuff;
  %LET _opnote = %SYSFUNC(GETOPTION(notes));
  OPTION NONOTES;

  %LET _dbin = &syslast.;
  %LET _go_til = %EVAL(%LENGTH(%NRBQUOTE(&syspbuff))-2);

  %LET _re=%SYSFUNC(PRXPARSE(',\s*db_in\s*=\s*([^) ]*)'));
  %LET _db_loc = %SYSFUNC(PRXMATCH(&_re, &syspbuff));

  %IF (&_db_loc > 0) %THEN %DO;
    %LET _go_til = %EVAL(&_db_loc - 2);
    %LET _dbin = %SYSFUNC(PRXPOSN(&_re, 1, %NRBQUOTE(&syspbuff)));
  %END;

  %SYSCALL PRXFREE(_re);

  %LET _vars = %SYSFUNC(SUBSTR(&syspbuff, 2, &_go_til));

  PROC SQL NOPRINT;
    CREATE TABLE _dup_table AS
      SELECT COUNT(*) AS num_duplicates, &_vars
      FROM &_dbin
      GROUP BY &_vars
      HAVING COUNT(*) > 1
      ORDER BY &_vars;

    SELECT DISTINCT COUNT(*) INTO :_num_dups
      FROM _dup_table;
  QUIT;
  PROC SQL;

  OPTION &_opnote;
  %PUT NOTE:;%PUT NOTE: Table &_dbin has %SYSFUNC(STRIP(&_num_dups)) duplicates by key: &_vars;%PUT NOTE:;
%MEND;



%PUT %NRSTR(%%)EXPORT(dbms=TAB,db_in=syslast,filename=);
%MACRO EXPORT(dbms=TAB,db_in=&syslast.,filename=);
  PROC EXPORT DATA=&db_in
              OUTFILE= &filename
              DBMS=&dbms REPLACE;
  RUN;
%MEND EXPORT;



%PUT %NRSTR(%%)EXPORT_STATA(db_in=,filename=);
%MACRO EXPORT_STATA(db_in=,filename=);
  %EXPORT(dbms="STATA",db_in=&db_in,filename=&filename);
%MEND EXPORT_STATA;





%PUT %NRSTR(%%)HEAD(db_in=syslast, n=2);
%MACRO HEAD(db_in=&syslast, n=2);
  TITLE "&db_in";
  PROC PRINT DATA=&db_in(obs=&n);
  RUN;
  TITLE;
%MEND HEAD;






%PUT %NRSTR(%%)STATS(db_in=tmp,db_out=summary_stats,vars=ret, by=none);
%MACRO STATS(db_in=tmp,db_out=summary_stats,vars=ret, by=none);
  %local count;
  %LOCAL db_delim;
  %let count=0;
  %LET db_delim=xzxz;
  DATA &db_delim.fromfile;SET &db_in;RUN;
  %DO %WHILE(%QSCAN(&vars,&count+1,%STR( )) ne %STR());
      %let var = %QSCAN(&vars,&count+1,%STR( ));
      %PUT Starting to calculate stats for &var....;
      %IF &by ne none %THEN %DO;
        PROC SORT DATA=&db_delim.fromfile;
            BY &by;
            RUN;
      %END;
      PROC UNIVARIATE DATA=&db_delim.fromfile NOPRINT;
          VAR &var;
          OUTPUT OUT=&db_delim.univ MEAN=mean STD=standard_dev
              T=tstat PROBT=pstat MIN=min P1=pct1 Q1=pct25
              MEDIAN=median Q3=pct75 P99=pct99 MAX=max N=nobs;
          %IF &by ne none %THEN %DO;
          BY &by;
          %END;
      RUN;
      %PUT Creating &db_delim.var to add varname in the right order.;
      DATA &db_delim.var;
          LENGTH varname $ 12;
          VARNAME = "&var";
          SET &db_delim.univ;
        RUN;
      %IF NOT %SYSFUNC(EXIST(&db_out)) %THEN %DO;
          %PUT Did not find &db_out so creating it now...;
          DATA &db_out;
              SET &db_delim.var;
              RUN;
      %END;%ELSE %DO;
          %PUT Found &db_out so merging &db_delim.var with it;
          DATA &db_out;
              MERGE &db_out &db_delim.var;
              BY varname;
              RUN;
      %END;
      %PUT Done with &var, deleting &db_delim.var and &db_delim.univ;
      PROC SQL;
          DROP TABLE &db_delim.univ, &db_delim.var;
      QUIT;
      %LET count = %EVAL(&count+1);
  %END;
  PROC SQL;
    DROP TABLE &db_delim.fromfile;
  QUIT;
%MEND STATS;






%PUT %NRSTR(%%)REMOVE_LABELS(library.database);
%MACRO REMOVE_LABELS(string);

  %LET src = %SYSFUNC(GETOPTION(source));
  %LET nt = %SYSFUNC(GETOPTION(notes));
  OPTIONS nonotes nosource;


  %IF %SCAN(&string,2,%str(.)) = %THEN %DO;
    %LET lib_str = user;
    %LET db_str = %scan(&string,1,%str(.));
    %PUT No library entered, defaulting to &lib_str;
  %END;
  %ELSE %DO;
    %LET lib_str = %scan(&string,1,%str(.));
    %LET db_str = %scan(&string,2,%str(.));
  %END;

  %IF %SYSFUNC(EXIST(&lib_str..&db_str)) %THEN %DO;
    PROC DATASETS LIB=&lib_str MEMTYPE=data NODETAILS NOLIST;
      MODIFY &db_str;
      ATTRIB _ALL_ LABEL='';
    RUN;QUIT;
    %PUT Modified &lib_str..&db_str;
  %END;
  %ELSE %DO;
      %PUT Library or database do not exist.;
  %END;

  OPTIONS &src &nt;

%MEND REMOVE_LABELS;





/*******************************************************************
*
* Trim or winsorize macro from wrds.us, somewhat modified.
* Note: If the percentile restriction cutoff is the two extreme
*       observations then this winsorization technique sets
*       the two extremes equal to the second and N-1 values.
*       In other words, the winsorization changes AT LEAST two
*       variables, even for small datasets. Samples of <5 have not
*       been tested. Use at your own risk. As always, look at your data.
*
* db_in = dataset to winsorize/trim
* db_out = dataset to output with winsorized/trimmed values
* vars = list of variables to winsorize (in place, no commas)
* type  = delete/winsor (delete will trim, winsor will winsorize
* byvar = subsetting variables to winsorize/trim on
* pctl_low/high = percentile (in percent) to winsorize to
* debug = set to true (no quotes) to keep intermediate files and vars
*
********************************************************************/
%PUT %NRSTR(%%)winsor(db_in=,db_out=,vars=, byvar=none, type=winsor, pctl_low=1, pctl_high=99, debug=false);
%MACRO winsor(db_in=,db_out=,vars=, byvar=none, type=winsor, pctl_low=1, pctl_high=99, debug=false);

    %if &db_out = %then %let db_out = &db_in;

    %let varL=;
    %let varH=;
    %let xn=1;

    %do %until ( %scan(&vars,&xn)= );
        %let token = %scan(&vars,&xn);
        %let varL = &varL &token.L;
        %let varH = &varH &token.H;
        %let xn=%EVAL(&xn + 1);
    %end;

    %let xn=%eval(&xn-1);
    /* If there is no BY variable, then make it 1. */
    %IF &byvar = none %THEN %DO;
      %LET byvar = 1;
    %END;

    data xtemp;
        set &db_in;
        tmp_byvar = &byvar;
      RUN;

    PROC SQL;
        CREATE TABLE xtemp_pctl AS
        SELECT DISTINCT tmp_byvar
        FROM xtemp
        ORDER BY tmp_byvar;
    QUIT;

    PROC SORT DATA=xtemp;
        BY tmp_byvar;
        RUN;

    %local count;
    %let count=0;
    %DO %WHILE(%QSCAN(&vars,&count+1,%STR( )) ne %STR());

        %LET vari = %QSCAN(&vars,&count+1,%STR( ));
        %LET variL = %SYSFUNC(catx(,&vari,L));
        %LET variH = %SYSFUNC(catx(,&vari,H));

        %PUT &variL &variH;

        PROC SORT DATA=xtemp;
            BY tmp_byvar &vari;
            RUN;QUIT;

        PROC SQL;
            CREATE TABLE xtemp2 AS
            SELECT *
                ,COUNT(*) AS x_num_x
                ,CEIL(COUNT(*) * &pctl_low / 100) AS x_num_low_x
                ,FLOOR(COUNT(*) * &pctl_high / 100) AS x_num_high_x
            FROM (SELECT * FROM xtemp WHERE &vari NE .)
            GROUP BY tmp_byvar
            ORDER BY tmp_byvar, &vari;
        QUIT;

        DATA xtemp3;
            SET xtemp2;
            BY tmp_byvar;
            RETAIN x_groupstart_x;
            IF FIRST.tmp_byvar THEN x_groupstart_x = _N_ - 1;
            x_byvarrank_x = _N_ - x_groupstart_x;
            *DROP x_groupstart_x;
        RUN;

        PROC SQL;
            CREATE TABLE xtemp4 AS
            SELECT DISTINCT tmp_byvar, &vari
                ,x_groupstart_x, x_num_x, x_byvarrank_x, x_num_low_x, x_num_high_x
            FROM xtemp3
            WHERE x_num_low_x + 1 = x_byvarrank_x;

            CREATE TABLE xtemp5 AS
            SELECT DISTINCT tmp_byvar, &vari
                ,x_groupstart_x, x_num_x, x_byvarrank_x, x_num_low_x, x_num_high_x
            FROM xtemp3
            WHERE x_num_high_x = x_byvarrank_x;

            CREATE TABLE xtemp_pctl2 AS
            SELECT DISTINCT a.*
                ,b.&vari AS &variL
                ,c.&vari AS &variH
            FROM xtemp_pctl AS a
            LEFT JOIN xtemp4 AS b
                ON a.tmp_byvar = b.tmp_byvar
            LEFT JOIN xtemp5 AS c
                ON a.tmp_byvar = c.tmp_byvar;
        QUIT;

        DATA xtemp_pctl;
            SET xtemp_pctl2;
            RUN;

        %LET count = %EVAL(&count+1);
    %END;

    PROC SORT DATA=xtemp;
        BY tmp_byvar;
        RUN;

    data &db_out;
        merge xtemp xtemp_pctl;
        by tmp_byvar;
        array trimvars{&xn} &vars;
        array trimvarl{&xn} &varL;
        array trimvarh{&xn} &varH;

        do xi = 1 to dim(trimvars);

            %if &type = winsor %then %do;
                if not missing(trimvars{xi}) then do;
                  if (trimvars{xi} < trimvarl{xi}) then trimvars{xi} = trimvarl{xi};
                  if (trimvars{xi} > trimvarh{xi}) then trimvars{xi} = trimvarh{xi};
                end;
            %end;

            %else %do;
                if not missing(trimvars{xi}) then do;
                  if (trimvars{xi} < trimvarl{xi}) then delete;
                  if (trimvars{xi} > trimvarh{xi}) then delete;
                end;
            %end;

        end;
        %IF &debug NE true %THEN %DO;
        DROP &varL &varH xi tmp_byvar;
        %END;
    run;

    %IF &debug NE true %THEN %DO;
      %PUT Dropping temp files.;
      PROC SQL;
        DROP TABLE xtemp, xtemp2, xtemp3, xtemp4, xtemp5, xtemp_pctl, xtemp_pctl2;
      QUIT;
    %END;
    %PUT "End winsor function: &vars.";
%MEND winsor;





%PUT %NRSTR(%%)YFE(var, from, to);
%MACRO YFE(var, from, to);
    %DO i=&from %TO &to;
    ,CASE
        WHEN &var = &i THEN 1
        ELSE 0
    END AS yr&i
    %END;
%MEND YFE;







/*****************************************************************************
* Generates Fama-French industry codes based on four-digit SIC codes.
* Outputs the original dataset with appended industry code information:
*
*   db_in              input dataset name
*   sic                four-digit sic code variable name
*   db_out             output dataset
*   dummy_prefix       prefix for industry binary variables (default: ffind)
*   ind_var            name of industry codes (1-48) variable (default: ffindn)
******************************************************************************/

%let _industry_fe=  i1 i2 i3 i4 i5 i6 i7 i8 i9
                    i10 i11 i12 i13 i14 i15 i16 i17 i18 i19
                    i20 i21 i22 i23 i24 i25 i26 i27 i28 i29
                    i30 i31 i32 i33 i34 i35 i36 i37 i38 i39
                    i40 i41 i42 i43 i44 i45 i46 i47 i48;

%PUT %NRSTR(%%)ind_ff48 (db_in, db_out, sic, dummy_prefix=ffind, ind_var=ffindn );
%macro ind_ff48 (db_in, db_out, sic, dummy_prefix=ffind, ind_var=ffindn );

data &db_out;
set &db_in;
    indus2=int(&sic/100);
    indus3=int(&sic/10);

* 1 Agric  Agriculture;
    if &sic ge 0100 and &sic le 0199  then FF_IND='AGRIC';
    if &sic ge 0200 and &sic le 0299  then FF_IND='AGRIC';
    if &sic ge 0700 and &sic le 0799  then FF_IND='AGRIC';
    if &sic ge 0910 and &sic le 0919  then FF_IND='AGRIC';
    if &sic ge 2048 and &sic le 2048  then FF_IND='AGRIC';
    if FF_IND='AGRIC' then &ind_var=1;

* 2 Food   Food Products;
    if &sic ge 2000 and &sic le 2009  then FF_IND='FOOD';
    if &sic ge 2010 and &sic le 2019  then FF_IND='FOOD';
    if &sic ge 2020 and &sic le 2029  then FF_IND='FOOD';
    if &sic ge 2030 and &sic le 2039  then FF_IND='FOOD';
    if &sic ge 2040 and &sic le 2046  then FF_IND='FOOD';
    if &sic ge 2050 and &sic le 2059  then FF_IND='FOOD';
    if &sic ge 2060 and &sic le 2063  then FF_IND='FOOD';
    if &sic ge 2070 and &sic le 2079  then FF_IND='FOOD';
    if &sic ge 2090 and &sic le 2092  then FF_IND='FOOD';
    if &sic ge 2095 and &sic le 2095  then FF_IND='FOOD';
    if &sic ge 2098 and &sic le 2099  then FF_IND='FOOD';
    if FF_IND='FOOD' then &ind_var=2;

* 3 Soda   Candy & Soda;
    if &sic ge 2064 and &sic le 2068  then FF_IND='SODA';
    if &sic ge 2086 and &sic le 2086  then FF_IND='SODA';
    if &sic ge 2087 and &sic le 2087  then FF_IND='SODA';
    if &sic ge 2096 and &sic le 2096  then FF_IND='SODA';
    if &sic ge 2097 and &sic le 2097  then FF_IND='SODA';
    if FF_IND='SODA' then &ind_var=3;

* 4 Beer   Beer & Liquor;
    if &sic ge 2080 and &sic le 2080  then FF_IND='BEER';
    if &sic ge 2082 and &sic le 2082  then FF_IND='BEER';
    if &sic ge 2083 and &sic le 2083  then FF_IND='BEER';
    if &sic ge 2084 and &sic le 2084  then FF_IND='BEER';
    if &sic ge 2085 and &sic le 2085  then FF_IND='BEER';
    if FF_IND='BEER' then &ind_var=4;

* 5 Smoke  Tobacco Products;
    if &sic ge 2100 and &sic le 2199  then FF_IND='SMOKE';
    if FF_IND='SMOKE' then &ind_var=5;

* 6 Toys   Recreation;
    if &sic ge 0920 and &sic le 0999  then FF_IND='TOYS';
    if &sic ge 3650 and &sic le 3651  then FF_IND='TOYS';
    if &sic ge 3652 and &sic le 3652  then FF_IND='TOYS';
    if &sic ge 3732 and &sic le 3732   then FF_IND='TOYS';
    if &sic ge 3930 and &sic le 3931   then FF_IND='TOYS';
    if &sic ge 3940 and &sic le 3949   then FF_IND='TOYS';
    if FF_IND='TOYS' then &ind_var=6;

* 7 Fun    Entertainment;
    if &sic ge 7800 and &sic le 7829   then FF_IND='FUN';
    if &sic ge  7830 and &sic le 7833   then FF_IND='FUN';
    if &sic ge 7840 and &sic le 7841   then FF_IND='FUN';
    if &sic ge 7900 and &sic le 7900   then FF_IND='FUN';
    if &sic ge 7910 and &sic le 7911   then FF_IND='FUN';
    if &sic ge 7920 and &sic le 7929   then FF_IND='FUN';
    if &sic ge 7930 and &sic le 7933   then FF_IND='FUN';
    if &sic ge 7940 and &sic le 7949   then FF_IND='FUN';
    if &sic ge 7980 and &sic le 7980   then FF_IND='FUN';
    if &sic ge 7990 and &sic le 7999   then FF_IND='FUN';
    if FF_IND='FUN' then &ind_var=7;

* 8 Books  Printing and Publishing;
    if &sic ge 2700 and &sic le 2709   then FF_IND='BOOKS';
    if &sic ge 2710 and &sic le 2719   then FF_IND='BOOKS';
    if &sic ge 2720 and &sic le 2729   then FF_IND='BOOKS';
    if &sic ge 2730 and &sic le 2739   then FF_IND='BOOKS';
    if &sic ge 2740 and &sic le 2749   then FF_IND='BOOKS';
    if &sic ge 2770 and &sic le 2771   then FF_IND='BOOKS';
    if &sic ge 2780 and &sic le 2789   then FF_IND='BOOKS';
    if &sic ge 2790 and &sic le 2799   then FF_IND='BOOKS';
    if FF_IND='BOOKS' then &ind_var=8;

* 9 Hshld  Consumer Goods;
    if &sic ge 2047 and &sic le 2047   then FF_IND='HSHLD';
    if &sic ge 2391 and &sic le 2392   then FF_IND='HSHLD';
    if &sic ge 2510 and &sic le 2519   then FF_IND='HSHLD';
    if &sic ge 2590 and &sic le 2599   then FF_IND='HSHLD';
    if &sic ge 2840 and &sic le 2843   then FF_IND='HSHLD';
    if &sic ge 2844 and &sic le 2844   then FF_IND='HSHLD';
    if &sic ge 3160 and &sic le 3161   then FF_IND='HSHLD';
    if &sic ge 3170 and &sic le 3171   then FF_IND='HSHLD';
    if &sic ge 3172 and &sic le 3172   then FF_IND='HSHLD';
    if &sic ge 3190 and &sic le 3199   then FF_IND='HSHLD';
    if &sic ge 3229 and &sic le 3229   then FF_IND='HSHLD';
    if &sic ge 3260 and &sic le 3260   then FF_IND='HSHLD';
    if &sic ge 3262 and &sic le 3263   then FF_IND='HSHLD';
    if &sic ge 3269 and &sic le 3269   then FF_IND='HSHLD';
    if &sic ge 3230 and &sic le 3231   then FF_IND='HSHLD';
    if &sic ge 3630 and &sic le 3639   then FF_IND='HSHLD';
    if &sic ge 3750 and &sic le 3751   then FF_IND='HSHLD';
    if &sic ge 3800 and &sic le 3800   then FF_IND='HSHLD';
    if &sic ge 3860 and &sic le 3861   then FF_IND='HSHLD';
    if &sic ge 3870 and &sic le 3873   then FF_IND='HSHLD';
    if &sic ge 3910 and &sic le 3911   then FF_IND='HSHLD';
    if &sic ge 3914 and &sic le 3914   then FF_IND='HSHLD';
    if &sic ge 3915 and &sic le 3915   then FF_IND='HSHLD';
    if &sic ge 3960 and &sic le 3962   then FF_IND='HSHLD';
    if &sic ge 3991 and &sic le 3991   then FF_IND='HSHLD';
    if &sic ge 3995 and &sic le 3995   then FF_IND='HSHLD';
    if FF_IND='HSHLD' then &ind_var=9;

*10 Clths  Apparel;
    if &sic ge 2300 and &sic le 2390   then FF_IND='CLTHS';
    if &sic ge 3020 and &sic le 3021   then FF_IND='CLTHS';
    if &sic ge 3100 and &sic le 3111   then FF_IND='CLTHS';
    if &sic ge 3130 and &sic le 3131   then FF_IND='CLTHS';
    if &sic ge 3140 and &sic le 3149   then FF_IND='CLTHS';
    if &sic ge 3150 and &sic le 3151   then FF_IND='CLTHS';
    if &sic ge 3963 and &sic le 3965   then FF_IND='CLTHS';
    if FF_IND='CLTHS' then &ind_var=10;

*11 Hlth   Healthcare;
    if &sic ge 8000 and &sic le 8099   then FF_IND='HLTH';
    if FF_IND='HLTH' then &ind_var=11;

*12 MedEq  Medical Equipment;
    if &sic ge 3693 and &sic le 3693   then FF_IND='MEDEQ';
    if &sic ge 3840 and &sic le 3849   then FF_IND='MEDEQ';
    if &sic ge 3850 and &sic le 3851   then FF_IND='MEDEQ';
    if FF_IND='MEDEQ' then &ind_var=12;

*13 Drugs  Pharmaceutical Products;
    if &sic ge 2830 and &sic le 2830   then FF_IND='DRUGS';
    if &sic ge 2831 and &sic le 2831   then FF_IND='DRUGS';
    if &sic ge 2833 and &sic le 2833   then FF_IND='DRUGS';
    if &sic ge 2834 and &sic le 2834   then FF_IND='DRUGS';
    if &sic ge 2835 and &sic le 2835   then FF_IND='DRUGS';
    if &sic ge 2836 and &sic le 2836   then FF_IND='DRUGS';
    if FF_IND='DRUGS' then &ind_var=13;

*14 Chems  Chemicals;
    if &sic ge 2800 and &sic le 2809   then FF_IND='CHEM';
    if &sic ge 2810 and &sic le 2819   then FF_IND='CHEM';
    if &sic ge 2820 and &sic le 2829   then FF_IND='CHEM';
    if &sic ge 2850 and &sic le 2859   then FF_IND='CHEM';
    if &sic ge 2860 and &sic le 2869   then FF_IND='CHEM';
    if &sic ge 2870 and &sic le 2879   then FF_IND='CHEM';
    if &sic ge 2890 and &sic le 2899   then FF_IND='CHEM';
    if FF_IND='CHEM' then &ind_var=14;

*15 Rubbr  Rubber and Plastic Products;
    if &sic ge 3031 and &sic le 3031   then FF_IND='RUBBR';
    if &sic ge 3041 and &sic le 3041   then FF_IND='RUBBR';
    if &sic ge 3050 and &sic le 3053   then FF_IND='RUBBR';
    if &sic ge 3060 and &sic le 3069   then FF_IND='RUBBR';
    if &sic ge 3070 and &sic le 3079   then FF_IND='RUBBR';
    if &sic ge 3080 and &sic le 3089   then FF_IND='RUBBR';
    if &sic ge 3090 and &sic le 3099   then FF_IND='RUBBR';
    if FF_IND='RUBBR' then &ind_var=15;

*16 Txtls  Textiles;
    if &sic ge 2200 and &sic le 2269   then FF_IND='TXTLS';
    if &sic ge 2270 and &sic le 2279   then FF_IND='TXTLS';
    if &sic ge 2280 and &sic le 2284   then FF_IND='TXTLS';
    if &sic ge 2290 and &sic le 2295   then FF_IND='TXTLS';
    if &sic ge 2297 and &sic le 2297   then FF_IND='TXTLS';
    if &sic ge 2298 and &sic le 2298   then FF_IND='TXTLS';
    if &sic ge 2299 and &sic le 2299   then FF_IND='TXTLS';
    if &sic ge 2393 and &sic le 2395   then FF_IND='TXTLS';
    if &sic ge 2397 and &sic le 2399   then FF_IND='TXTLS';
    if FF_IND='TXTLS' then &ind_var=16;

*17 BldMt  Construction Materials;
    if &sic ge 0800 and &sic le 0899   then FF_IND='BLDMT';
    if &sic ge 2400 and &sic le 2439   then FF_IND='BLDMT';
    if &sic ge 2450 and &sic le 2459   then FF_IND='BLDMT';
    if &sic ge 2490 and &sic le 2499   then FF_IND='BLDMT';
    if &sic ge 2660 and &sic le 2661   then FF_IND='BLDMT';
    if &sic ge 2950 and &sic le 2952   then FF_IND='BLDMT';
    if &sic ge 3200 and &sic le 3200   then FF_IND='BLDMT';
    if &sic ge 3210 and &sic le 3211   then FF_IND='BLDMT';
    if &sic ge 3240 and &sic le 3241   then FF_IND='BLDMT';
    if &sic ge 3250 and &sic le 3259   then FF_IND='BLDMT';
    if &sic ge 3261 and &sic le 3261   then FF_IND='BLDMT';
    if &sic ge 3264 and &sic le 3264   then FF_IND='BLDMT';
    if &sic ge 3270 and &sic le 3275   then FF_IND='BLDMT';
    if &sic ge 3280 and &sic le 3281   then FF_IND='BLDMT';
    if &sic ge 3290 and &sic le 3293   then FF_IND='BLDMT';
    if &sic ge 3295 and &sic le 3299   then FF_IND='BLDMT';
    if &sic ge 3420 and &sic le 3429   then FF_IND='BLDMT';
    if &sic ge 3430 and &sic le 3433   then FF_IND='BLDMT';
    if &sic ge 3440 and &sic le 3441   then FF_IND='BLDMT';
    if &sic ge 3442 and &sic le 3442   then FF_IND='BLDMT';
    if &sic ge 3446 and &sic le 3446   then FF_IND='BLDMT';
    if &sic ge 3448 and &sic le 3448   then FF_IND='BLDMT';
    if &sic ge 3449 and &sic le 3449   then FF_IND='BLDMT';
    if &sic ge 3450 and &sic le 3451   then FF_IND='BLDMT';
    if &sic ge 3452 and &sic le 3452   then FF_IND='BLDMT';
    if &sic ge 3490 and &sic le 3499   then FF_IND='BLDMT';
    if &sic ge 3996 and &sic le 3996   then FF_IND='BLDMT';
    if FF_IND='BLDMT' then &ind_var=17;

*18 Cnstr  Construction;
    if &sic ge 1500 and &sic le 1511   then FF_IND='CNSTR';
    if &sic ge 1520 and &sic le 1529   then FF_IND='CNSTR';
    if &sic ge 1530 and &sic le 1539   then FF_IND='CNSTR';
    if &sic ge 1540 and &sic le 1549   then FF_IND='CNSTR';
    if &sic ge 1600 and &sic le 1699   then FF_IND='CNSTR';
    if &sic ge 1700 and &sic le 1799   then FF_IND='CNSTR';
    if FF_IND='CNSTR' then &ind_var=18;

*19 Steel  Steel Works Etc;
    if &sic ge 3300 and &sic le 3300   then FF_IND='STEEL';
    if &sic ge 3310 and &sic le 3317   then FF_IND='STEEL';
    if &sic ge 3320 and &sic le 3325   then FF_IND='STEEL';
    if &sic ge 3330 and &sic le 3339   then FF_IND='STEEL';
    if &sic ge 3340 and &sic le 3341   then FF_IND='STEEL';
    if &sic ge 3350 and &sic le 3357   then FF_IND='STEEL';
    if &sic ge 3360 and &sic le 3369   then FF_IND='STEEL';
    if &sic ge 3370 and &sic le 3379   then FF_IND='STEEL';
    if &sic ge 3390 and &sic le 3399   then FF_IND='STEEL';
    if FF_IND='STEEL' then &ind_var=19;

*20 FabPr  Fabricated Products;
    if &sic ge 3400 and &sic le 3400   then FF_IND='FABPR';
    if &sic ge 3443 and &sic le 3443   then FF_IND='FABPR';
    if &sic ge 3444 and &sic le 3444   then FF_IND='FABPR';
    if &sic ge 3460 and &sic le 3469   then FF_IND='FABPR';
    if &sic ge 3470 and &sic le 3479   then FF_IND='FABPR';
    if FF_IND='FABPR' then &ind_var=20;

*21 Mach   Machinery;
    if &sic ge 3510 and &sic le 3519   then FF_IND='MACH';
    if &sic ge 3520 and &sic le 3529   then FF_IND='MACH';
    if &sic ge 3530 and &sic le 3530   then FF_IND='MACH';
    if &sic ge 3531 and &sic le 3531   then FF_IND='MACH';
    if &sic ge 3532 and &sic le 3532   then FF_IND='MACH';
    if &sic ge 3533 and &sic le 3533   then FF_IND='MACH';
    if &sic ge 3534 and &sic le 3534   then FF_IND='MACH';
    if &sic ge 3535 and &sic le 3535   then FF_IND='MACH';
    if &sic ge 3536 and &sic le 3536   then FF_IND='MACH';
    if &sic ge 3538 and &sic le 3538   then FF_IND='MACH';
    if &sic ge 3540 and &sic le 3549   then FF_IND='MACH';
    if &sic ge 3550 and &sic le 3559   then FF_IND='MACH';
    if &sic ge 3560 and &sic le 3569   then FF_IND='MACH';
    if &sic ge 3580 and &sic le 3580   then FF_IND='MACH';
    if &sic ge 3581 and &sic le 3581   then FF_IND='MACH';
    if &sic ge 3582 and &sic le 3582   then FF_IND='MACH';
    if &sic ge 3585 and &sic le 3585   then FF_IND='MACH';
    if &sic ge 3586 and &sic le 3586   then FF_IND='MACH';
    if &sic ge 3589 and &sic le 3589   then FF_IND='MACH';
    if &sic ge 3590 and &sic le 3599   then FF_IND='MACH';
    if FF_IND='MACH' then &ind_var=21;

*22 ElcEq  Electrical Equipment;
    if &sic ge 3600 and &sic le 3600   then FF_IND='ELCEQ';
    if &sic ge 3610 and &sic le 3613   then FF_IND='ELCEQ';
    if &sic ge 3620 and &sic le 3621   then FF_IND='ELCEQ';
    if &sic ge 3623 and &sic le 3629   then FF_IND='ELCEQ';
    if &sic ge 3640 and &sic le 3644   then FF_IND='ELCEQ';
    if &sic ge 3645 and &sic le 3645   then FF_IND='ELCEQ';
    if &sic ge 3646 and &sic le 3646   then FF_IND='ELCEQ';
    if &sic ge 3648 and &sic le 3649   then FF_IND='ELCEQ';
    if &sic ge 3660 and &sic le 3660   then FF_IND='ELCEQ';
    if &sic ge 3690 and &sic le 3690   then FF_IND='ELCEQ';
    if &sic ge 3691 and &sic le 3692   then FF_IND='ELCEQ';
    if &sic ge 3699 and &sic le 3699   then FF_IND='ELCEQ';
    if FF_IND='ELCEQ' then &ind_var=22;

*23 Autos  Automobiles and Trucks;
    if &sic ge 2296 and &sic le 2296   then FF_IND='AUTOS';
    if &sic ge 2396 and &sic le 2396   then FF_IND='AUTOS';
    if &sic ge 3010 and &sic le 3011   then FF_IND='AUTOS';
    if &sic ge 3537 and &sic le 3537   then FF_IND='AUTOS';
    if &sic ge 3647 and &sic le 3647   then FF_IND='AUTOS';
    if &sic ge 3694 and &sic le 3694   then FF_IND='AUTOS';
    if &sic ge 3700 and &sic le 3700   then FF_IND='AUTOS';
    if &sic ge 3710 and &sic le 3710   then FF_IND='AUTOS';
    if &sic ge 3711 and &sic le 3711   then FF_IND='AUTOS';
    if &sic ge 3713 and &sic le 3713   then FF_IND='AUTOS';
    if &sic ge 3714 and &sic le 3714   then FF_IND='AUTOS';
    if &sic ge 3715 and &sic le 3715   then FF_IND='AUTOS';
    if &sic ge 3716 and &sic le 3716   then FF_IND='AUTOS';
    if &sic ge 3792 and &sic le 3792   then FF_IND='AUTOS';
    if &sic ge 3790 and &sic le 3791   then FF_IND='AUTOS';
    if &sic ge 3799 and &sic le 3799   then FF_IND='AUTOS';
    if FF_IND='AUTOS' then &ind_var=23;

*24 Aero   Aircraft;
    if &sic ge 3720 and &sic le 3720   then FF_IND='AERO';
    if &sic ge 3721 and &sic le 3721   then FF_IND='AERO';
    if &sic ge 3723 and &sic le 3724   then FF_IND='AERO';
    if &sic ge 3725 and &sic le 3725   then FF_IND='AERO';
    if &sic ge 3728 and &sic le 3729   then FF_IND='AERO';
    if FF_IND='AERO' then &ind_var=24;

*25 Ships  Shipbuilding, Railroad Equipment;
    if &sic ge 3730 and &sic le 3731   then FF_IND='SHIPS';
    if &sic ge 3740 and &sic le 3743   then FF_IND='SHIPS';
    if FF_IND='SHIPS' then &ind_var=25;

*26 Guns   Defense;
    if &sic ge 3760 and &sic le 3769   then FF_IND='GUNS';
    if &sic ge 3795 and &sic le 3795   then FF_IND='GUNS';
    if &sic ge 3480 and &sic le 3489   then FF_IND='GUNS';
    if FF_IND='GUNS' then &ind_var=26;

*27 Gold   Precious Metals;
    if &sic ge 1040 and &sic le 1049   then FF_IND='GOLD';
    if FF_IND='GOLD' then &ind_var=27;

*28 Mines  Non and &sic le Metallic and Industrial Metal Mining;;
    if &sic ge 1000 and &sic le 1009   then FF_IND='MINES';
    if &sic ge 1010 and &sic le 1019   then FF_IND='MINES';
    if &sic ge 1020 and &sic le 1029   then FF_IND='MINES';
    if &sic ge 1030 and &sic le 1039   then FF_IND='MINES';
    if &sic ge 1050 and &sic le 1059   then FF_IND='MINES';
    if &sic ge 1060 and &sic le 1069   then FF_IND='MINES';
    if &sic ge 1070 and &sic le 1079   then FF_IND='MINES';
    if &sic ge 1080 and &sic le 1089   then FF_IND='MINES';
    if &sic ge 1090 and &sic le 1099   then FF_IND='MINES';
    if &sic ge 1100 and &sic le 1119   then FF_IND='MINES';
    if &sic ge 1400 and &sic le 1499   then FF_IND='MINES';
    if FF_IND='MINES' then &ind_var=28;

*29 Coal   Coal;
    if &sic ge 1200 and &sic le 1299   then FF_IND='COAL';
    if FF_IND='COAL' then &ind_var=29;

*30 Oil    Petroleum and Natural Gas;
    if &sic ge 1300 and &sic le 1300   then FF_IND='OIL';
    if &sic ge 1310 and &sic le 1319   then FF_IND='OIL';
    if &sic ge 1320 and &sic le 1329   then FF_IND='OIL';
    if &sic ge 1330 and &sic le 1339   then FF_IND='OIL';
    if &sic ge 1370 and &sic le 1379   then FF_IND='OIL';
    if &sic ge 1380 and &sic le 1380   then FF_IND='OIL';
    if &sic ge 1381 and &sic le 1381   then FF_IND='OIL';
    if &sic ge 1382 and &sic le 1382   then FF_IND='OIL';
    if &sic ge 1389 and &sic le 1389   then FF_IND='OIL';
    if &sic ge 2900 and &sic le 2912   then FF_IND='OIL';
    if &sic ge 2990 and &sic le 2999   then FF_IND='OIL';
    if FF_IND='OIL' then &ind_var=30;

*31 Util   Utilities;
    if &sic ge 4900 and &sic le 4900   then FF_IND='UTIL';
    if &sic ge 4910 and &sic le 4911   then FF_IND='UTIL';
    if &sic ge 4920 and &sic le 4922   then FF_IND='UTIL';
    if &sic ge 4923 and &sic le 4923   then FF_IND='UTIL';
    if &sic ge 4924 and &sic le 4925   then FF_IND='UTIL';
    if &sic ge 4930 and &sic le 4931   then FF_IND='UTIL';
    if &sic ge 4932 and &sic le 4932   then FF_IND='UTIL';
    if &sic ge 4939 and &sic le 4939   then FF_IND='UTIL';
    if &sic ge 4940 and &sic le 4942   then FF_IND='UTIL';
    if FF_IND='UTIL' then &ind_var=31;

*32 Telcm  Communication;
    if &sic ge 4800 and &sic le 4800   then FF_IND='TELCM';
    if &sic ge 4810 and &sic le 4813   then FF_IND='TELCM';
    if &sic ge 4820 and &sic le 4822   then FF_IND='TELCM';
    if &sic ge 4830 and &sic le 4839   then FF_IND='TELCM';
    if &sic ge 4840 and &sic le 4841   then FF_IND='TELCM';
    if &sic ge 4880 and &sic le 4889   then FF_IND='TELCM';
    if &sic ge 4890 and &sic le 4890   then FF_IND='TELCM';
    if &sic ge 4891 and &sic le 4891   then FF_IND='TELCM';
    if &sic ge 4892 and &sic le 4892   then FF_IND='TELCM';
    if &sic ge 4899 and &sic le 4899   then FF_IND='TELCM';
    if FF_IND='TELCM' then &ind_var=32;

*33 PerSv  Personal Services;
    if &sic ge 7020 and &sic le 7021   then FF_IND='PERSV';
    if &sic ge 7030 and &sic le 7033   then FF_IND='PERSV';
    if &sic ge 7200 and &sic le 7200   then FF_IND='PERSV';
    if &sic ge 7210 and &sic le 7212   then FF_IND='PERSV';
    if &sic ge 7214 and &sic le 7214   then FF_IND='PERSV';
    if &sic ge 7215 and &sic le 7216   then FF_IND='PERSV';
    if &sic ge 7217 and &sic le 7217   then FF_IND='PERSV';
    if &sic ge 7219 and &sic le 7219   then FF_IND='PERSV';
    if &sic ge 7220 and &sic le 7221   then FF_IND='PERSV';
    if &sic ge 7230 and &sic le 7231   then FF_IND='PERSV';
    if &sic ge 7240 and &sic le 7241   then FF_IND='PERSV';
    if &sic ge 7250 and &sic le 7251   then FF_IND='PERSV';
    if &sic ge 7260 and &sic le 7269   then FF_IND='PERSV';
    if &sic ge 7270 and &sic le 7290   then FF_IND='PERSV';
    if &sic ge 7291 and &sic le 7291   then FF_IND='PERSV';
    if &sic ge 7292 and &sic le 7299   then FF_IND='PERSV';
    if &sic ge 7395 and &sic le 7395   then FF_IND='PERSV';
    if &sic ge 7500 and &sic le 7500   then FF_IND='PERSV';
    if &sic ge 7520 and &sic le 7529   then FF_IND='PERSV';
    if &sic ge 7530 and &sic le 7539   then FF_IND='PERSV';
    if &sic ge 7540 and &sic le 7549   then FF_IND='PERSV';
    if &sic ge 7600 and &sic le 7600   then FF_IND='PERSV';
    if &sic ge 7620 and &sic le 7620   then FF_IND='PERSV';
    if &sic ge 7622 and &sic le 7622   then FF_IND='PERSV';
    if &sic ge 7623 and &sic le 7623   then FF_IND='PERSV';
    if &sic ge 7629 and &sic le 7629   then FF_IND='PERSV';
    if &sic ge 7630 and &sic le 7631   then FF_IND='PERSV';
    if &sic ge 7640 and &sic le 7641   then FF_IND='PERSV';
    if &sic ge 7690 and &sic le 7699   then FF_IND='PERSV';
    if &sic ge 8100 and &sic le 8199   then FF_IND='PERSV';
    if &sic ge 8200 and &sic le 8299   then FF_IND='PERSV';
    if &sic ge 8300 and &sic le 8399   then FF_IND='PERSV';
    if &sic ge 8400 and &sic le 8499   then FF_IND='PERSV';
    if &sic ge 8600 and &sic le 8699   then FF_IND='PERSV';
    if &sic ge 8800 and &sic le 8899   then FF_IND='PERSV';
    if &sic ge 7510 and &sic le 7515   then FF_IND='PERSV';
    if FF_IND='PERSV' then &ind_var=33;

*34 BusSv  Business Services;
    if &sic ge 2750 and &sic le 2759   then FF_IND='BUSSV';
    if &sic ge 3993 and &sic le 3993   then FF_IND='BUSSV';
    if &sic ge 7218 and &sic le 7218   then FF_IND='BUSSV';
    if &sic ge 7300 and &sic le 7300   then FF_IND='BUSSV';
    if &sic ge 7310 and &sic le 7319   then FF_IND='BUSSV';
    if &sic ge 7320 and &sic le 7329   then FF_IND='BUSSV';
    if &sic ge 7330 and &sic le 7339   then FF_IND='BUSSV';
    if &sic ge 7340 and &sic le 7342   then FF_IND='BUSSV';
    if &sic ge 7349 and &sic le 7349   then FF_IND='BUSSV';
    if &sic ge 7350 and &sic le 7351   then FF_IND='BUSSV';
    if &sic ge 7352 and &sic le 7352   then FF_IND='BUSSV';
    if &sic ge 7353 and &sic le 7353   then FF_IND='BUSSV';
    if &sic ge 7359 and &sic le 7359   then FF_IND='BUSSV';
    if &sic ge 7360 and &sic le 7369   then FF_IND='BUSSV';
    if &sic ge 7370 and &sic le 7372   then FF_IND='BUSSV';
    if &sic ge 7374 and &sic le 7374   then FF_IND='BUSSV';
    if &sic ge 7375 and &sic le 7375   then FF_IND='BUSSV';
    if &sic ge 7376 and &sic le 7376   then FF_IND='BUSSV';
    if &sic ge 7377 and &sic le 7377   then FF_IND='BUSSV';
    if &sic ge 7378 and &sic le 7378   then FF_IND='BUSSV';
    if &sic ge 7379 and &sic le 7379   then FF_IND='BUSSV';
    if &sic ge 7380 and &sic le 7380   then FF_IND='BUSSV';
    if &sic ge 7381 and &sic le 7382   then FF_IND='BUSSV';
    if &sic ge 7383 and &sic le 7383   then FF_IND='BUSSV';
    if &sic ge 7384 and &sic le 7384   then FF_IND='BUSSV';
    if &sic ge 7385 and &sic le 7385   then FF_IND='BUSSV';
    if &sic ge 7389 and &sic le 7390   then FF_IND='BUSSV';
    if &sic ge 7391 and &sic le 7391   then FF_IND='BUSSV';
    if &sic ge 7392 and &sic le 7392   then FF_IND='BUSSV';
    if &sic ge 7393 and &sic le 7393   then FF_IND='BUSSV';
    if &sic ge 7394 and &sic le 7394   then FF_IND='BUSSV';
    if &sic ge 7396 and &sic le 7396   then FF_IND='BUSSV';
    if &sic ge 7397 and &sic le 7397   then FF_IND='BUSSV';
    if &sic ge 7399 and &sic le 7399   then FF_IND='BUSSV';
    if &sic ge 7519 and &sic le 7519   then FF_IND='BUSSV';
    if &sic ge 8700 and &sic le 8700   then FF_IND='BUSSV';
    if &sic ge 8710 and &sic le 8713   then FF_IND='BUSSV';
    if &sic ge 8720 and &sic le 8721   then FF_IND='BUSSV';
    if &sic ge 8730 and &sic le 8734   then FF_IND='BUSSV';
    if &sic ge 8740 and &sic le 8748   then FF_IND='BUSSV';
    if &sic ge 8900 and &sic le 8910   then FF_IND='BUSSV';
    if &sic ge 8911 and &sic le 8911   then FF_IND='BUSSV';
    if &sic ge 8920 and &sic le 8999   then FF_IND='BUSSV';
    if &sic ge 4220 and &sic le 4229  then FF_IND='BUSSV';
    if FF_IND='BUSSV' then &ind_var=34;

*35 Comps  Computers;
    if &sic ge 3570 and &sic le 3579   then FF_IND='COMPS';
    if &sic ge 3680 and &sic le 3680   then FF_IND='COMPS';
    if &sic ge 3681 and &sic le 3681   then FF_IND='COMPS';
    if &sic ge 3682 and &sic le 3682   then FF_IND='COMPS';
    if &sic ge 3683 and &sic le 3683   then FF_IND='COMPS';
    if &sic ge 3684 and &sic le 3684   then FF_IND='COMPS';
    if &sic ge 3685 and &sic le 3685   then FF_IND='COMPS';
    if &sic ge 3686 and &sic le 3686   then FF_IND='COMPS';
    if &sic ge 3687 and &sic le 3687   then FF_IND='COMPS';
    if &sic ge 3688 and &sic le 3688   then FF_IND='COMPS';
    if &sic ge 3689 and &sic le 3689   then FF_IND='COMPS';
    if &sic ge 3695 and &sic le 3695   then FF_IND='COMPS';
    if &sic ge 7373 and &sic le 7373   then FF_IND='COMPS';
    if FF_IND='COMPS' then &ind_var=35;

*36 Chips  Electronic Equipment;
    if &sic ge 3622 and &sic le 3622   then FF_IND='CHIPS';
    if &sic ge 3661 and &sic le 3661   then FF_IND='CHIPS';
    if &sic ge 3662 and &sic le 3662   then FF_IND='CHIPS';
    if &sic ge 3663 and &sic le 3663   then FF_IND='CHIPS';
    if &sic ge 3664 and &sic le 3664   then FF_IND='CHIPS';
    if &sic ge 3665 and &sic le 3665   then FF_IND='CHIPS';
    if &sic ge 3666 and &sic le 3666   then FF_IND='CHIPS';
    if &sic ge 3669 and &sic le 3669   then FF_IND='CHIPS';
    if &sic ge 3670 and &sic le 3679   then FF_IND='CHIPS';
    if &sic ge 3810 and &sic le 3810   then FF_IND='CHIPS';
    if &sic ge 3812 and &sic le 3812   then FF_IND='CHIPS';
    if FF_IND='CHIPS' then &ind_var=36;

*37 LabEq  Measuring and Control Equipment;
    if &sic ge 3811 and &sic le 3811   then FF_IND='LABEQ';
    if &sic ge 3820 and &sic le 3820   then FF_IND='LABEQ';
    if &sic ge 3821 and &sic le 3821   then FF_IND='LABEQ';
    if &sic ge 3822 and &sic le 3822   then FF_IND='LABEQ';
    if &sic ge 3823 and &sic le 3823   then FF_IND='LABEQ';
    if &sic ge 3824 and &sic le 3824   then FF_IND='LABEQ';
    if &sic ge 3825 and &sic le 3825   then FF_IND='LABEQ';
    if &sic ge 3826 and &sic le 3826   then FF_IND='LABEQ';
    if &sic ge 3827 and &sic le 3827   then FF_IND='LABEQ';
    if &sic ge 3829 and &sic le 3829   then FF_IND='LABEQ';
    if &sic ge 3830 and &sic le 3839   then FF_IND='LABEQ';
    if FF_IND='LABEQ' then &ind_var=37;

*38 Paper  Business Supplies;
    if &sic ge 2520 and &sic le 2549   then FF_IND='PAPER';
    if &sic ge 2600 and &sic le 2639   then FF_IND='PAPER';
    if &sic ge 2670 and &sic le 2699   then FF_IND='PAPER';
    if &sic ge 2760 and &sic le 2761   then FF_IND='PAPER';
    if &sic ge 3950 and &sic le 3955   then FF_IND='PAPER';
    if FF_IND='PAPER' then &ind_var=38;

*39 Boxes  Shipping Containers;
    if &sic ge 2440 and &sic le 2449   then FF_IND='BOXES';
    if &sic ge 2640 and &sic le 2659   then FF_IND='BOXES';
    if &sic ge 3220 and &sic le 3221   then FF_IND='BOXES';
    if &sic ge 3410 and &sic le 3412   then FF_IND='BOXES';
    if FF_IND='BOXES' then &ind_var=39;

*40 Trans  Transportation;
    if &sic ge 4000 and &sic le 4013   then FF_IND='TRANS';
    if &sic ge 4040 and &sic le 4049   then FF_IND='TRANS';
    if &sic ge 4100 and &sic le 4100   then FF_IND='TRANS';
    if &sic ge 4110 and &sic le 4119   then FF_IND='TRANS';
    if &sic ge 4120 and &sic le 4121   then FF_IND='TRANS';
    if &sic ge 4130 and &sic le 4131   then FF_IND='TRANS';
    if &sic ge 4140 and &sic le 4142   then FF_IND='TRANS';
    if &sic ge 4150 and &sic le 4151   then FF_IND='TRANS';
    if &sic ge 4170 and &sic le 4173   then FF_IND='TRANS';
    if &sic ge 4190 and &sic le 4199   then FF_IND='TRANS';
    if &sic ge 4200 and &sic le 4200   then FF_IND='TRANS';
    if &sic ge 4210 and &sic le 4219   then FF_IND='TRANS';
    if &sic ge 4230 and &sic le 4231   then FF_IND='TRANS';
    if &sic ge 4240 and &sic le 4249   then FF_IND='TRANS';
    if &sic ge 4400 and &sic le 4499   then FF_IND='TRANS';
    if &sic ge 4500 and &sic le 4599   then FF_IND='TRANS';
    if &sic ge 4600 and &sic le 4699   then FF_IND='TRANS';
    if &sic ge 4700 and &sic le 4700   then FF_IND='TRANS';
    if &sic ge 4710 and &sic le 4712   then FF_IND='TRANS';
    if &sic ge 4720 and &sic le 4729   then FF_IND='TRANS';
    if &sic ge 4730 and &sic le 4739   then FF_IND='TRANS';
    if &sic ge 4740 and &sic le 4749   then FF_IND='TRANS';
    if &sic ge 4780 and &sic le 4780   then FF_IND='TRANS';
    if &sic ge 4782 and &sic le 4782   then FF_IND='TRANS';
    if &sic ge 4783 and &sic le 4783   then FF_IND='TRANS';
    if &sic ge 4784 and &sic le 4784   then FF_IND='TRANS';
    if &sic ge 4785 and &sic le 4785   then FF_IND='TRANS';
    if &sic ge 4789 and &sic le 4789   then FF_IND='TRANS';
    if FF_IND='TRANS' then &ind_var=40;

*41 Whlsl  Wholesale;
    if &sic ge 5000 and &sic le 5000   then FF_IND='WHLSL';
    if &sic ge 5010 and &sic le 5015   then FF_IND='WHLSL';
    if &sic ge 5020 and &sic le 5023   then FF_IND='WHLSL';
    if &sic ge 5030 and &sic le 5039   then FF_IND='WHLSL';
    if &sic ge 5040 and &sic le 5042   then FF_IND='WHLSL';
    if &sic ge 5043 and &sic le 5043   then FF_IND='WHLSL';
    if &sic ge 5044 and &sic le 5044   then FF_IND='WHLSL';
    if &sic ge 5045 and &sic le 5045   then FF_IND='WHLSL';
    if &sic ge 5046 and &sic le 5046   then FF_IND='WHLSL';
    if &sic ge 5047 and &sic le 5047   then FF_IND='WHLSL';
    if &sic ge 5048 and &sic le 5048   then FF_IND='WHLSL';
    if &sic ge 5049 and &sic le 5049   then FF_IND='WHLSL';
    if &sic ge 5050 and &sic le 5059   then FF_IND='WHLSL';
    if &sic ge 5060 and &sic le 5060   then FF_IND='WHLSL';
    if &sic ge 5063 and &sic le 5063   then FF_IND='WHLSL';
    if &sic ge 5064 and &sic le 5064   then FF_IND='WHLSL';
    if &sic ge 5065 and &sic le 5065   then FF_IND='WHLSL';
    if &sic ge 5070 and &sic le 5078   then FF_IND='WHLSL';
    if &sic ge 5080 and &sic le 5080   then FF_IND='WHLSL';
    if &sic ge 5081 and &sic le 5081   then FF_IND='WHLSL';
    if &sic ge 5082 and &sic le 5082   then FF_IND='WHLSL';
    if &sic ge 5083 and &sic le 5083   then FF_IND='WHLSL';
    if &sic ge 5084 and &sic le 5084   then FF_IND='WHLSL';
    if &sic ge 5085 and &sic le 5085   then FF_IND='WHLSL';
    if &sic ge 5086 and &sic le 5087   then FF_IND='WHLSL';
    if &sic ge 5088 and &sic le 5088   then FF_IND='WHLSL';
    if &sic ge 5090 and &sic le 5090   then FF_IND='WHLSL';
    if &sic ge 5091 and &sic le 5092   then FF_IND='WHLSL';
    if &sic ge 5093 and &sic le 5093   then FF_IND='WHLSL';
    if &sic ge 5094 and &sic le 5094   then FF_IND='WHLSL';
    if &sic ge 5099 and &sic le 5099   then FF_IND='WHLSL';
    if &sic ge 5100 and &sic le 5100   then FF_IND='WHLSL';
    if &sic ge 5110 and &sic le 5113   then FF_IND='WHLSL';
    if &sic ge 5120 and &sic le 5122   then FF_IND='WHLSL';
    if &sic ge 5130 and &sic le 5139   then FF_IND='WHLSL';
    if &sic ge 5140 and &sic le 5149   then FF_IND='WHLSL';
    if &sic ge 5150 and &sic le 5159   then FF_IND='WHLSL';
    if &sic ge 5160 and &sic le 5169   then FF_IND='WHLSL';
    if &sic ge 5170 and &sic le 5172   then FF_IND='WHLSL';
    if &sic ge 5180 and &sic le 5182   then FF_IND='WHLSL';
    if &sic ge 5190 and &sic le 5199   then FF_IND='WHLSL';
    if FF_IND='WHLSL' then &ind_var=41;

*42 Rtail  Retail ;
    if &sic ge 5200 and &sic le 5200   then FF_IND='RTAIL';
    if &sic ge 5210 and &sic le 5219   then FF_IND='RTAIL';
    if &sic ge 5220 and &sic le 5229   then FF_IND='RTAIL';
    if &sic ge 5230 and &sic le 5231   then FF_IND='RTAIL';
    if &sic ge 5250 and &sic le 5251   then FF_IND='RTAIL';
    if &sic ge 5260 and &sic le 5261   then FF_IND='RTAIL';
    if &sic ge 5270 and &sic le 5271   then FF_IND='RTAIL';
    if &sic ge 5300 and &sic le 5300   then FF_IND='RTAIL';
    if &sic ge 5310 and &sic le 5311   then FF_IND='RTAIL';
    if &sic ge 5320 and &sic le 5320   then FF_IND='RTAIL';
    if &sic ge 5330 and &sic le 5331   then FF_IND='RTAIL';
    if &sic ge 5334 and &sic le 5334   then FF_IND='RTAIL';
    if &sic ge 5340 and &sic le 5349   then FF_IND='RTAIL';
    if &sic ge 5390 and &sic le 5399   then FF_IND='RTAIL';
    if &sic ge 5400 and &sic le 5400   then FF_IND='RTAIL';
    if &sic ge 5410 and &sic le 5411   then FF_IND='RTAIL';
    if &sic ge 5412 and &sic le 5412   then FF_IND='RTAIL';
    if &sic ge 5420 and &sic le 5429   then FF_IND='RTAIL';
    if &sic ge 5430 and &sic le 5439   then FF_IND='RTAIL';
    if &sic ge 5440 and &sic le 5449   then FF_IND='RTAIL';
    if &sic ge 5450 and &sic le 5459   then FF_IND='RTAIL';
    if &sic ge 5460 and &sic le 5469   then FF_IND='RTAIL';
    if &sic ge 5490 and &sic le 5499   then FF_IND='RTAIL';
    if &sic ge 5500 and &sic le 5500   then FF_IND='RTAIL';
    if &sic ge 5510 and &sic le 5529   then FF_IND='RTAIL';
    if &sic ge 5530 and &sic le 5539   then FF_IND='RTAIL';
    if &sic ge 5540 and &sic le 5549   then FF_IND='RTAIL';
    if &sic ge 5550 and &sic le 5559   then FF_IND='RTAIL';
    if &sic ge 5560 and &sic le 5569   then FF_IND='RTAIL';
    if &sic ge 5570 and &sic le 5579   then FF_IND='RTAIL';
    if &sic ge 5590 and &sic le 5599   then FF_IND='RTAIL';
    if &sic ge 5600 and &sic le 5699   then FF_IND='RTAIL';
    if &sic ge 5700 and &sic le 5700   then FF_IND='RTAIL';
    if &sic ge 5710 and &sic le 5719   then FF_IND='RTAIL';
    if &sic ge 5720 and &sic le 5722   then FF_IND='RTAIL';
    if &sic ge 5730 and &sic le 5733   then FF_IND='RTAIL';
    if &sic ge 5734 and &sic le 5734   then FF_IND='RTAIL';
    if &sic ge 5735 and &sic le 5735   then FF_IND='RTAIL';
    if &sic ge 5736 and &sic le 5736   then FF_IND='RTAIL';
    if &sic ge 5750 and &sic le 5799   then FF_IND='RTAIL';
    if &sic ge 5900 and &sic le 5900   then FF_IND='RTAIL';
    if &sic ge 5910 and &sic le 5912   then FF_IND='RTAIL';
    if &sic ge 5920 and &sic le 5929   then FF_IND='RTAIL';
    if &sic ge 5930 and &sic le 5932   then FF_IND='RTAIL';
    if &sic ge 5940 and &sic le 5940   then FF_IND='RTAIL';
    if &sic ge 5941 and &sic le 5941   then FF_IND='RTAIL';
    if &sic ge 5942 and &sic le 5942   then FF_IND='RTAIL';
    if &sic ge 5943 and &sic le 5943   then FF_IND='RTAIL';
    if &sic ge 5944 and &sic le 5944   then FF_IND='RTAIL';
    if &sic ge 5945 and &sic le 5945   then FF_IND='RTAIL';
    if &sic ge 5946 and &sic le 5946   then FF_IND='RTAIL';
    if &sic ge 5947 and &sic le 5947   then FF_IND='RTAIL';
    if &sic ge 5948 and &sic le 5948   then FF_IND='RTAIL';
    if &sic ge 5949 and &sic le 5949   then FF_IND='RTAIL';
    if &sic ge 5950 and &sic le 5959   then FF_IND='RTAIL';
    if &sic ge 5960 and &sic le 5969   then FF_IND='RTAIL';
    if &sic ge 5970 and &sic le 5979   then FF_IND='RTAIL';
    if &sic ge 5980 and &sic le 5989   then FF_IND='RTAIL';
    if &sic ge 5990 and &sic le 5990   then FF_IND='RTAIL';
    if &sic ge 5992 and &sic le 5992   then FF_IND='RTAIL';
    if &sic ge 5993 and &sic le 5993   then FF_IND='RTAIL';
    if &sic ge 5994 and &sic le 5994   then FF_IND='RTAIL';
    if &sic ge 5995 and &sic le 5995   then FF_IND='RTAIL';
    if &sic ge 5999 and &sic le 5999   then FF_IND='RTAIL';
    if FF_IND='RTAIL' then &ind_var=42;

*43 Meals  Restaraunts, Hotels, Motels;
    if &sic ge 5800 and &sic le 5819   then FF_IND='MEALS';
    if &sic ge 5820 and &sic le 5829   then FF_IND='MEALS';
    if &sic ge 5890 and &sic le 5899   then FF_IND='MEALS';
    if &sic ge 7000 and &sic le 7000   then FF_IND='MEALS';
    if &sic ge 7010 and &sic le 7019   then FF_IND='MEALS';
    if &sic ge 7040 and &sic le 7049   then FF_IND='MEALS';
    if &sic ge 7213 and &sic le 7213   then FF_IND='MEALS';
    if FF_IND='MEALS' then &ind_var=43;

*44 Banks  Banking;
    if &sic ge 6000 and &sic le 6000   then FF_IND='BANKS';
    if &sic ge 6010 and &sic le 6019   then FF_IND='BANKS';
    if &sic ge 6020 and &sic le 6020   then FF_IND='BANKS';
    if &sic ge 6021 and &sic le 6021   then FF_IND='BANKS';
    if &sic ge 6022 and &sic le 6022   then FF_IND='BANKS';
    if &sic ge 6023 and &sic le 6024   then FF_IND='BANKS';
    if &sic ge 6025 and &sic le 6025   then FF_IND='BANKS';
    if &sic ge 6026 and &sic le 6026   then FF_IND='BANKS';
    if &sic ge 6027 and &sic le 6027   then FF_IND='BANKS';
    if &sic ge 6028 and &sic le 6029   then FF_IND='BANKS';
    if &sic ge 6030 and &sic le 6036   then FF_IND='BANKS';
    if &sic ge 6040 and &sic le 6059   then FF_IND='BANKS';
    if &sic ge 6060 and &sic le 6062   then FF_IND='BANKS';
    if &sic ge 6080 and &sic le 6082   then FF_IND='BANKS';
    if &sic ge 6090 and &sic le 6099   then FF_IND='BANKS';
    if &sic ge 6100 and &sic le 6100   then FF_IND='BANKS';
    if &sic ge 6110 and &sic le 6111   then FF_IND='BANKS';
    if &sic ge 6112 and &sic le 6113   then FF_IND='BANKS';
    if &sic ge 6120 and &sic le 6129   then FF_IND='BANKS';
    if &sic ge 6130 and &sic le 6139   then FF_IND='BANKS';
    if &sic ge 6140 and &sic le 6149   then FF_IND='BANKS';
    if &sic ge 6150 and &sic le 6159   then FF_IND='BANKS';
    if &sic ge 6160 and &sic le 6169   then FF_IND='BANKS';
    if &sic ge 6170 and &sic le 6179   then FF_IND='BANKS';
    if &sic ge 6190 and &sic le 6199   then FF_IND='BANKS';
    if FF_IND='BANKS' then &ind_var=44;

*45 Insur  Insurance;
    if &sic ge 6300 and &sic le 6300   then FF_IND='INSUR';
    if &sic ge 6310 and &sic le 6319   then FF_IND='INSUR';
    if &sic ge 6320 and &sic le 6329   then FF_IND='INSUR';
    if &sic ge 6330 and &sic le 6331   then FF_IND='INSUR';
    if &sic ge 6350 and &sic le 6351   then FF_IND='INSUR';
    if &sic ge 6360 and &sic le 6361   then FF_IND='INSUR';
    if &sic ge 6370 and &sic le 6379   then FF_IND='INSUR';
    if &sic ge 6390 and &sic le 6399   then FF_IND='INSUR';
    if &sic ge 6400 and &sic le 6411   then FF_IND='INSUR';
    if FF_IND='INSUR' then &ind_var=45;

*46 RlEst  Real Estate;
    if &sic ge 6500 and &sic le 6500   then FF_IND='RLEST';
    if &sic ge 6510 and &sic le 6510   then FF_IND='RLEST';
    if &sic ge 6512 and &sic le 6512   then FF_IND='RLEST';
    if &sic ge 6513 and &sic le 6513   then FF_IND='RLEST';
    if &sic ge 6514 and &sic le 6514   then FF_IND='RLEST';
    if &sic ge 6515 and &sic le 6515   then FF_IND='RLEST';
    if &sic ge 6517 and &sic le 6519   then FF_IND='RLEST';
    if &sic ge 6520 and &sic le 6529   then FF_IND='RLEST';
    if &sic ge 6530 and &sic le 6531   then FF_IND='RLEST';
    if &sic ge 6532 and &sic le 6532   then FF_IND='RLEST';
    if &sic ge 6540 and &sic le 6541   then FF_IND='RLEST';
    if &sic ge 6550 and &sic le 6553   then FF_IND='RLEST';
    if &sic ge 6590 and &sic le 6599   then FF_IND='RLEST';
    if &sic ge 6610 and &sic le 6611   then FF_IND='RLEST';
    if FF_IND='RLEST' then &ind_var=46;

*47 Fin    Trading;
    if &sic ge 6200 and &sic le 6299   then FF_IND='FIN';
    if &sic ge 6700 and &sic le 6700   then FF_IND='FIN';
    if &sic ge 6710 and &sic le 6719   then FF_IND='FIN';
    if &sic ge 6720 and &sic le 6722   then FF_IND='FIN';
    if &sic ge 6723 and &sic le 6723   then FF_IND='FIN';
    if &sic ge 6724 and &sic le 6724   then FF_IND='FIN';
    if &sic ge 6725 and &sic le 6725   then FF_IND='FIN';
    if &sic ge 6726 and &sic le 6726   then FF_IND='FIN';
    if &sic ge 6730 and &sic le 6733   then FF_IND='FIN';
    if &sic ge 6740 and &sic le 6779   then FF_IND='FIN';
    if &sic ge 6790 and &sic le 6791   then FF_IND='FIN';
    if &sic ge 6792 and &sic le 6792   then FF_IND='FIN';
    if &sic ge 6793 and &sic le 6793   then FF_IND='FIN';
    if &sic ge 6794 and &sic le 6794   then FF_IND='FIN';
    if &sic ge 6795 and &sic le 6795   then FF_IND='FIN';
    if &sic ge 6798 and &sic le 6798   then FF_IND='FIN';
    if &sic ge 6799 and &sic le 6799   then FF_IND='FIN';
    if FF_IND='FIN' then &ind_var=47;

*48 Other  Almost Nothing;
    if &sic ge 4950 and &sic le 4959   then FF_IND='OTHER';
    if &sic ge 4960 and &sic le 4961   then FF_IND='OTHER';
    if &sic ge 4970 and &sic le 4971   then FF_IND='OTHER';
    if &sic ge 4990 and &sic le 4991   then FF_IND='OTHER';
    if &sic ge 9990 and &sic le 9999   then FF_IND='OTHER';
    if FF_IND='OTHER' then &ind_var=48;

%IF "&dummy_prefix" NE "" %THEN %DO;
    if(&ind_var=1) then &dummy_prefix.1=1;        else &dummy_prefix.1=0;
    if(&ind_var=2) then &dummy_prefix.2=1;        else &dummy_prefix.2=0;
    if(&ind_var=3) then &dummy_prefix.3=1;        else &dummy_prefix.3=0;
    if(&ind_var=4) then &dummy_prefix.4=1;        else &dummy_prefix.4=0;
    if(&ind_var=5) then &dummy_prefix.5=1;        else &dummy_prefix.5=0;
    if(&ind_var=6) then &dummy_prefix.6=1;        else &dummy_prefix.6=0;
    if(&ind_var=7) then &dummy_prefix.7=1;        else &dummy_prefix.7=0;
    if(&ind_var=8) then &dummy_prefix.8=1;        else &dummy_prefix.8=0;
    if(&ind_var=9) then &dummy_prefix.9=1;        else &dummy_prefix.9=0;
    if(&ind_var=10) then &dummy_prefix.10=1;        else &dummy_prefix.10=0;
    if(&ind_var=11) then &dummy_prefix.11=1;        else &dummy_prefix.11=0;
    if(&ind_var=12) then &dummy_prefix.12=1;        else &dummy_prefix.12=0;
    if(&ind_var=13) then &dummy_prefix.13=1;        else &dummy_prefix.13=0;
    if(&ind_var=14) then &dummy_prefix.14=1;        else &dummy_prefix.14=0;
    if(&ind_var=15) then &dummy_prefix.15=1;        else &dummy_prefix.15=0;
    if(&ind_var=16) then &dummy_prefix.16=1;        else &dummy_prefix.16=0;
    if(&ind_var=17) then &dummy_prefix.17=1;        else &dummy_prefix.17=0;
    if(&ind_var=18) then &dummy_prefix.18=1;        else &dummy_prefix.18=0;
    if(&ind_var=19) then &dummy_prefix.19=1;        else &dummy_prefix.19=0;
    if(&ind_var=20) then &dummy_prefix.20=1;        else &dummy_prefix.20=0;
    if(&ind_var=21) then &dummy_prefix.21=1;        else &dummy_prefix.21=0;
    if(&ind_var=22) then &dummy_prefix.22=1;        else &dummy_prefix.22=0;
    if(&ind_var=23) then &dummy_prefix.23=1;        else &dummy_prefix.23=0;
    if(&ind_var=24) then &dummy_prefix.24=1;        else &dummy_prefix.24=0;
    if(&ind_var=25) then &dummy_prefix.25=1;        else &dummy_prefix.25=0;
    if(&ind_var=26) then &dummy_prefix.26=1;        else &dummy_prefix.26=0;
    if(&ind_var=27) then &dummy_prefix.27=1;        else &dummy_prefix.27=0;
    if(&ind_var=28) then &dummy_prefix.28=1;        else &dummy_prefix.28=0;
    if(&ind_var=29) then &dummy_prefix.29=1;        else &dummy_prefix.29=0;
    if(&ind_var=30) then &dummy_prefix.30=1;        else &dummy_prefix.30=0;
    if(&ind_var=31) then &dummy_prefix.31=1;        else &dummy_prefix.31=0;
    if(&ind_var=32) then &dummy_prefix.32=1;        else &dummy_prefix.32=0;
    if(&ind_var=33) then &dummy_prefix.33=1;        else &dummy_prefix.33=0;
    if(&ind_var=34) then &dummy_prefix.34=1;        else &dummy_prefix.34=0;
    if(&ind_var=35) then &dummy_prefix.35=1;        else &dummy_prefix.35=0;
    if(&ind_var=36) then &dummy_prefix.36=1;        else &dummy_prefix.36=0;
    if(&ind_var=37) then &dummy_prefix.37=1;        else &dummy_prefix.37=0;
    if(&ind_var=38) then &dummy_prefix.38=1;        else &dummy_prefix.38=0;
    if(&ind_var=39) then &dummy_prefix.39=1;        else &dummy_prefix.39=0;
    if(&ind_var=40) then &dummy_prefix.40=1;        else &dummy_prefix.40=0;
    if(&ind_var=41) then &dummy_prefix.41=1;        else &dummy_prefix.41=0;
    if(&ind_var=42) then &dummy_prefix.42=1;        else &dummy_prefix.42=0;
    if(&ind_var=43) then &dummy_prefix.43=1;        else &dummy_prefix.43=0;
    if(&ind_var=44) then &dummy_prefix.44=1;        else &dummy_prefix.44=0;
    if(&ind_var=45) then &dummy_prefix.45=1;        else &dummy_prefix.45=0;
    if(&ind_var=46) then &dummy_prefix.46=1;        else &dummy_prefix.46=0;
    if(&ind_var=47) then &dummy_prefix.47=1;        else &dummy_prefix.47=0;
    if(&ind_var=48) then &dummy_prefix.48=1;        else &dummy_prefix.48=0;
%END;
RUN;

%MEND;
