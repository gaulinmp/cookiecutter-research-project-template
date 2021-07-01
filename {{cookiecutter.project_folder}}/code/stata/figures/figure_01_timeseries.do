/*
This file makes Figure 1
 */

quietly {

  /* All possible paths here */
  capture cd "$((ROOTDIR))"
  /* End all possible paths */

  do "code/stata/01_load_annual_sample.do"
}

*------------------------*
*       Variables        *
*------------------------*
global depvar log_at
global timevar fyear

*------------------------*
*        Figures         *
*------------------------*

twoway (line $depvar $timevar, sort color(black) ) ///
        , yline(0) ///
        legend(off) ///
        title("Value of $depvar over time") ///
        name("time", replace)


if $writeout ///
graph export "${figure_dir}/figure_1_timeseries.png", name("time") replace

graph close *
