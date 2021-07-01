net install st0085_2.pkg // esttab
ssc install parmest // for rolling regression hack
net install xtqreg.pkg


/* One day, I will write a program to get current do file's path, using something like:

tempfile results_content

translate @Results `results_content'

file open myfile using `results_content', read
file read myfile line

while r(eof)==0 {
    // Look for "do [.....].do"
	display "`=word("`line'",1)'"
	file read myfile line
}

file close myfile
 */
