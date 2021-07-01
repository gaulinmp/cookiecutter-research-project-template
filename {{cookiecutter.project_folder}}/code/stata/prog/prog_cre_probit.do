// Program to estimate Correlated Random Effects Probit

capture program drop creprobit

program creprobit, eclass
    version 13
    syntax [varlist(fv ts)] [if] [in], [ ///
        reg(string) ///
        countvar(varname) ///
        groupvar(varname) ///
        ave_suffix(string) ///
        nodrop ///
        quietly ///
        debug ///
        help ///
        * ]

    if "`help'" != "" {
        display "creprobit {txt}[{inp}dep-var indep-varlist{txt}]{inp} {txt}[{inp}if{txt}] [{inp}in{txt}]{inp}, {txt}["
        display "{inp}    reg(string)        {txt}//  Regression method to run (default=probit)"
        display "{inp}    countvar(varname)  {txt}//  Add count_`countvar' to e() results for saving with esto and printing in table"
        display "{inp}    groupvar(varname)  {txt}//  Group variable for demeaning by (default=gvkey). "
        display "{inp}    ave_suffix(string) {txt}//  Suffix to add for denoting average (default=__ave)"
        display "{inp}    nodrop             {txt}//  Do not restore original dataset after estimation. Effectively keeps the *_firmave vars."
        display "{inp}    quietly            {txt}//  Suppress all output"
        display "{inp}    debug              {txt}//  Print all output"
        display "{inp}    help               {txt}//  Show this help menu"
        display "{inp}    *                  {txt}//  Any additional arguments here are passed directly to the regression."
        display "{txt}    ]"
        exit
    }

    if "`quietly'" != "" local quietly quietly
    if "`debug'" != "" {
        local quietly noisily
    }
    if "`drop'" == "" preserve

`quietly' {

    // This formats the inputs and sets up local variables.
    tokenize `varlist'
    fvunab varlist: `varlist'

    local depvar: word 1 of `varlist'
    local fvindvar: list uniq varlist
    local fvindvar: list fvindvar - depvar
    local indvar

    // Set defaults
    if "`reg'" == "" local reg probit
    if "`countvar'" == "" local countvar "`depvar'"
    if "`groupvar'" == "" local groupvar gvkey
    if "`ave_suffix'" == "" local ave_suffix "__ave"


    // Make factor variables into xi: outputted variables
    foreach v of local fvindvar {
        local dot_loc = strpos("`v'", ".")
        if (`dot_loc' == 0) {
            local indvar "`indvar' `v'"
            continue
        }

        local ipart = substr("`v'", 1, `dot_loc'-1)
        local varpart = substr("`v'", `dot_loc'+1, .)

        quietly levelsof `varpart', local(__tmp_levelsof__)

        local b_loc = strpos("`ipart'", "b")
        if (`b_loc' > 0) {
            local base_val = substr("`ipart'", `b_loc'+1, .)
        }
        else {
            local base_val: word 1 of `__tmp_levelsof__'
        }

        local __tmp_nobase__: list __tmp_levelsof__ - base_val

        if "`__tmp_levelsof__'" == "`__tmp_nobase__'" {
            noisily display "{err}ERROR analyzing factor variable (`v'), base (`base_val') not found in levelsof."
            noisily display "{err}      not found in levels (`__tmp_levelsof__')."
            error 175 // factor level out of range
        }

        // Now we have a list of levels to generate. Keep a list to add back to depvar.
        local all_newvars ""
        foreach val of local __tmp_nobase__ {
            local newvarname = substr("`varpart'", 1, 32 - strlen("_`val'") - strlen("`ave_suffix'"))
            local newvarname = "`newvarname'_`val'"

            capture drop `newvarname'
            quietly generate `newvarname' = cond(`varpart'==`val', 1, 0) if !missing(`varpart')

            local lab: variable label `varpart'
            if ("`lab'" == "") local lab "`varpart'"
            capture label variable `newvarname' "`lab' = `val'"

            local all_newvars "`all_newvars' `newvarname'"
        }

        `noisily' display "{inp}Made factor variables: {res}`all_newvars'"
        local indvar "`indvar' `all_newvars'"
    }

    `noisily' display "{inp}depvars: {res}`depvar'"
    if `"`fvindvar'"' != `"`indvar'"' ///
    `noisily' display "{inp}fv indv: {res}`fvindvar'"
    `noisily' display "{inp}indepvs: {res}`indvar'"

    // Run probit to get observations over which to calculate means
    capture drop _use_probitfe_
    `reg' `depvar' `indvar' `if'
    generate _use_probitfe_ = e(sample)
        if _rc != 0 noisily display "Error generating probit use sample for 'if' filtering!"

    // Now remove groups with one observation
    capture drop _use_probitfe_count_
    capture bysort `groupvar': egen _use_probitfe_count_ = count(`depvar') if _use_probitfe_
        if _rc noisily display "Error generating probit count variable for 'if' filtering!"
        capture replace _use_probitfe_ = 0 if _use_probitfe_count_ <= 1

    local firm_means

    // Do for continuous variables in indvar
    foreach v of local indvar {
        quietly sum `v', d
        if (r(max) - r(min) != 0) {
            `noisily' display "{inp}Making firm-average for {txt}`v'"
            // Then we're a non-constant variable
            // Add `ave_suffix' to front (making sure total name length < 32)
            local newv = substr("`v'", 1, 32 - strlen("`ave_suffix'"))
            local newv = "`newv'`ave_suffix'"

            capture drop `newv'
            capture drop _tmp_fa_var_
            capture generate _tmp_fa_var_ = `v' if _use_probitfe_
            if _rc noisily display "Error generating tmp variable for `v'"

            capture by `groupvar': egen `newv' = mean(_tmp_fa_var) if _use_probitfe_
                if _rc noisily display "Error generating firm average for `newv'"

                capture drop _tmp_fa_var_

            local firm_means "`firm_means' `newv'"
        }
    }
    local firm_means: list uniq firm_means

    `quietly' display "`reg' `depvar' ~ `indvar' + `firm_means' if _use_probitfe_, `options'"
    `quietly' `reg' `depvar' `indvar' `firm_means' if _use_probitfe_, `options'

    quietly count if e(sample) & (`countvar' > 0)
    ereturn scalar num_outcomes = r(N)

    if "`drop'" == ""  restore
    else drop _use_probitfe_count_ _use_probitfe_
}
end
