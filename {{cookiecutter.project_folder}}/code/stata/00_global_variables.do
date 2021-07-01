quietly {
noisily display "Setting Global Variables..."


/*
██╗   ██╗ █████╗ ██████╗ ██╗ █████╗ ██████╗ ██╗     ███████╗███████╗
██║   ██║██╔══██╗██╔══██╗██║██╔══██╗██╔══██╗██║     ██╔════╝██╔════╝
██║   ██║███████║██████╔╝██║███████║██████╔╝██║     █████╗  ███████╗
╚██╗ ██╔╝██╔══██║██╔══██╗██║██╔══██║██╔══██╗██║     ██╔══╝  ╚════██║
 ╚████╔╝ ██║  ██║██║  ██║██║██║  ██║██████╔╝███████╗███████╗███████║
  ╚═══╝  ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═╝╚═════╝ ╚══════╝╚══════╝╚══════╝
*/
global cluster_var gvkey
global sic sic           // sic_comp OR sic_comphist OR sic_10
global ind_fe gics_group // or ff12
global year_fe fyear


/*
 ██████╗ ██╗   ██╗████████╗██████╗ ██╗   ██╗████████╗
██╔═══██╗██║   ██║╚══██╔══╝██╔══██╗██║   ██║╚══██╔══╝
██║   ██║██║   ██║   ██║   ██████╔╝██║   ██║   ██║
██║   ██║██║   ██║   ██║   ██╔═══╝ ██║   ██║   ██║
╚██████╔╝╚██████╔╝   ██║   ██║     ╚██████╔╝   ██║
 ╚═════╝  ╚═════╝    ╚═╝   ╚═╝      ╚═════╝    ╚═╝
 */
/* Dataset variables */
global regenerate_data 0
global save_dataset 1


/* Write results output to disc */
global writeout 1


/* Suppress output (set blank for full output) */
global quietly quietly

/* Code and data directories (no trailing slashes) */
global data_dir "data"
global code_dir "code/stata"




/* Output tables to file (no trailing slashes) */
global output_dir "output"
global table_dir "${output_dir}/tables"
global figure_dir "${output_dir}/figures"

/* For overleaf */
global latex_output_dir "~/Dropbox/Apps/Overleaf/{{ cookiecutter.project_folder }}"
global latex_table_dir "${latex_output_dir}/tables"
global latex_figure_dir "${latex_output_dir}/figures"


/* Formatting things. */
global f3 "%4.3f"
global f2 "%4.2f"
global c0 "%10.0gc"
global html_foot `"postfoot("</table><style>tr:nth-child(even) {background-color: #f2f2f2;}</style>")"'

}
