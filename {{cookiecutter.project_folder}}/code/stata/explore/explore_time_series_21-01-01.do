/*
This file is used to track exploratory data analysis
 */

quietly {

  /* All possible paths here */
  capture cd "$((ROOTDIR))"
  /* End all possible paths */

  do "code/stata/01_load_annual_sample.do"

}

wsum *, sort
