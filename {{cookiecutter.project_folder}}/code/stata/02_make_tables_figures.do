quietly {

  /* All possible paths here */
  capture cd "$((ROOTDIR))"
  /* End all possible paths */

  do "code/stata/01_load_annual_sample.do"

  /* remember to set writeout=1 in the globals file. */

  noisily display "Destination: ${table_dir}/"
  noisily display "Data Dir: ${data_dir}/"
  noisily display "Year FE: ${year_fe}"
  noisily display "Industry FE: ${ind_fe}"
  noisily display "Firm Cluster: ${cluster_var}"

  noisily do "${code_dir}/tables/table_01_summary_stats"

  noisily do "${code_dir}/figures/figure_01_timeseries"

}
