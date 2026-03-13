************************************************Table S1: Summary Statistics on Main Modes****************************************************
eststo clear /*clearing all the previous saved results*/
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

quietly tab age,     gen(age_)       // age_1 age_2 ...
quietly tab employ,  gen(employ_)    // employ_1 employ_2 ...
quietly tab hhtype,  gen(hhtype_)    // hhtype_1 hhtype_2 ...
gen byte female = (p2_gender==2) if !missing(p2_gender)  
* Treatment group
eststo treat: estpost summarize age_* employ_* female hhtype_* control_trip car_own max_mode dummy_walk dummy_bus dummy_mrt dummy_car if Treat==1&sample_main==1, detail
* Control group
eststo control: estpost summarize age_* employ_* female hhtype_* control_trip car_own max_mode dummy_walk dummy_bus dummy_mrt dummy_car if Treat==0&sample_main==1, detail
* Difference
eststo diff: estpost ttest age_* employ_* female hhtype_* control_trip car_own max_mode dummy_walk dummy_bus dummy_mrt dummy_car, by(Treat)

esttab treat control diff using main_summstats.tex, replace label ///
   cells("mu_1(fmt(2)) mu_2(fmt(2)) b(fmt(2) star)") ///
    mlabels("Treatment" "Control" "Difference") ///
    collabels(none) nomtitle nonumber noobs ///
    unstack ///
    stats(N, fmt(0) labels("Observations")) ///
    star(* 0.10 ** 0.05 *** 0.01)
	
************************************************Table S2: Summary Statistics on First-mile Modes****************************************************
local controls "i.age i.employ i.p2_gender i.hhtype control_trip i.car_own max_mode_w"
local fe "postal_code group_time i.region#i.group_time"
local condition `"weekday>=1&weekday<=5&lease_commence_date<2014"' 
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
* Treatment group
eststo treat: estpost summarize age_* employ_*  hhtype_* female control_trip car_own max_mode walk_transfer bus_transfer car_transfer if Treat==1&sample_main==1, detail
* Control group
eststo control: estpost summarize age_* employ_*  hhtype_* female control_trip car_own max_mode walk_transfer bus_transfer car_transfer if Treat==0&sample_main==1, detail
* Difference
eststo diff: estpost ttest age_* employ_*  hhtype_* female control_trip car_own max_mode walk_transfer bus_transfer car_transfer, by(Treat)

esttab treat control diff using first_summstats2.tex, replace label ///
   cells("mu_1(fmt(2)) mu_2(fmt(2)) b(fmt(2) star)") ///
    mlabels("Treatment" "Control" "Difference") ///
    collabels(none) nomtitle nonumber noobs ///
    unstack ///
    stats(N, fmt(0) labels("Observations")) ///
    star(* 0.10 ** 0.05 *** 0.01)
	
*******************************************Table S6: Heterogeneity by Temperature*************************************************
cap: drop temperature
gen temperature=visib

cap: drop Treat_temp_*

	gen Treat_temp_1=1 if Treat==1&temperature>24.2&temperature<=24.6
    replace Treat_temp_1=0 if Treat_temp_1==.

	gen Treat_temp_2=1 if Treat==1&temperature>24.6&temperature<=25.4
    replace Treat_temp_2=0 if Treat_temp_2==.

	gen Treat_temp_3=1 if Treat==1&temperature>25.4
    replace Treat_temp_3=0 if Treat_temp_3==.

eststo clear /*clearing all the previous saved results*/
local dep_var "walk bus mrt car"
foreach z in `dep_var'{
local controls "i.age i.employ i.p2_gender i.hhtype control_trip i.car_own max_mode_w"
local fe "postal_code group_time i.region#i.group_time"
local condition `"weekday>=1&weekday<=5&temperature!=."' 
local cluster "postal_code"

eststo: reghdfe dummy_`z'_t8 1.Treat_temp_*##1.Post `controls' if `condition', a(`fe') cluster(`cluster')
	sum dummy_`z'_t8 if e(sample)==1, meanonly
    estadd scalar mean = r(mean) 
parmest, format (estimate min95 max95 %8.2f p %8.3f) saving(Dummytemp_`z'.dta, replace)

}

local dep_var "walk bus car"
foreach z in `dep_var'{
local controls "i.age i.employ i.p2_gender i.hhtype control_trip i.car_own max_mode_w"
local fe "postal_code group_time i.region#i.group_time"
local condition `"weekday>=1&weekday<=5&temperature!=."' 
local cluster "postal_code"

eststo: reghdfe `z'_transfer 1.Treat_temp_*##1.Post `controls' if `condition', a(`fe') cluster(`cluster')
	sum `z'_transfer if e(sample)==1, meanonly
    estadd scalar mean = r(mean) 
parmest, format (estimate min95 max95 %8.2f p %8.3f) saving(Transfertemp_`z'.dta, replace)

}

estout using hete_temp.tex, replace style(tex) cells(b(star fmt(3))  se(label("Standard Error") par fmt(3)) p(label("P value" ) fmt(3))) starlevels(\textsuperscript{*} 0.10 \textsuperscript{**} 0.05 \textsuperscript{***} 0.01) ///
keep (1.Treat_* 1.Post 1.Treat_*#1.Post) ///
stats (N r2 mean, fmt(0 2 2) label("Observations" "R2" "Mean Value of Dep.Var") ) //////
varlabels (1.Treat_temp_1#1.Post "Low-temperature*Post" 1.Treat_temp_1 "Low-temperature" 1.Treat_temp_2#1.Post "Medium-temperature*Post" 1.Treat_temp_2 "Medium-temperature" 1.Treat_temp_3#1.Post "High-temperature*Post" 1.Treat_temp_3 "High-temperature" 1.Post "Post" , elist(1.Treat#1.Post \hline)) ///
collabels(none) mlabels(none) eqlabels(none)

*******************************************Table S7: Subsample Analysis by Rainfall*************************************************
preserve
replace ratio_walking=0 if distance_mrt_walkway_m!=.&ratio_walking==.
winsor2 ratio_walking, cuts(5 95) 
cap: drop inter_test
gen inter_test=ratio_walking_w
////standardization
center inter_test, prefix(z_) standardize
////Panel A
eststo clear /*clearing all the previous saved results*/
local dep_var "walk bus mrt car"
foreach z in `dep_var'{
local controls "i.age i.employ i.p2_gender i.hhtype control_trip i.car_own max_mode_w"
local fe "postal_code group_time i.region#i.group_time"
local condition `"weekday>=1&weekday<=5 "' 
local cluster "postal_code"

eststo: reghdfe dummy_`z'_t8 1.Treat##1.Post##c.z_inter_test `controls' if `condition'&prcp<=0.2, a(`fe') cluster(`cluster')
	sum dummy_`z'_t8 if e(sample)==1, meanonly
    estadd scalar mean = r(mean) 

}

local dep_var "walk bus car"
foreach z in `dep_var'{
local controls "i.age i.employ i.p2_gender i.hhtype control_trip i.car_own max_mode_w"
local fe "postal_code group_time i.region#i.group_time"
local condition `"weekday>=1&weekday<=5&hhtype!=12"' 
local cluster "postal_code"

eststo:  reghdfe `z'_transfer 1.Treat##1.Post##c.z_inter_test `controls' if `condition'&prcp<=0.2, a(`fe') cluster(`cluster')
	sum `z'_transfer if e(sample)==1, meanonly
    estadd scalar mean = r(mean) 

}
estout using hete_dry.tex, replace style(tex) cells(b(star fmt(3)) se(par fmt(3)) p(fmt(3))) starlevels(\textsuperscript{*} 0.10 \textsuperscript{**} 0.05 \textsuperscript{***} 0.01) ///
keep (1.Treat 1.Post 1.Treat#1.Post 1.Treat#1.Post#c.z_inter_test) ///
stats (N r2 mean, fmt(0 2 2) label("Observations" "R2" "Mean Value of Dep.Var") ) //////
varlabels (1.Treat#1.Post "Treat*Post" 1.Treat "Treat" 1.Post "Post" 1.Treat#1.Post#c.z_inter_test "Treat*Post*Coverage", elist(1.Treat#1.Post#c.z_inter_test \hline)) ///
collabels(none) mlabels(none) eqlabels(none)

////Panel B
eststo clear /*clearing all the previous saved results*/
local dep_var "walk bus mrt car"
foreach z in `dep_var'{
local controls "i.age i.employ i.p2_gender i.hhtype control_trip i.car_own max_mode_w"
local fe "postal_code group_time i.region#i.group_time"
local condition `"weekday>=1&weekday<=5 "' 
local cluster "postal_code"

eststo: reghdfe dummy_`z'_t8 1.Treat##1.Post##c.z_inter_test `controls' if `condition'&prcp>0.2, a(`fe') cluster(`cluster')
	sum dummy_`z'_t8 if e(sample)==1, meanonly
    estadd scalar mean = r(mean) 

}

local dep_var "walk bus car"
foreach z in `dep_var'{
local controls "i.age i.employ i.p2_gender i.hhtype control_trip i.car_own max_mode_w"
local fe "postal_code group_time i.region#i.group_time"
local condition `"weekday>=1&weekday<=5&hhtype!=12"' 
local cluster "postal_code"

eststo:  reghdfe `z'_transfer 1.Treat##1.Post##c.z_inter_test `controls' if `condition'&prcp>0.2, a(`fe') cluster(`cluster')
	sum `z'_transfer if e(sample)==1, meanonly
    estadd scalar mean = r(mean) 

}
estout using hete_rain.tex, replace style(tex) cells(b(star fmt(3)) se(par fmt(3)) p(fmt(3))) starlevels(\textsuperscript{*} 0.10 \textsuperscript{**} 0.05 \textsuperscript{***} 0.01) ///
keep (1.Treat 1.Post 1.Treat#1.Post 1.Treat#1.Post#c.z_inter_test) ///
stats (N r2 mean, fmt(0 2 2) label("Observations" "R2" "Mean Value of Dep.Var") ) //////
varlabels (1.Treat#1.Post "Treat*Post" 1.Treat "Treat" 1.Post "Post" 1.Treat#1.Post#c.z_inter_test "Treat*Post*Coverage", elist(1.Treat#1.Post#c.z_inter_test \hline)) ///
collabels(none) mlabels(none) eqlabels(none)


restore


*******************************************Table S8: Subsample Analysis by Distance to Transit Hub*************************************************
preserve
replace ratio_walking=0 if distance_mrt_walkway_m!=.&ratio_walking==.
winsor2 ratio_walking, cuts(5 95) 
cap: drop inter_test
gen inter_test=ratio_walking_w
////standardization
center inter_test, prefix(z_) standardize
////Panel A
eststo clear /*clearing all the previous saved results*/
local dep_var "walk bus mrt car"
foreach z in `dep_var'{
local controls "i.age i.employ i.p2_gender i.hhtype control_trip i.car_own max_mode_w"
local fe "postal_code group_time i.region#i.group_time"
local condition `"weekday>=1&weekday<=5 "' 
local cluster "postal_code"

eststo: reghdfe dummy_`z'_t8 1.Treat##1.Post##c.z_inter_test `controls' if `condition'&distance_mrt_walkway_m<=1200, a(`fe') cluster(`cluster')
	sum dummy_`z'_t8 if e(sample)==1, meanonly
    estadd scalar mean = r(mean) 

}

local dep_var "walk bus car"
foreach z in `dep_var'{
local controls "i.age i.employ i.p2_gender i.hhtype control_trip i.car_own max_mode_w"
local fe "postal_code group_time i.region#i.group_time"
local condition `"weekday>=1&weekday<=5&hhtype!=12"' 
local cluster "postal_code"

eststo:  reghdfe `z'_transfer 1.Treat##1.Post##c.z_inter_test `controls' if `condition'&distance_mrt_walkway_m<=1200, a(`fe') cluster(`cluster')
	sum `z'_transfer if e(sample)==1, meanonly
    estadd scalar mean = r(mean) 

}
estout using hete_shortdist.tex, replace style(tex) cells(b(star fmt(3)) se(par fmt(3)) p(fmt(3))) starlevels(\textsuperscript{*} 0.10 \textsuperscript{**} 0.05 \textsuperscript{***} 0.01) ///
keep (1.Treat 1.Post 1.Treat#1.Post 1.Treat#1.Post#c.z_inter_test) ///
stats (N r2 mean, fmt(0 2 2) label("Observations" "R2" "Mean Value of Dep.Var") ) //////
varlabels (1.Treat#1.Post "Treat*Post" 1.Treat "Treat" 1.Post "Post" 1.Treat#1.Post#c.z_inter_test "Treat*Post*Coverage", elist(1.Treat#1.Post#c.z_inter_test \hline)) ///
collabels(none) mlabels(none) eqlabels(none)

////Panel B
eststo clear /*clearing all the previous saved results*/
local dep_var "walk bus mrt car"
foreach z in `dep_var'{
local controls "i.age i.employ i.p2_gender i.hhtype control_trip i.car_own max_mode_w"
local fe "postal_code group_time i.region#i.group_time"
local condition `"weekday>=1&weekday<=5 "' 
local cluster "postal_code"

eststo: reghdfe dummy_`z'_t8 1.Treat##1.Post##c.z_inter_test `controls' if `condition'&distance_mrt_walkway_m>1200, a(`fe') cluster(`cluster')
	sum dummy_`z'_t8 if e(sample)==1, meanonly
    estadd scalar mean = r(mean) 

}

local dep_var "walk bus car"
foreach z in `dep_var'{
local controls "i.age i.employ i.p2_gender i.hhtype control_trip i.car_own max_mode_w"
local fe "postal_code group_time i.region#i.group_time"
local condition `"weekday>=1&weekday<=5&hhtype!=12"' 
local cluster "postal_code"

eststo:  reghdfe `z'_transfer 1.Treat##1.Post##c.z_inter_test `controls' if `condition'&distance_mrt_walkway_m>1200, a(`fe') cluster(`cluster')
	sum `z'_transfer if e(sample)==1, meanonly
    estadd scalar mean = r(mean) 

}
estout using hete_longdist.tex, replace style(tex) cells(b(star fmt(3)) se(par fmt(3)) p(fmt(3))) starlevels(\textsuperscript{*} 0.10 \textsuperscript{**} 0.05 \textsuperscript{***} 0.01) ///
keep (1.Treat 1.Post 1.Treat#1.Post 1.Treat#1.Post#c.z_inter_test) ///
stats (N r2 mean, fmt(0 2 2) label("Observations" "R2" "Mean Value of Dep.Var") ) //////
varlabels (1.Treat#1.Post "Treat*Post" 1.Treat "Treat" 1.Post "Post" 1.Treat#1.Post#c.z_inter_test "Treat*Post*Coverage", elist(1.Treat#1.Post#c.z_inter_test \hline)) ///
collabels(none) mlabels(none) eqlabels(none)


restore


*******************************************Table S9: Subsample Analysis by Peak Types*************************************************
cap: drop dummy_peak
gen dummy_peak= (Peak!="non"&Peak!="base")

preserve
replace ratio_walking=0 if distance_mrt_walkway_m!=.&ratio_walking==.
winsor2 ratio_walking, cuts(5 95) 
cap: drop inter_test
gen inter_test=ratio_walking_w
////standardization
center inter_test, prefix(z_) standardize
////Panel A
eststo clear /*clearing all the previous saved results*/
local dep_var "walk bus mrt car"
foreach z in `dep_var'{
local controls "i.age i.employ i.p2_gender i.hhtype control_trip i.car_own max_mode_w"
local fe "postal_code group_time i.region#i.group_time"
local condition `"weekday>=1&weekday<=5 "' 
local cluster "postal_code"

eststo: reghdfe dummy_`z'_t8 1.Treat##1.Post##c.z_inter_test `controls' if `condition'&dummy_peak==0, a(`fe') cluster(`cluster')
	sum dummy_`z'_t8 if e(sample)==1, meanonly
    estadd scalar mean = r(mean) 

}

local dep_var "walk bus car"
foreach z in `dep_var'{
local controls "i.age i.employ i.p2_gender i.hhtype control_trip i.car_own max_mode_w"
local fe "postal_code group_time i.region#i.group_time"
local condition `"weekday>=1&weekday<=5&hhtype!=12"' 
local cluster "postal_code"

eststo:  reghdfe `z'_transfer 1.Treat##1.Post##c.z_inter_test `controls' if `condition'&&dummy_peak==0, a(`fe') cluster(`cluster')
	sum `z'_transfer if e(sample)==1, meanonly
    estadd scalar mean = r(mean) 

}
estout using hete_nonpeak.tex, replace style(tex) cells(b(star fmt(3)) se(par fmt(3)) p(fmt(3))) starlevels(\textsuperscript{*} 0.10 \textsuperscript{**} 0.05 \textsuperscript{***} 0.01) ///
keep (1.Treat 1.Post 1.Treat#1.Post 1.Treat#1.Post#c.z_inter_test) ///
stats (N r2 mean, fmt(0 2 2) label("Observations" "R2" "Mean Value of Dep.Var") ) //////
varlabels (1.Treat#1.Post "Treat*Post" 1.Treat "Treat" 1.Post "Post" 1.Treat#1.Post#c.z_inter_test "Treat*Post*Coverage", elist(1.Treat#1.Post#c.z_inter_test \hline)) ///
collabels(none) mlabels(none) eqlabels(none)

////Panel B
eststo clear /*clearing all the previous saved results*/
local dep_var "walk bus mrt car"
foreach z in `dep_var'{
local controls "i.age i.employ i.p2_gender i.hhtype control_trip i.car_own max_mode_w"
local fe "postal_code group_time i.region#i.group_time"
local condition `"weekday>=1&weekday<=5 "' 
local cluster "postal_code"

eststo: reghdfe dummy_`z'_t8 1.Treat##1.Post##c.z_inter_test `controls' if `condition'&&dummy_peak==1, a(`fe') cluster(`cluster')
	sum dummy_`z'_t8 if e(sample)==1, meanonly
    estadd scalar mean = r(mean) 

}

local dep_var "walk bus car"
foreach z in `dep_var'{
local controls "i.age i.employ i.p2_gender i.hhtype control_trip i.car_own max_mode_w"
local fe "postal_code group_time i.region#i.group_time"
local condition `"weekday>=1&weekday<=5&hhtype!=12"' 
local cluster "postal_code"

eststo:  reghdfe `z'_transfer 1.Treat##1.Post##c.z_inter_test `controls' if `condition'&&dummy_peak==1, a(`fe') cluster(`cluster')
	sum `z'_transfer if e(sample)==1, meanonly
    estadd scalar mean = r(mean) 

}
estout using hete_peaktime.tex, replace style(tex) cells(b(star fmt(3)) se(par fmt(3)) p(fmt(3))) starlevels(\textsuperscript{*} 0.10 \textsuperscript{**} 0.05 \textsuperscript{***} 0.01) ///
keep (1.Treat 1.Post 1.Treat#1.Post 1.Treat#1.Post#c.z_inter_test) ///
stats (N r2 mean, fmt(0 2 2) label("Observations" "R2" "Mean Value of Dep.Var") ) //////
varlabels (1.Treat#1.Post "Treat*Post" 1.Treat "Treat" 1.Post "Post" 1.Treat#1.Post#c.z_inter_test "Treat*Post*Coverage", elist(1.Treat#1.Post#c.z_inter_test \hline)) ///
collabels(none) mlabels(none) eqlabels(none)


restore

