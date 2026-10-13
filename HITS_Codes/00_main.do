// Sheletered walkway and travel behavior
// HITS-based analysis
// General setup
// Last edited: 11/10/2026

args project_root_arg
local project_root = subinstr(`"`project_root_arg'"', "\", "/", .)
global HITS_CODE `"`project_root'/HITS_Codes"'
global HITS_INPUT `"`project_root'/Data/Restricted Inputs"'

use "$HITS_INPUT/HITS_combine_three.dta", clear
capture drop latitude longitude

merge m:1 postal_code using "$HITS_INPUT/postal_latlon.dta", nogen keep(master match)
gen house_location = string(latitude) + "," + string(longitude)

* Process the HITS analysis data.
do "$HITS_CODE/01_process_data.do"

* Create main-text tables.
do "$HITS_CODE/02_main_table.do"

* Create main-text figures.
do "$HITS_CODE/03_main_figure.do"

* Create supplementary tables and figures.
do "$HITS_CODE/04_supple_infor.do"
