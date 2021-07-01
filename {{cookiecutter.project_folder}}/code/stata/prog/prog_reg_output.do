
{ // regout
capture program drop regout

program regout, nclass
	version 13
	syntax [namelist] [using], [ ///
            margins ///
            drop(string) ///
            indicate(string asis) ///
            addindicate(string asis) ///
            vif ///
            yearname(string) ///
            yearlabel(string) ///
            indname(string) ///
            indlabel(string) ///
            fename(string) ///
            felabel(string) ///
            indicatelabels(string asis) ///
            r2(string asis) ///
            r2label(string) ///
            stats(string asis) ///
            varwidth(int 30) ///
            default_args(string asis) ///
            debug ///
            help ///
            * ]
    if "`help'" != "" {
        display "regout  {txt}[{inp}namelist of esttab outputs (e.g. est1 est2){txt}]{inp} [using{txt}]{inp}, {txt}["
        display "{inp}    margins               {txt}//  Display marginal effects in output"
        display "{inp}    drop(string)          {txt}//  Drop these variables from output"
        display "{inp}    indicate(string)      {txt}//  Indicate these variables. Should have the form ''Text = variable or *variables'' "
        display "{inp}    addindicate(string)   {txt}//  Add to the default indicator set (Year/Ind/Firm FE). Should have the form ''Text = variable or *variables'' "
        display "{inp}    vif                   {txt}//  Add VIF statistics to the default indicator set. "
        display "{inp}    yearname(string)      {txt}//  Name of year variable, to be put in ''Year FE=yearname'', overridden by indicate above. Default: Year FE"
        display "{inp}    yearlabel(string)     {txt}//  Label of year variable, to be put in ''Label=yearname'', overridden by indicate above. Default: ${year_fe}"
        display "{inp}    indname(string)       {txt}//  Name of industry variable, to be put in ''Industry FE=indname'', overridden by indicate above. Default: Industry FE"
        display "{inp}    indlabel(string)      {txt}//  Label of industry variable, to be put in ''Label=indname'', overridden by indicate above. Default: ${ind_fe}"
        display "{inp}    fename(string)        {txt}//  Name of firm variable, to be put in ''Firm FE=fename'', overridden by indicate above. Default: Firm FE"
        display "{inp}    felabel(string)       {txt}//  Label of firm variable, to be put in ''Label=fename'', overridden by indicate above. Default: ${firm_fe}"
        display "{inp}    indicatelabels(string){txt}//  Labels to be used for indicating. Should have the form ''Yes'' ''No'' "
        display "{inp}    r2(string)            {txt}//  String for Rsquared. Default: r2 (should be r2_p for probits etc.)"
        display "{inp}    r2label(string)       {txt}//  String for Rsquared label. Default: R2"
        display "{inp}    stats(string)         {txt}//  List of ''stat var name'' ''statistic description'' to add at bottom of table, along with r2 and N."
        display "{inp}    default_args(string)  {txt}//  Additional esttab arguments. Default: label compress nogaps noconst"
        display "{inp}    debug                 {txt}//  Print all output"
        display "{inp}    help                  {txt}//  Show this help menu"
        display "{inp}    *                     {txt}//  Any additional arguments here are passed directly to esttab."
        display "{txt}    ]"
        exit
    }

    if "`default_args'" == "" local default_args = "label compress nogaps noconst eqlabels(none) collabels(none)"

    if `"`indicate'"' == `""' {
        if "`yearname'" == "" local yearname "${year_fe}"
        if "`yearlabel'" == "" local yearlabel "Year FE"
        if "`indname'" == "" local indname "${ind_fe}"
        if "`indlabel'" == "" local indlabel "Industry FE"
        if "`fename'" == "" local fename "${firm_fe}"
        if "`felabel'" == "" local felabel "Firm FE"

        capture esttab `namelist', drop(*`yearname'*)
        if _rc == 0 local indicate `"`indicate' "`yearlabel' = *`yearname'* ""'
        capture esttab `namelist', drop(*`indname'*)
        if _rc == 0 local indicate `"`indicate' "`indlabel' = *`indname'* ""'
        capture esttab `namelist', drop(`fename')
        if _rc == 0 local indicate `"`indicate' "`felabel' = `fename'""'

        /* Add any additional indicators from addindicate (does nothing if it is empty) */
        local indicate `"`addindicate' `indicate'"'

    }

    if `"`indicatelabels'"' == `""' local indicatelabels "Y N"

    if "`drop'" != "" {
        local tmp_drop
        foreach v in `drop_in' {
            capture esttab `namelist', drop(`v')
            if _rc == 0 local tmp_drop `"`tmp_drop' `v'"'
        }
        local drop "drop(`tmp_drop')"
    }

    if "`r2'" == "" local r2 "r2"
    if "`r2label'" == "" & "`r2'" == "r2_p" local r2label "Pseudo R2"
    else if "`r2label'" == "" local r2label "R2"
    if "`margins'" != "" local margins `" "margins_b(fmt(${f2}))" "'

    local i = 0
    local statvars
    local statdesc
    local statfrmt
    if "`vif'" != "" local stats `"`stats' ave_vif "Average VIF" max_vif "Maximum VIF" hi_vif "Number VIF over 10""'
    /* Loop through groups of "var" "description" pairs */
    foreach v in `stats' {
      if `i' == 0 { // then it's a variable name
        local statvars = "`statvars' `v'"
      }
      else { // then it's the variable description
        local statdesc = `"`statdesc' `"`v'"'"'
        local statfrmt = `"`statfrmt' ${f3} "'
      }
      local i = 1 - `i'
    }

    local statvars = "`statvars' num_outcomes"
    local statdesc = `"`statdesc' "\# of Outcomes" "'
    local statfrmt = `"`statfrmt' ${c0} "'

    if "`debug'" != "" {
      noisily display `"esttab `namelist' `using',	 "'
      noisily display `"    cells("b(fmt(${f3}) star)" "t(par fmt(${f2}))" `margins')  "'
      noisily display `"    star(* 0.10 ** 0.05 *** 0.01)  "'
      noisily display `"    stats(`r2' N `statvars', "'
      noisily display `"            fmt(${f3} ${c0} `statfrmt')  "'
      noisily display `"            labels("`r2label'" "Observations" `statdesc'))  "'
      noisily display `"    indicate(`indicate', labels(`indicatelabels'))  "'
      noisily display `"    varwidth(`varwidth') "'
      noisily display `"    `drop' `default_args' `options' "'
    }

    esttab `namelist', ///
            cells("b(fmt(${f3}) star)" "t(par fmt(${f2}))" "`margins'") ///
            star(* 0.10 ** 0.05 *** 0.01) ///
            stats(`r2' N `statvars', ///
                  fmt(${f3} ${c0} `statfrmt') ///
                  labels("`r2label'" "Observations" `statdesc')) ///
            indicate(`indicate', labels(`indicatelabels')) ///
            varwidth(`varwidth') ///
            `drop' `default_args' `options'


    if `"`using'"' != `""' {
        if strpos(`"`using'"', "html") > 0 ///
            local post_foot `"postfoot("</table><style>tr:nth-child(even) {background-color: #f2f2f2;}</style>")"'

        esttab `namelist' `using', ///
                cells("b(fmt(${f3}) star)" "t(par fmt(${f2}))" "`margins'") ///
                star(* 0.10 ** 0.05 *** 0.01) ///
                stats(`r2' N `statvars', ///
                    fmt(${f3} ${c0} `statfrmt') ///
                    labels("`r2label'" "Observations" `statdesc')) ///
                indicate(`indicate', labels(`indicatelabels')) ///
                varwidth(`varwidth') ///
                `drop' `default_args' `options' `post_foot'
    }

end
}
// regout

{ // texout
capture program drop texout
program texout, rclass
	version 13
	syntax [namelist] [using], [ ///
            yearlabel(string) ///
            indlabel(string) ///
            felabel(string) ///
            r2label(string) ///
            default_args(string asis) ///
            debug ///
            help ///
            * ]
    if "`help'" != "" {
        display "regout {txt}[{inp}namelist of esttab outputs (e.g. est1 est2){txt}] [{inp}using{txt}]{inp}, {txt}["
        display "{inp}    yearlabel(string)     {txt}//  Label of year variable, to be put in ''Label=yearname'', overridden by indicate above. Default: ${year_fe}"
        display "{inp}    indlabel(string)      {txt}//  Label of industry variable, to be put in ''Label=indname'', overridden by indicate above. Default: ${ind_fe}"
        display "{inp}    felabel(string)       {txt}//  Label of firm variable, to be put in ''Label=fename'', overridden by indicate above. Default: ${firm_fe}"
        display "{inp}    default_args(string)  {txt}//  Additional esttab arguments, defaults to: label compress nogaps noconst"
        display "{inp}    debug                 {txt}//  Print all output"
        display "{inp}    help                  {txt}//  Show this help menu"
        display "{inp}    *                     {txt}//  Any additional arguments here are passed directly to esttab."
        display "{txt}    ]"
        exit
    }

        if "`r2label'" == "" local r2label "$ R^2 $"
        if "`yearlabel'" == "" local yearlabel "Year F.E."
        if "`indlabel'" == "" local indlabel "Industry F.E."
        if "`felabel'" == "" local felabel "Firm F.E."

        if "`default_args'" == "" local default_args = "booktabs label compress nogaps noconst nomtitles eqlabels(none) collabels(none)"

		regout `namelist' `using', ///
                r2label(`r2label') ///
                yearlabel(`yearlabel') ///
                indlabel(`indlabel') ///
                felabel(`felabel') ///
                default_args(`default_args') ///
				substitute(\_ _) `options'

end
}
// texout
