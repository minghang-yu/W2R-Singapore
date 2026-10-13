// Sheletered walkway and travel behavior
// HITS-based analysis
// Supplementary Tables and Figures
// Last edited: 11/10/2026

******************************************************************
**********  Table S3: Summary Statistics on Main Modes  **********
******************************************************************

local dep_var "walk"
foreach z in `dep_var'{
local controls "i.age i.employ i.p2_gender i.hhtype control_trip i.car_own max_mode_w"
local fe "postal_code group_time i.region#i.group_time"
local condition `"weekday>=1&weekday<=5"'
local cluster "postal_code"

eststo: reghdfe dummy_`z'_t8 1.Treat##1.Post `controls' if `condition', a(`fe') cluster(`cluster')
	sum dummy_`z'_t8 if e(sample)==1, meanonly
    estadd scalar mean = r(mean)
}

cap: drop sample_main
gen sample_main=e(sample)
eststo clear
local vars age_* employ_* hhtype_* female control_trip car_own max_mode ///
           dummy_walk_t8 dummy_bus_t8 dummy_mrt_t8 dummy_car_t8
* All treatment
eststo treat_all: estpost summarize `vars' ///
    if Treat==1 & sample_main==1, detail
* Phase 1
eststo treat1: estpost summarize `vars' ///
    if Treat_phase==1 & sample_main==1, detail
* Phase 2
eststo treat2: estpost summarize `vars' ///
    if Treat_phase==2 & sample_main==1, detail
* Control
eststo control: estpost summarize `vars' ///
    if Treat==0 & sample_main==1, detail

esttab treat_all treat1 treat2 control using main_summstats_phase.tex, replace ///
    label ///
    cells("mean(fmt(2))") ///
    mgroups("Treatment" "Control", ///
        pattern(1 0 0 1) ///
        span ///
        prefix(\multicolumn{@span}{c}{) suffix(}) ///
        erepeat(\cmidrule(lr){@span})) ///
    mlabels("All" "Phase 1" "Phase 2" "All") ///
    collabels(none) ///
    nonumber noobs ///
    stats(N, fmt(0) labels("Observations"))

************************************************************************
**********  Table S4: Summary Statistics on First-mile Modes  **********
************************************************************************

local controls "i.age i.employ i.p2_gender i.hhtype control_trip i.car_own max_mode_w"
local fe "postal_code group_time i.region#i.group_time"
local condition `"weekday>=1&weekday<=5"'
local cluster "postal_code"

eststo: reghdfe walk_transfer 1.Treat##1.Post `controls' if `condition', a(`fe') cluster(`cluster')
	sum walk_transfer if e(sample)==1, meanonly
    estadd scalar mean = r(mean)

cap: drop sample_main
gen sample_main=e(sample)
eststo clear

quietly tab age,     gen(age_)       // age_1 age_2 ...
quietly tab employ,  gen(employ_)    // employ_1 employ_2 ...
quietly tab hhtype,  gen(hhtype_)    // hhtype_1 hhtype_2 ...
gen byte female = (p2_gender==2) if !missing(p2_gender)

local vars age_* employ_* hhtype_* female control_trip car_own max_mode ///
           walk_transfer bus_transfer car_transfer
* All treatment
eststo treat_all: estpost summarize `vars' ///
    if Treat==1 & sample_main==1, detail
* Phase 1
eststo treat1: estpost summarize `vars' ///
    if Treat_phase==1 & sample_main==1, detail
* Phase 2
eststo treat2: estpost summarize `vars' ///
    if Treat_phase==2 & sample_main==1, detail
* Control
eststo control: estpost summarize `vars' ///
    if Treat==0 & sample_main==1, detail

esttab treat_all treat1 treat2 control using first_summstats_phase.tex, replace ///
    label ///
    cells("mean(fmt(2))") ///
    mgroups("Treatment" "Control", ///
        pattern(1 0 0 1) ///
        span ///
        prefix(\multicolumn{@span}{c}{) suffix(}) ///
        erepeat(\cmidrule(lr){@span})) ///
    mlabels("All" "Phase 1" "Phase 2" "All") ///
    collabels(none) ///
    nonumber noobs ///
    stats(N, fmt(0) labels("Observations"))

gen Treat_phase=0
replace Treat_phase=1 if Treat==1&phase_mrt==0
replace Treat_phase=2 if Treat==1&phase_mrt==1

cap: drop post_sector
gen post_sector = substr(string(postal_code), 1, 4)
destring post_sector, replace

eststo clear /*clearing all the previous saved results*/

local controls "i.age i.employ i.p2_gender ib(5).hhtype control_trip i.car_own max_mode_w"
local fe "post_sector group_time i.region#i.group_time"
local condition `"weekday>=1&weekday<=5&Post==0"'
local cluster "postal_code"
eststo m1: reghdfe Treat_phase `controls' if `condition', a(`fe') cluster(`cluster')

coefplot m1, drop(_cons) xline(0) ///
    mlabel format(%9.3f) mlabsize(vsmall) ///
    xtitle("Coefficient") xlabel(-1(0.3)1.5, nogrid) ylabel(, nogrid labsize(vsmall)) ///
    title("") ///
    coeflabels(1.age = "Age" 1.employ = "Employed" ///
               1.p2_gender = "Gender" control_trip = "Toal Trip Time" ///
               1.car_own = "Car Ownership" max_mode_w = "Max Mode Number") scheme(white_jet)
graph export "balance_coefplot.png", replace width(2000)

eststo clear

local controls "i.age i.employ i.p2_gender ib(8).hhtype control_trip i.car_own max_mode_w"
local fe "post_sector group_time i.region#i.group_time"
local condition `"weekday>=1&weekday<=5&Post==0"'
local cluster "postal_code"

eststo m1: reghdfe Treat_phase `controls' if `condition', ///
    absorb(`fe') cluster(`cluster')

* Joint test of household type
testparm ib(8).hhtype
estadd scalar HH_p = r(p)

* Joint test of all characteristics
testparm i.age i.employ i.p2_gender ib(8).hhtype ///
         control_trip i.car_own max_mode_w
estadd scalar Joint_p = r(p)

esttab m1, ///
    stats(N r2 HH_p Joint_p, ///
    labels("Observations" "R-squared" ///
           "Joint p-value: household type" ///
           "Joint p-value: all covariates")) ///
    star(* 0.10 ** 0.05 *** 0.01)

********************************************************************************
* Summary statistics: Post - Pre changes for Treatment and Control
********************************************************************************

* Generate categorical indicators
cap drop age_*
cap drop employ_*
cap drop hhtype_*
cap drop female

quietly tab age,     gen(age_)
quietly tab employ,  gen(employ_)
quietly tab hhtype,  gen(hhtype_)

gen byte female = (p2_gender==2) if !missing(p2_gender)

local vars age_* employ_* hhtype_* female control_trip car_own max_mode ///
           walk_transfer bus_transfer car_transfer


********************************************************************************
* Calculate Post - Pre mean changes
********************************************************************************
cap: drop sample_main
gen sample_main=e(sample)

tempname memhold

postfile `memhold' str40 variable ///
    double treat_change control_change ///
    using sorting_prepost_change.dta, replace
local vars age_* employ_* hhtype_* female control_trip car_own max_mode
foreach var of varlist `vars' {

    *-------------------------*
    * Treatment group
    *-------------------------*

    quietly summarize `var' if Treat==1 & Post==0 & sample_main==1
    local treat_pre = r(mean)

    quietly summarize `var' if Treat==1 & Post==1 & sample_main==1
    local treat_post = r(mean)

    local treat_change = `treat_post' - `treat_pre'


    *-------------------------*
    * Control group
    *-------------------------*

    quietly summarize `var' if Treat==0 & Post==0 & sample_main==1
    local control_pre = r(mean)

    quietly summarize `var' if Treat==0 & Post==1 & sample_main==1
    local control_post = r(mean)

    local control_change = `control_post' - `control_pre'


    * Save results
    post `memhold' ("`var'") ///
        (`treat_change') (`control_change')
}

postclose `memhold'


preserve

use sorting_prepost_change.dta, clear

*------------------------------------------------------------*
* Drop control_trip
*------------------------------------------------------------*
drop if variable == "control_trip"

*------------------------------------------------------------*
* Create plotting position
*------------------------------------------------------------*
gen id = _n

* Slightly offset Treatment and Control
gen id_treat   = id + 0.13
gen id_control = id - 0.13


*------------------------------------------------------------*
* Create readable variable names
*------------------------------------------------------------*
gen varname = ""

* AGE
replace varname = "Age: 15-19"   if variable == "age_1"
replace varname = "Age: 20-24"   if variable == "age_2"
replace varname = "Age: 25-29"   if variable == "age_3"
replace varname = "Age: 30-34"   if variable == "age_4"
replace varname = "Age: 35-39"   if variable == "age_5"
replace varname = "Age: 40-44"   if variable == "age_6"
replace varname = "Age: 45-49"   if variable == "age_7"
replace varname = "Age: 50-54"   if variable == "age_8"
replace varname = "Age: 55-59"   if variable == "age_9"
replace varname = "Age: 6-9"     if variable == "age_10"
replace varname = "Age: 60-64"   if variable == "age_11"
replace varname = "Age: 65-69"   if variable == "age_12"
replace varname = "Age: 70-74"   if variable == "age_13"
replace varname = "Age: 75-79"   if variable == "age_14"
replace varname = "Age: 80-84"   if variable == "age_15"
replace varname = "Age: 85+"     if variable == "age_16"

* EMPLOYMENT
replace varname = "Domestic worker"       if variable == "employ_1"
replace varname = "Employed full time"    if variable == "employ_2"
replace varname = "Employed part time"    if variable == "employ_3"
replace varname = "Full-time student"      if variable == "employ_4"
replace varname = "Homemaker"              if variable == "employ_5"
replace varname = "National service"       if variable == "employ_6"
replace varname = "Non-schooling child"    if variable == "employ_7"
replace varname = "Other employment"       if variable == "employ_8"
replace varname = "Retired"                if variable == "employ_9"
replace varname = "Self-employed"          if variable == "employ_10"
replace varname = "Unemployed"             if variable == "employ_11"
replace varname = "Voluntary worker"       if variable == "employ_12"

* HOUSEHOLD TYPE
replace varname = "Attap/zinc roofed"            if variable == "hhtype_1"
replace varname = "Floor of shophouse"           if variable == "hhtype_2"
replace varname = "Government executive flat"    if variable == "hhtype_3"
replace varname = "HDB 1-room"                   if variable == "hhtype_4"
replace varname = "HDB 2-room"                   if variable == "hhtype_5"
replace varname = "HDB 3-room"                   if variable == "hhtype_6"
replace varname = "HDB 4-room"                   if variable == "hhtype_7"
replace varname = "HDB 5-room"                   if variable == "hhtype_8"
replace varname = "HDB 5-room/executive"         if variable == "hhtype_9"
replace varname = "HDB other than flat"          if variable == "hhtype_10"
replace varname = "HUDC flat"                    if variable == "hhtype_11"
replace varname = "Other public flat"             if variable == "hhtype_12"
replace varname = "Private flat/condo"            if variable == "hhtype_13"
replace varname = "Shophouse"                     if variable == "hhtype_14"

* OTHER VARIABLES
replace varname = "Female"          if variable == "female"
replace varname = "Car ownership"   if variable == "car_own"
replace varname = "Maximum mode"    if variable == "max_mode"
replace varname = "Walk transfer"   if variable == "walk_transfer"
replace varname = "Bus transfer"    if variable == "bus_transfer"
replace varname = "Car transfer"    if variable == "car_transfer"

* Fallback: keep original variable name
replace varname = variable if varname == ""


*------------------------------------------------------------*
* Explicitly construct y-axis labels
*------------------------------------------------------------*
local ylabels

forvalues i = 1/`=_N' {
    quietly levelsof varname if id == `i', local(vname) clean
    local ylabels `"`ylabels' `i' "`vname'""'
}


*------------------------------------------------------------*
* Plot
*------------------------------------------------------------*
twoway ///
    (pcspike id_treat treat_change ///
             id_control control_change, ///
        lcolor(gs12) ///
        lwidth(vthin)) ///
    ///
    (scatter id_treat treat_change, ///
        msymbol(O) ///
        msize(vsmall) ///
        mcolor(navy)) ///
    ///
    (scatter id_control control_change, ///
        msymbol(D) ///
        msize(vsmall) ///
        mcolor(maroon)), ///
    ///
    ylabel(`ylabels', ///
        angle(0) ///
        labsize(tiny) ///
        nogrid) ///
    ///
    yscale(range(0.5 `=_N + 0.5') reverse) ///
    ///
    xline(0, ///
        lcolor(gs8) ///
        lpattern(dash) ///
        lwidth(vthin)) ///
    ///
    xlabel(-0.4(0.1)0.4, ///
        labsize(small) ///
        nogrid) ///
    ///
    xtitle("Within-group Change in Mean (Post - Pre)", ///
        size(small)) ///
    ///
    ytitle("") ///
    ///
    legend( ///
        order(2 "Treatment" 3 "Control") ///
        rows(1) ///
        position(6) ///
        size(small) ///
        region(lcolor(none))) ///
    ///
    graphregion(color(white)) ///
    plotregion(color(white)) ///
    ///
    title("", ///
        size(medsmall))

graph export "sorting_prepost_change.pdf", replace

restore



use "$HITS_INPUT/Data_hdb.dta", clear
rename (latitude longitude) (lathouse lonhouse)
rename postalcode postal_code

merge m:1 postal_code  using "$HITS_INPUT/house_walkwaystraight_distinct.dta", nogen keep(master match) keepusing(distance_*)

cap: drop Treat
gen Treat=(distance_straight_walkway<=100)
gen Post=( saleyear>2014)

gen y=ln(resale_price)
encode storey_range, gen(Storey)
encode flat_type, gen(Type_flat)
gen ln_area=ln(floor_area_sqm)
encode flat_model, gen(Flat_model)
cap: drop age
gen age=2026-lease_commence_date
gen area2 = real(substr(string(postal_code), 1, 2))
gen sale_ym=ym( saleyear , salemonth )
format sale_ym %tm
keep if distance_straight_walkway!=.

eststo clear
local cluster "postal_code"
local controls "i.age i.Storey i.Type_flat i.Flat_model ln_area"
local conditions `"saleyear>=2008&saleyear<=2018"'
local absorblist "postal_code sale_ym"
eststo: reghdfe y  1.Treat##1.Post  `controls' if  `conditions', absorb(`absorblist') cluster(`cluster')
	sum resale_price if e(sample)==1,  meanonly
    estadd scalar mean = r(mean)

local absorblist "postal_code salemonth i.area2#sale_ym"
eststo: reghdfe y  1.Treat##1.Post  `controls' if  `conditions', absorb(`absorblist') cluster(`cluster')
	sum resale_price if e(sample)==1,  meanonly
    estadd scalar mean = r(mean)

estout using baseline_price_hdb.tex, replace style(tex) cells(b(star fmt(3)) se(par fmt(3)) p(fmt(3))) starlevels(\textsuperscript{*} 0.10 \textsuperscript{**} 0.05 \textsuperscript{***} 0.01) ///
keep ( 1.Treat#1.Post) ///
stats (N r2 mean, fmt(0 2 2) label("Observations" "R2" "Mean Value of Dep.Var") ) //////
varlabels (1.Treat#1.Post "Treat*Post" 1.Treat "Treat" 1.Post "Post", elist(1.Treat#1.Post \hline)) ///
collabels(none) mlabels(none) eqlabels(none)

use "$HITS_INPUT/Data_private_19962024.dta", clear
rename (latitude longitude) (lathouse lonhouse)
rename postalcode postal_code
merge m:1 postal_code  using "$HITS_INPUT/house_walkwaystraight_distinct.dta", nogen keep(master match) keepusing(distance_*)

cap: drop Treat
gen Treat=(distance_straight_walkway<=100)
gen Post=( saleyear>2014)

encode planningarea, gen(Area)
gen y=ln(transactedprice)
encode propertytype, gen(prop_type)

drop if completiondate=="Unknown"|completiondate=="-"
replace completiondate="2024" if completiondate=="Uncompleted"|completiondate=="Uncomplete"
destring completiondate, replace force
cap: drop age
gen age=2024-completiondate

encode typeofsale, gen(Type_sale)
gen ln_area=ln(areasqm)
gen Tenure=(tenure=="Freehold")
replace Tenure=. if tenure=="N.A."|tenure=="NA"
encode planningregion, gen(Region)
encode typeofarea, gen(Type_area)
gen area2 = real(substr(string(postal_code), 1, 2))
gen sale_ym=ym( saleyear , salemonth )
format sale_ym %tm
keep if distance_straight_walkway!=.

eststo clear

local cluster "postal_code"
local controls "age i.prop_type i.Type_sale ln_area i.Tenure numberofunits i.Type_area"
local conditions `"saleyear>=2008&saleyear<=2017"'

local absorblist "postal_code sale_ym"
eststo: reghdfe y  1.Treat##1.Post  `controls' if  `conditions', absorb(`absorblist') cluster(`cluster')
	sum transactedprice if e(sample)==1,  meanonly
    estadd scalar mean = r(mean)

local absorblist "postal_code sale_ym i.area2#sale_ym"
eststo: reghdfe y  1.Treat##1.Post  `controls' if  `conditions', absorb(`absorblist') cluster(`cluster')
	sum transactedprice if e(sample)==1,  meanonly
    estadd scalar mean = r(mean)

estout using baseline_price_condo.tex, replace style(tex) cells(b(star fmt(3)) se(par fmt(3)) p(fmt(3))) starlevels(\textsuperscript{*} 0.10 \textsuperscript{**} 0.05 \textsuperscript{***} 0.01) ///
keep ( 1.Treat#1.Post) ///
stats (N r2 mean, fmt(0 2 2) label("Observations" "R2" "Mean Value of Dep.Var") ) //////
varlabels (1.Treat#1.Post "Treat*Post" 1.Treat "Treat" 1.Post "Post", elist(1.Treat#1.Post \hline)) ///
collabels(none) mlabels(none) eqlabels(none)
