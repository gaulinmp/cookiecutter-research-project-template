
capture program drop winsorize_all

program winsorize_all, rclass
	version 10
	syntax varlist [if] [in], [ low(integer 1) high(integer 99) nocompress force(varlist) omit(varlist) debug ]

  if "`debug'" == "" local quietly quietly

  if "`compress'" == "" compress

  local varlist: list uniq varlist

  if `"`force'"' != `""' {
    fvunab force: `force'
    local force: list uniq force
  }
  if `"`omit'"' != `""' {
    fvunab omit: `omit'
    local omit: list uniq omit
  }
  if `"`if'"' == `""' local if if 1

  foreach v of local varlist {
    if (("`: type `v''" == "float") | ("`: type `v''" == "double") | (`: list v in force')) & !(`: list v in omit') {
      `quietly' _pctile `v' `if' `in', p(`low' `high')
      local p_low=r(r1)
      local p_high=r(r2)
      `quietly' sum `v' `if' `in', detail
      local p_min=r(min)
      local p_max=r(max)
      `quietly' display "`p_min' -- `p_low' --- `p_high' -- `p_max'"

      if (`p_low' == `p_high') {
        display "{txt}`v' (`: type `v'') is NOT winsorized but `low'% == `high'% == " `p_low'
      }
      else if ((`p_max' != `p_high') | (`p_min' != `p_low')) {
        display "{err}`v' not winsorized:", _continue
        if (`p_min' != `p_low') {
          display "{err} (" `p_min' "!=" `p_low' ")", _continue
          /* `quietly' replace `v' = max(`v', r(r10)) `if' & !missing(`v') */
        }
        if (`p_max' != `p_high') {
          display "{err} (" `p_max' "!=" `p_high' ")", _continue
          /* `quietly' replace `v' = min(`v', r(r990)) `if' & !missing(`v') */
        }
        display // end line from above
        `quietly' replace `v' = max(min(`v', `p_high'), `p_low') `if' & !missing(`v')
        /* winsor2 `v' `if' `in', replace cuts(1 99) */
      }
      else {
        display "{txt}`v' (`: type `v'') is winsorized"
      }
    }
    else {
      display "{res}Skipping `v' (`: type `v'')"
    }
  }

end
