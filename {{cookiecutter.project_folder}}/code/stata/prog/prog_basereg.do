capture program drop basereg

program basereg, eclass
  version 13

  // _on_colon_parse splits the command by the : char,
  // saving the two halves into s(before) and s(after)
  capt _on_colon_parse `0'

  // If there is an errorr (_rc != 0), no : was found, so print or clear then exit
  if _rc {
      // command syntax is basereg print|clear, [options]
      syntax anything, [*]

      if strpos(`"`1'"', `"print"') > 0 {
          noisily regout, `options'
      }
      if strpos(`"`1'"', `"clear"') > 0 {
          eststo clear
      }
      if strpos(`"`1'"', `"help"') > 0 {
        display "{txt}There are two ways to call basereg." _n
        display "{txt}First, is without a colon: "
        display "{inp}basereg print, {txt}[{inp}options{txt}]  // convenience function for {res}regout, [options]"
        display "{inp}basereg clear             {txt}// convenience function for eststo clear"
        display "{inp}basereg help              {txt}// print this help function" _n
        display "{txt}The second way is with a colon, as {inp}basereg: reg depvar indepvar, [options]"
        display "{inp}basereg: reg varlist(ts fv) {txt}[{inp}if{txt}] [{inp}in{txt}]{inp}, {txt}[ // optional arguments:"
        display "{inp}    cluster(varname)      {txt}// Cluster dimension, defaults to gvkey."
        display "{inp}    margins(string asis)  {txt}// Variables to calculate margins for"
        display "{inp}    vif                   {txt}// Calculate Variance Inflation factors"
        display "{inp}    SUMmarize             {txt}// Also print summary stats of dep- and indep- vars"
        display "{inp}    nosave                {txt}// Do not save the output in eststo"
        display "{inp}    NOPRINTsteps          {txt}// Do not print out info information (fully quiet)"
        display "{inp}    debug                 {txt}// Print out debug information"
        display "{inp}    *                     {txt}//  Any additional arguments here are passed directly to `reg'."
        display "{txt}    ]"
      }

    exit
  }
  else {
      // If there is no error, that means a : was found, so set 0 macro
      // (which is the full command) equal to what is after the colon
      local precommand `"`s(before)'"'
      local 0 `"`s(after)'"'
  }

  // the reg function to run is the first 'word'
  local reg: word 1 of `0'

  // The rest is whatever is left after the first space following the reg function
  // Remember to strip the spaces on the left side of the command, or
  //    strpos will find that first space at the beginning
  local 0=ltrim(`"`0'"')
  local 0=substr(`"`0'"', strpos(`"`0'"', " "), .)

  // We have cleaned up `0', so now parse its syntax. I can't believe this works.
  syntax varlist(min=1 ts fv) [if] [in], [ ///
        cluster(varname)     /// Cluster dimension, defaults to gvkey.
        margins(string asis) /// Variables to calculate margins for
        vif                  /// Calculate Variance Inflation factors
        SUMmarize            /// Also print summary stats of dep- and indep- vars
        nosave               /// Do not save the output in eststo
        NOPRINTsteps         /// Do not print out info information
        debug                /// Print out debug information
        * ]

  local noisily quietly
  if "`debug'" != "" local noisily noisily
  if "`printsteps'" == "" local infout noisily

  `noisily' {

    // This formats the inputs and sets up local variables.
    tokenize `varlist'


    // Extract variables from the argument.
    local depvar `1'
    macro shift

    local indvar `*'
    fvunab indvar : `indvar'
    local indvar: list uniq indvar

    if "`summarize'" != "" {
        `infout' wsum `depvar' `indvar'
    }

    quietly sum `depvar'
    local count_val = 1
    if r(max) - r(min) == 1 {
        local countvar "`depvar'"
        local count_val = r(max)
    }

    // Set default cluster variable to $cluster_var global variable
    if `"`cluster'"' == `""' local cluster "${cluster_var}"

    display `"{txt}Will run: {inp}`reg' `depvar' `indvar' `if' `in', cluster(`cluster') `options' "'

    // Calculate VIF and put them in the table output
    if "`vif'" != "" { // non-empty means vif was specified
      `infout' display `"{txt}Running VIFs: {inp}regress `depvar' `indvar' `if' `in', cluster(`cluster')"'
      regress `depvar' `indvar' `if' `in', cluster(`cluster')
      estat vif
      local ave_vif = 0
      local max_vif = 0
      local hi_vif = 0
      forvalues vn = 1/`=e(rank)-1'{
        if (strpos("`=r(name_`vn')'", "$year_fe") > 0) | (strpos("`=r(name_`vn')'", "$ind_fe") > 0) {
            continue
        }
        `infout' display "{txt}VIF of: `=r(name_`vn')' == {res}" %6.2f r(vif_`vn')
        local ave_vif = `ave_vif' + r(vif_`vn')
        if r(vif_`vn') > `max_vif' local max_vif = r(vif_`vn')
        if r(vif_`vn') > 10 local hi_vif = `hi_vif' + 1
      }
      local ave_vif = `ave_vif'/(e(rank)-1)
    }

    // This is the main regression. Everything else is for formatting.
    `infout' display `"{txt}Running regr: {inp}`reg' `depvar' `indvar' `if' `in', cluster(`cluster') `options'"'
    `infout' `reg' `depvar' `indvar' `if' `in', cluster(`cluster')  `options'

    // This adds all those VIF stats from above
    if "`vif'" != "" {
        ereturn scalar ave_vif=`ave_vif'
        ereturn scalar max_vif=`max_vif'
        ereturn scalar hi_vif=`hi_vif'
    }

    if "`countvar'" != "" {
        quietly count if (e(sample)==1) & (`countvar' == `count_val')
        ereturn scalar num_outcomes = r(N)
    }

    if "`save'" == "" {
      // This calculates the margins, and stores them in an esttab output.
      if "`margins'" != "" {
        `infout' display `"{txt}Running marg: {inp}estadd margins, dydx(`margins')"'
        estadd margins, dydx(`margins')
      }
      eststo
    }

    if "`vif'" != "" {
      `noisily' display "Average VIF: `ave_vif'"
      `noisily' display "Maximum VIF: `max_vif'"
      `noisily' display "# >= 10 VIF: `hi_vif'"
    }

  } // end `noisily'
end
