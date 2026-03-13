**********************************************************Table 1: Baseline Estimate Panel A***********************************************************
eststo clear /*clearing all the previous saved results*/
local dep_var "walk bus mrt car"
foreach z in `dep_var'{
local controls "i.age i.employ i.p2_gender i.hhtype control_trip i.car_own max_mode_w"
local fe "postal_code group_time i.region#i.group_time"
local condition `"weekday>=1&weekday<=5"' 
local cluster "postal_code"

eststo: reghdfe dummy_`z'_t8 1.Treat##1.Post `controls' if `condition', a(`fe') cluster(`cluster')
	sum dummy_`z'_t8 if e(sample)==1, meanonly
    estadd scalar mean = r(mean) 
}

local controls "i.age i.employ i.p2_gender i.hhtype control_trip i.car_own max_mode_w"
local fe "postal_code group_time i.region#i.group_time"
local condition `"weekday>=1&weekday<=5"' 
local cluster "postal_code"

eststo: reghdfe walk_transfer 1.Treat##1.Post `controls' if `condition', a(`fe') cluster(`cluster')
	sum walk_transfer if e(sample)==1, meanonly
    estadd scalar mean = r(mean) 

eststo: reghdfe bus_transfer 1.Treat##1.Post `controls' if `condition', a(`fe') cluster(`cluster')
	sum bus_transfer if e(sample)==1, meanonly
    estadd scalar mean = r(mean) 

eststo: reghdfe car_transfer 1.Treat##1.Post `controls' if `condition', a(`fe') cluster(`cluster')
	sum car_transfer if e(sample)==1, meanonly
    estadd scalar mean = r(mean) 

estout using baseline_choice.tex, replace style(tex) cells(b(star fmt(3)) se(par fmt(3)) p(fmt(3))) starlevels(\textsuperscript{*} 0.10 \textsuperscript{**} 0.05 \textsuperscript{***} 0.01) ///
keep (1.Treat 1.Post 1.Treat#1.Post) ///
stats (N r2 mean, fmt(0 2 2) label("Observations" "R2" "Mean Value of Dep.Var") ) //////
varlabels (1.Treat#1.Post "$Treat*Post$" 1.Treat "Treat" 1.Post "Post", elist(1.Treat#1.Post \hline)) ///
collabels(none) mlabels(none) eqlabels(none)


**********************************************************Table 1: Baseline Estimate Panel B***********************************************************
gen distance_mrt_walkway_m=total_cost_walkdistance

preserve	
replace ratio_walking=0 if distance_mrt_walkway_m!=.&ratio_walking==.
cap: drop Treatratio
 gen Treatratio=(ratio_walking>0.011)
 replace Treatratio=. if ratio_walking==.

eststo clear /*clearing all the previous saved results*/
local dep_var "walk bus mrt car"
foreach z in `dep_var'{
local controls "i.age i.employ i.p2_gender i.hhtype control_trip i.car_own max_mode_w"
local fe "postal_code group_time i.region#i.group_time"
local condition `"weekday>=1&weekday<=5&ratio_walking>0"' 
local cluster "postal_code"

eststo: reghdfe dummy_`z'_t8 1.Treatratio##1.Post `controls' if `condition', a(`fe') cluster(`cluster')
	sum dummy_`z'_t8 if e(sample)==1, meanonly
    estadd scalar mean = r(mean) 
}


local controls "i.age i.employ i.p2_gender i.hhtype control_trip i.car_own max_mode_w"
local fe "postal_code group_time i.region#i.group_time"
local condition `"weekday>=1&weekday<=5&ratio_walking>0"' 
local cluster "postal_code"

eststo: reghdfe walk_transfer 1.Treatratio##1.Post `controls' if `condition', a(`fe') cluster(`cluster')
	sum walk_transfer if e(sample)==1, meanonly
    estadd scalar mean = r(mean) 

eststo: reghdfe bus_transfer 1.Treatratio##1.Post `controls' if `condition', a(`fe') cluster(`cluster')
	sum bus_transfer if e(sample)==1, meanonly
    estadd scalar mean = r(mean) 

eststo: reghdfe car_transfer 1.Treatratio##1.Post `controls' if `condition', a(`fe') cluster(`cluster')
	sum car_transfer if e(sample)==1, meanonly
    estadd scalar mean = r(mean) 

estout using baseline_choice_ratio.tex, replace style(tex) cells(b(star fmt(3)) se(par fmt(3)) p(fmt(3))) starlevels(\textsuperscript{*} 0.10 \textsuperscript{**} 0.05 \textsuperscript{***} 0.01) ///
keep (1.Treatratio 1.Post 1.Treatratio#1.Post) ///
stats (N r2 mean, fmt(0 2 2) label("Observations" "R2" "Mean Value of Dep.Var") ) //////
varlabels (1.Treatratio#1.Post "$Treat*Post$" 1.Treatratio "Treat" 1.Post "Post", elist(1.Treatratio#1.Post \hline)) ///
collabels(none) mlabels(none) eqlabels(none)

restore

**********************************************************Table 2: Robustness Check Panel A***********************************************************
////collapse the individual data into building level
preserve
	   local retainlist "trip_id hhid person_id stata_date latitude longitude house_location total_cost_walkdistance Year Post Treat survey_id  time_start time_end  hour weekday region Peak total_time t8_triplegmode st14_invehtime  "
	   //change max
       local collapselist "dummy_* *_transfer age employ p2_gender hhtype time_diff_min car_own max_mode"
       collapse (firstnm) `retainlist' (mean) `collapselist', by(postal_code group_time) fast

cap: drop time_diff_min_w
winsor2 time_diff_min max_mode, cut(5 95)

cap: drop control_trip
gen control_trip=time_diff_min_w

eststo clear /*clearing all the previous saved results*/
local dep_var "walk bus mrt car"
foreach z in `dep_var'{
local controls "age employ p2_gender hhtype control_trip car_own max_mode_w"
local fe "postal_code group_time i.region#i.group_time"
local condition `"weekday>=1&weekday<=5 "' 
local cluster "postal_code"

eststo: reghdfe dummy_`z' 1.Treat##1.Post `controls' if `condition', a(`fe') cluster(`cluster')
	sum dummy_`z' if e(sample)==1, meanonly
    estadd scalar mean = r(mean) 
}

local dep_var "walk bus car"
foreach z in `dep_var'{
local controls "age employ p2_gender hhtype control_trip car_own max_mode_w"
local fe "postal_code group_time i.region#i.group_time"
local condition `"weekday>=1&weekday<=5 "' 
local cluster "postal_code"

eststo: reghdfe `z'_transfer 1.Treat##1.Post `controls' if `condition', a(`fe') cluster(`cluster')
	sum `z'_transfer if e(sample)==1, meanonly
    estadd scalar mean = r(mean) 
}

estout using baselinezip_moderatio.tex, replace style(tex) cells(b(star fmt(3)) se(par fmt(3)) p(fmt(3))) starlevels(\textsuperscript{*} 0.10 \textsuperscript{**} 0.05 \textsuperscript{***} 0.01) ///
keep (1.Treat#1.Post 1.Treat) ///
stats (N r2 mean, fmt(0 2 2) label("Observations" "R2" "Mean Value of Dep.Var") ) //////
varlabels (1.Treat "Treat" 1.Treat#1.Post "$\mathbf{Treat*Post}$", elist(1.Treat#1.Post \hline)) ///
collabels(none) mlabels("Walk" "Bus" "MRT" "Car") eqlabels(none)

restore
**********************************************************Table 2: Robustness Check Panel B***********************************************************
////merge with the data of hdb built time
merge m:1 postal_code using "G:\A_Walk2way\HITS_qx\hdb_builtyear.dta" , nogen keep(master match)

eststo clear /*clearing all the previous saved results*/
local dep_var "walk bus mrt car"
foreach z in `dep_var'{
local controls "i.age i.employ i.p2_gender i.hhtype control_trip i.car_own max_mode_w"
local fe "postal_code group_time i.region#i.group_time"
local condition `"weekday>=1&weekday<=5&lease_commence_date<2014"' 
local cluster "postal_code"

eststo: reghdfe dummy_`z'_t8 1.Treat##1.Post `controls' if `condition', a(`fe') cluster(`cluster')
	sum dummy_`z'_t8 if e(sample)==1, meanonly
    estadd scalar mean = r(mean) 
}

local controls "i.age i.employ i.p2_gender i.hhtype control_trip i.car_own max_mode_w"
local fe "postal_code group_time i.region#i.group_time"
local condition `"weekday>=1&weekday<=5&lease_commence_date<2014"' 
local cluster "postal_code"

eststo: reghdfe walk_transfer 1.Treat##1.Post `controls' if `condition', a(`fe') cluster(`cluster')
	sum walk_transfer if e(sample)==1, meanonly
    estadd scalar mean = r(mean) 

eststo: reghdfe bus_transfer 1.Treat##1.Post `controls' if `condition', a(`fe') cluster(`cluster')
	sum bus_transfer if e(sample)==1, meanonly
    estadd scalar mean = r(mean) 

eststo: reghdfe car_transfer 1.Treat##1.Post `controls' if `condition', a(`fe') cluster(`cluster')
	sum car_transfer if e(sample)==1, meanonly
    estadd scalar mean = r(mean) 

estout using baseline_hdb.tex, replace style(tex) cells(b(star fmt(3)) se(par fmt(3)) p(fmt(3))) starlevels(\textsuperscript{*} 0.10 \textsuperscript{**} 0.05 \textsuperscript{***} 0.01) ///
keep (1.Treat 1.Post 1.Treat#1.Post) ///
stats (N r2 mean, fmt(0 2 2) label("Observations" "R2" "Mean Value of Dep.Var") ) //////
varlabels (1.Treat#1.Post "$Treat*Post$" 1.Treat "Treat" 1.Post "Post", elist(1.Treat#1.Post \hline)) ///
collabels(none) mlabels(none) eqlabels(none)

