/*
Code to compile sample and output to: data/final/final_dataset.dta

Assumes this is run from 01_load_sample.do, which loads the globals and sets the right paths.
*/


/*
██╗      ██████╗  █████╗ ██████╗     ██████╗  █████╗ ████████╗ █████╗
██║     ██╔═══██╗██╔══██╗██╔══██╗    ██╔══██╗██╔══██╗╚══██╔══╝██╔══██╗
██║     ██║   ██║███████║██║  ██║    ██║  ██║███████║   ██║   ███████║
██║     ██║   ██║██╔══██║██║  ██║    ██║  ██║██╔══██║   ██║   ██╔══██║
███████╗╚██████╔╝██║  ██║██████╔╝    ██████╔╝██║  ██║   ██║   ██║  ██║
╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚═════╝     ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝

Load dataset to start from.
*/
/* INPUT: Data/interim/annual_dataset.dta */
use "${data_dir}/interim/annual_dataset.dta", clear


duplicates report gvkey datadate
if r(unique_value) != r(N) {
    noisily display _n "{err}ERROR: gvkey-datadate is not a unique key. {res}DUPLICATES FOUND!"
    exit
}

/*
███╗   ███╗███████╗██████╗  ██████╗ ███████╗███████╗
████╗ ████║██╔════╝██╔══██╗██╔════╝ ██╔════╝██╔════╝
██╔████╔██║█████╗  ██████╔╝██║  ███╗█████╗  ███████╗
██║╚██╔╝██║██╔══╝  ██╔══██╗██║   ██║██╔══╝  ╚════██║
██║ ╚═╝ ██║███████╗██║  ██║╚██████╔╝███████╗███████║
╚═╝     ╚═╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚══════╝
Merge in any other datasets.
*/
// merge m:1 fyear using "${data_dir}/interim/yearly_gdp_data.dta", nogenerate force keep(match master)

/*
███████╗██╗██╗  ████████╗███████╗██████╗ ███████╗
██╔════╝██║██║  ╚══██╔══╝██╔════╝██╔══██╗██╔════╝
█████╗  ██║██║     ██║   █████╗  ██████╔╝███████╗
██╔══╝  ██║██║     ██║   ██╔══╝  ██╔══██╗╚════██║
██║     ██║███████╗██║   ███████╗██║  ██║███████║
╚═╝     ╚═╝╚══════╝╚═╝   ╚══════╝╚═╝  ╚═╝╚══════╝
*/

/* Drop Financial and Utilities */
// 	drop if (($sic>3999) & ($sic<4600))
// 	drop if (($sic>5999) & ($sic<6500))

/* Drop if missing key variables */
// drop if missing(filedate)

/*
██╗   ██╗ █████╗ ██████╗ ██╗ █████╗ ██████╗ ██╗     ███████╗███████╗
██║   ██║██╔══██╗██╔══██╗██║██╔══██╗██╔══██╗██║     ██╔════╝██╔════╝
██║   ██║███████║██████╔╝██║███████║██████╔╝██║     █████╗  ███████╗
╚██╗ ██╔╝██╔══██║██╔══██╗██║██╔══██║██╔══██╗██║     ██╔══╝  ╚════██║
 ╚████╔╝ ██║  ██║██║  ██║██║██║  ██║██████╔╝███████╗███████╗███████║
  ╚═══╝  ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═╝╚═════╝ ╚══════╝╚══════╝╚══════╝

* Make and clean up variables.
*/
sort gvkey fyear
xtset gvkey fyear

/* Create FF12 industries, based on SIC we use (global variable $sic)
      If you don't have the command: help ffind */
capture drop ff12* ff48*
ffind $sic, newvar(ff12) type(12)



/*
██╗    ██╗██████╗ ██╗████████╗███████╗     ██████╗ ██╗   ██╗████████╗
██║    ██║██╔══██╗██║╚══██╔══╝██╔════╝    ██╔═══██╗██║   ██║╚══██╔══╝
██║ █╗ ██║██████╔╝██║   ██║   █████╗      ██║   ██║██║   ██║   ██║
██║███╗██║██╔══██╗██║   ██║   ██╔══╝      ██║   ██║██║   ██║   ██║
╚███╔███╔╝██║  ██║██║   ██║   ███████╗    ╚██████╔╝╚██████╔╝   ██║
 ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝   ╚═╝   ╚══════╝     ╚═════╝  ╚═════╝    ╚═╝
*/

winsorize_all * // or just a subset of variables to winsorize

/* OUTPUT: data/final/final_dataset.dta */
save "${data_dir}/final/final_dataset.dta", replace
