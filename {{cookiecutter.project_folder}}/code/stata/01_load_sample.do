
quietly {
clear all
set more off

/* All possible paths here */
capture cd "$((ROOTDIR))"
/* End all possible paths */


/* Load global variables */
do code/stata/00_global_variables.do


noisily display "DATA_DIR: ${data_dir}"
noisily display "CODE_DIR: ${code_dir}"
noisily display "Writing: ${writeout}"

do "${code_dir}/prog/winsorize_all.ado"
do "${code_dir}/prog/ffind.ado"
do "${code_dir}/prog/prog_basereg"
do "${code_dir}/prog/prog_reg_output"
do "${code_dir}/prog/prog_cre_probit"
do "${code_dir}/prog/wsum.ado"
do "${code_dir}/prog/wcorr.ado"


/* INPUT: data/final/final_dataset.dta */
capture use "${data_dir}/final/final_dataset.dta", clear

/* Regenerate data if the global variable from 00_global_variables.do above tells us to. */
if $regenerate_data | _rc {
    do "${code_dir}/data/01.1_make_sample.do"
}

} // end quietly
