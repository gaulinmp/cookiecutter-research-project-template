/*
This file makes Table 1: Summary Stats
 */

quietly {

  /* All possible paths here */
  capture cd "$((ROOTDIR))"
  /* End all possible paths */

  do "code/stata/01_load_annual_sample.do"
}

$quietly { // quietly global defined in 00_global_variables.do

    *------------------------*
    *       Variables        *
    *------------------------*
    global all log_at

    *------------------------*
    *       Statistics       *
    *------------------------*
    eststo clear

    if $writeout {
        /* OUTPUT: output/tables/table_1_summary_stats.html */
        wsum $all using "${table_dir}/table_1_summary_stats.tex", replace ///
            label substitute('.0000', '')
    }
    else noisily wsum $all



    *------------------------*
    *      Correlations      *
    *------------------------*
    eststo clear

    if $writeout {
        /* OUTPUT: output/tables/table_1_correlations.tex */
        noisily wcorr $all using "${table_dir}/table_1_correlations.tex", replace ///
            label
    }
    else noisily wcorr $all

} // end $quietly
