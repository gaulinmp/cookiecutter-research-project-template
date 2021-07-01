/* -*- coding: utf-8 -*- */

// wcorr program
capture program drop wcorr
program wcorr, rclass
    version 12
    syntax varlist(min=1 max=99 fv ts) [using] [if] [in], ///
            [ /// // options
            sort /// // Sort variables by name
            spearman /// // Display spearman correlations
            format(string asis) /// // Format for stats in table
            modelwidth(int 6) /// // Width of the models in STATA output
            label /// // Use variable labels or variable names?
            debug /// // output debug information
            * ]

    local noisily quietly
    if "`debug'" != "" local noisily noisily

    /* Format the inputs and sets up local variables. */
    tokenize varlist
    fvunab varlist: `varlist'
    local varlist: list uniq varlist

    if "`sort'" != "" local varlist: list sort varlist

    if `"`statslabels'"' == `""' local statslabels `"`stats'"'

    if `"`format'"'==`""' {
        local format "%-5.2f"
        local mwidth
    }

    local nvars :  word count `varlist'

    /*
    Add variables to list for re-labeling with (i) in front.
    If Spearman is requested, calculate temp vars which are the rank(var),
    because the correlation of ranks == Spearman.
    */
    local i=0
    local max_str_len = 1
    local eql
    /* This only allows for a maximum of 99 variables. Which is sane. */
    if `nvars' > 9 local space " "
    foreach v in `varlist' {
        local i = `i'+1
        /* Check if variable is valid */
        tempvar var_`i'
        if "`spearman'" != "" {
            capture egen `var_`i'' = rank(`v')
        }
        else {
            capture gen `var_`i'' = `v'
        }
        /* If _rc != 0, then we hit an error in the variable
        (probably a factor variable), so ignore it */
        if _rc {
            local i = `i'-1
            continue
        }

        /* If we're greater than 9, drop the added space in front of ( i) */
        if `i' > 9 local space ""

        /* Make new varlist with temp-variable names in it */
        local newvarlist `" `newvarlist' `var_`i'' "'

        /* Label those tem variables in estout below, using:
        "tempvarname" "(i) oldvarname" */
        if "`label'" != "" ///
            local lab: variable label `v'
        if ("`label'" == "") | ("`lab'" == "") ///
            local lab "`v'"
        local full_lab "(`space'`i') `lab'"
        local varlab `"`varlab' "`var_`i''" "`full_lab'" "'

        /* Add (i) to the equation label string along the top of the table */
        local eql `"`eql' "(`i')" "'

        /* Track the length of the longest label (and add 4 below) */
        local i_str_len = strlen("`full_lab'")
        if `i_str_len' > `max_str_len' local max_str_len `i_str_len'
    }

    if "`debug'" != "" noisily wcorr `newvarlist' `if' `in'

    /* Do corr */
    `noisily' display `"estpost correlate `newvarlist' `if' `in', matrix listwise "'

    /* Run correlation matrix */
    capture estpost correlate `newvarlist' `if' `in', matrix listwise
    if _rc {
        `noisily' display `"xi: estpost correlate `newvarlist' `if' `in', matrix listwise"'
        xi: estpost correlate `newvarlist' `if' `in', matrix listwise
    }

    /* Output results */
    `noisily' display `"esttab, unstack not nonumbers nomtitle noobs compress /// "'
    `noisily' display `"        cells(b(fmt(`format') star)) /// "'
    `noisily' display `"        star(* 0.01) /// "'
    `noisily' display `"        eqlabels(`eql') /// "'
    `noisily' display `"        collabels(none) /// "'
    `noisily' display `"        varwidth(`max_str_len') /// "'
    `noisily' display `"        modelwidth(`modelwidth') /// "'
    `noisily' display `"        varlabels(`varlab') /// "'
    `noisily' display `"        substitute(`sub') `options' "'

    esttab ., unstack not nonumbers nomtitle noobs compress ///
            cells(b(fmt(`format') star)) ///
            star(* 0.01) ///
            eqlabels(`eql') ///
            collabels(none) ///
            varwidth(`max_str_len') ///
            modelwidth(`modelwidth') ///
            varlabels(`varlab') `options'

    if `"`using'"' != `""' {
        if strpos(`"`using'"', "html") > 0 ///
            local post_foot_html `"postfoot("</table><style>tr:nth-child(even) {background-color: #f2f2f2;}</style>")"'

        esttab . `using', ///
                unstack not nonumbers nomtitle noobs compress nogaps ///
                cells(b(fmt(`format') star)) ///
                star(* 0.01) ///
                eqlabels(`eql') ///
                collabels(none) ///
                varwidth(`max_str_len') ///
                modelwidth(`modelwidth') ///
                varlabels(`varlab') `options' `post_foot_html'
    }
end
// end wcorr program
