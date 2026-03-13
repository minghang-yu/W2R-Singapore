***************************************************Figure 4: Event Study on Travel Modes***************************************************
cap: drop policy 
cap: drop pre_* 
cap: drop post_* 
cap: drop current


gen policy=.
replace policy=1 if Year==2016
replace policy=1 if Year==2017
replace policy=-1 if Year==2013
replace policy=-1 if Year==2012
replace policy=-2 if Year==2009
replace policy=-2 if Year==2008


label var policy "the difference in years between observation year and treat_year (<0= before; >=0 = after)"
replace policy = . if policy < -2
replace policy = . if policy > 1
////generate the interaction term of Treat and time length
forvalues j = 2(-1)1{
  gen pre_`j' = (policy == -`j' & Treat == 1) 
}

forvalues h = 1(1)1{
  gen  post_`h' = (policy == `h' & Treat  == 1)
}
drop pre_1

////Main mode
eststo clear /*clearing all the previous saved results*/
local dep_var "walk bus mrt car"
foreach z in `dep_var'{
local controls "i.age i.employ i.p2_gender i.hhtype control_trip i.car_own max_mode_w"
local fe "postal_code group_time i.region#i.group_time"
local condition `"weekday>=1&weekday<=5"' 
local cluster "postal_code"

qui: reghdfe dummy_`z'_t8 1.Treat##1.Post `controls' if `condition', a(`fe') cluster(`cluster')
cap: drop sample
gen sample = e(sample)

reghdfe dummy_`z'_t8 pre_* post_* Treat policy `controls'  if  sample==1, a(`fe') cluster(`cluster')
parmest, level(95) format(estimate min95 max95 %8.2f p %8.3f) saving(dummy_`z'_pretrend.dta, replace)

}

////First-mile mode
eststo clear /*clearing all the previous saved results*/
local dep_var "walk bus car"
foreach y in `dep_var'{

local controls "i.age i.employ i.p2_gender i.hhtype control_trip i.car_own max_mode_w"
local fe "postal_code group_time i.region#i.group_time"
local condition `"weekday>=1&weekday<=5 "' 
local cluster "postal_code"

qui: reghdfe `y'_transfer 1.Treat##1.Post `controls' if `condition', a(`fe') cluster(`cluster')
cap: drop sample
gen sample = e(sample)

reghdfe `y'_transfer pre_* post_* Treat policy `controls'  if  sample==1, a(`fe') cluster(`cluster')
parmest, level(95) format(estimate min95 max95 %8.2f p %8.3f) saving(transfer_`y'_pretrend.dta, replace)

}

**********Main mode figure a
set scheme white_jet
preserve
use dummy_walk_pretrend.dta, replace 
gen type="walk"
append using dummy_mrt_pretrend.dta
replace type="mrt" if type==""
append using dummy_bus_pretrend.dta
replace type="bus" if type==""
append using dummy_car_pretrend.dta
replace type="car" if type==""

keep if parm=="pre_2"|parm=="post_1"

split parm, p(_)

replace parm2="0" if parm1=="post"
destring parm2, force replace
drop if parm2==.
replace parm2 = parm2*-1 if parm1=="pre"

** 
set obs `=_N+1'
replace estimate = 0 if estimate ==.
replace min95 = 0 if min95 ==.
replace max95 = 0 if max95 ==.
replace parm2 = -1 if parm2==.

replace parm2=parm2+0.1 if type=="bus"
replace parm2=parm2+0.2 if type=="mrt"
replace parm2=parm2+0.3 if type=="car"
sort parm2

sum estimate, det
local ylower = round(r(min),.01) - 0.10
di `ylower'
local yupper = round(r(max),.01) + 0.06
di `yupper'

graph twoway ///
    (scatter estimate parm2 if type == "walk", ///
        msymbol(circle) mcolor(navy) lcolor(navy) ///
        mlabel(estimate) mlabsize(vsmall) mlabposition(9) mlabformat(%8.2fc)) ///
    (rcap min95 max95 parm2 if type == "walk", ///
        lcolor(navy) lpattern(solid)) ///
    ///
    (scatter estimate parm2 if type == "bus", ///
        msymbol(square) mcolor(maroon) lcolor(maroon) ///
        mlabel(estimate) mlabsize(vsmall) mlabposition(6) mlabformat(%8.2fc)) ///
    (rcap min95 max95 parm2 if type == "bus", ///
        lcolor(maroon) lpattern(solid)) ///
    ///
    (scatter estimate parm2 if type == "mrt", ///
        msymbol(diamond) mcolor(forest_green) lcolor(forest_green) ///
        mlabel(estimate) mlabsize(vsmall) mlabposition(6) mlabformat(%8.2fc)) ///
    (rcap min95 max95 parm2 if type == "mrt",lcolor(forest_green) lpattern(solid))  (scatter estimate parm2 if type == "car", ///
        msymbol(triangle) mcolor(black) lcolor(black) ///
        mlabel(estimate) mlabsize(vsmall) mlabposition(3) mlabformat(%8.2fc)) ///
    (rcap min95 max95 parm2 if type == "car", ///
        lcolor(black) lpattern(solid)) (scatter estimate parm2 if parm2==-1, msymbol(O) mcolor(black))  , ///
		legend(order(1 "Walk" 3 "Bus" 5 "MRT" 7 "Car") position(5) ring(0) region(lstyle(none))) ytitle("Estimated Effects On The Main Travel Mode") xtitle("Survey Round (Relative to 2012 Wave)")  ylabel(`ylower'(0.05) `yupper',format(%8.2g) nogrid) yline(0 , lpattern(dash) lcolor(black)) title("") ///
	xlabel(0 "2016 (Post 1)" -1 "2012 (Pre 1)" -2 "2008 (Pre 2)" 1 " ", nogrid) aspect(0.5) 
    graph save Main_pretrend.gph, replace
	graph export Main_pretrend.pdf, as(pdf) replace	

restore

**********First-mile mode figure b
preserve
use transfer_walk_pretrend.dta, replace 
gen type="walk"
append using transfer_bus_pretrend.dta
replace type="bus" if type==""
append using transfer_car_pretrend.dta
replace type="car" if type==""


keep if parm=="pre_2"|parm=="post_1"

split parm, p(_)

replace parm2="0" if parm1=="post"
destring parm2, force replace
drop if parm2==.
replace parm2 = parm2*-1 if parm1=="pre"

** 
set obs `=_N+1'
replace estimate = 0 if estimate ==.
replace min95 = 0 if min95 ==.
replace max95 = 0 if max95 ==.
replace parm2 = -1 if parm2==.

replace parm2=parm2+0.1 if type=="bus"
replace parm2=parm2+0.2 if type=="car"

sum estimate, det
local ylower = round(r(min),.01) - 0.10
di `ylower'
local yupper = round(r(max),.01) + 0.15
di `yupper'

graph twoway ///
    (scatter estimate parm2 if type == "walk", ///
        msymbol(circle) mcolor(navy) lcolor(navy) ///
        mlabel(estimate) mlabsize(vsmall) mlabposition(9) mlabformat(%8.2fc)) ///
    (rcap min95 max95 parm2 if type == "walk", ///
        lcolor(navy) lpattern(solid)) ///
    ///
    (scatter estimate parm2 if type == "bus", ///
        msymbol(square) mcolor(maroon) lcolor(maroon) ///
        mlabel(estimate) mlabsize(vsmall) mlabposition(6) mlabformat(%8.2fc)) ///
    (rcap min95 max95 parm2 if type == "bus", ///
        lcolor(maroon) lpattern(solid)) ///
    ///
    (scatter estimate parm2 if type == "car", ///
        msymbol(triangle) mcolor(black) lcolor(black) ///
        mlabel(estimate) mlabsize(vsmall) mlabposition(3) mlabformat(%8.2fc)) ///
    (rcap min95 max95 parm2 if type == "car", ///
        lcolor(black) lpattern(solid)) (scatter estimate parm2 if parm2==-1, msymbol(O) mcolor(black)) , ///
		legend(order(1 "Walk" 3 "Bus" 5 "Car" ) position(5) ring(0) region(lstyle(none))) ytitle("Estimated Effects On The First Travel Mode") xtitle("Survey Round (Relative to 2012 Wave)")  ylabel(`ylower'(0.05) `yupper',format(%8.2g) nogrid) yline(0 , lpattern(dash) lcolor(black)) title("") ///
	xlabel(0 "2016 (Post 1)" -1 "2012 (Pre 1)" -2 "2008 (Pre 2)" 1 " ", nogrid) aspect(0.5) 
    graph save First_pretrend.gph, replace
	graph export First_pretrend.pdf, as(pdf) replace	

restore


*************************************************Figure 5: Impacts on Number of Outdoor Trips*************************************************

preserve
////calculate the daily number of trips of each person 
drop if control_trip==.
bysort person_id stata_date: gen frequency=_N
gen ln_freq=ln(frequency)
////collapse the data into individual-day level
bysort person_id stata_date: gen filt=_n
keep if filt==1

winsor2 ln_freq, cut(5 95)
////baseline on overall trips
eststo clear /*clearing all the previous saved results*/
local controls "i.age i.employ i.p2_gender i.hhtype i.car_own"
local fe "postal_code stata_date i.region#i.stata_date"
local condition `"weekday>=1&weekday<=5"' 
local cluster "postal_code"

eststo: reghdfe ln_freq_w 1.Treat##1.Post `controls' if `condition', a(`fe') cluster(`cluster')
parmest, level(95) format(estimate min95 max95 %8.2f p %8.3f) saving(base_outdoor.dta, replace)
////heterogenous impacts on the total number of trips by peak types
cap: drop Treat_*
gen Treat_NonPeak=1 if Treat==1&Peak=="non"
replace Treat_NonPeak=0 if Treat_NonPeak==.

gen Treat_MornPeak=1 if Treat==1&Peak=="Morn_peak"
replace Treat_MornPeak=0 if Treat_MornPeak==.

gen Treat_EvenPeak=1 if Treat==1&Peak=="Even_peak"
replace Treat_EvenPeak=0 if Treat_EvenPeak==.

eststo: reghdfe ln_freq_w 1.Treat_*##1.Post `controls' if `condition', a(`fe') cluster(`cluster')
parmest, level(95) format(estimate min95 max95 %8.2f p %8.3f) saving(peak_outdoor.dta, replace)

////heterogenous impacts on the total number of trips by distances to the transit hub
cap: drop Treat_*_*
gen Treat_0_4=1 if Treat==1&distance_mrt_walkway_m>0&distance_mrt_walkway_m<=400
replace Treat_0_4=0 if Treat_0_4==.

gen Treat_4_8=1 if Treat==1&distance_mrt_walkway_m>400&distance_mrt_walkway_m<=800
replace Treat_4_8=0 if Treat_4_8==.

gen Treat_8_12=1 if Treat==1&distance_mrt_walkway_m>800&distance_mrt_walkway_m<=1200
replace Treat_8_12=0 if Treat_8_12==.

eststo: reghdfe ln_freq_w 1.Treat_*_*##1.Post `controls' if `condition', a(`fe') cluster(`cluster')
parmest, level(95) format(estimate min95 max95 %8.2f p %8.3f) saving(mrtbuffer_outdoor.dta, replace)

////heterogenous impacts on the total number of trips by the rainfall
cap: drop Treat_prcp_*

	gen Treat_prcp_1=1 if Treat==1&prcp>0.2&prcp<=2
    replace Treat_prcp_1=0 if Treat_prcp_1==.

	gen Treat_prcp_2=1 if Treat==1&prcp>2&prcp<=9.5
    replace Treat_prcp_2=0 if Treat_prcp_2==.

	gen Treat_prcp_3=1 if Treat==1&prcp>9.5
    replace Treat_prcp_3=0 if Treat_prcp_3==.

eststo: reghdfe ln_freq_w 1.Treat_prcp_*##1.Post `controls' if `condition', a(`fe') cluster(`cluster')
parmest, level(95) format(estimate min95 max95 %8.2f p %8.3f) saving(rainfall_outdoor.dta, replace)

restore
////present all estimates in one figure
preserve
use base_outdoor.dta, clear
gen group=1
append using peak_outdoor.dta
replace group=3 if group==.
append using mrtbuffer_outdoor.dta
replace group=5 if group==.
append using rainfall_outdoor.dta
replace group=7 if group==.

split parm, p("#")
keep if parm2=="1.Post"
bysort group: gen filt=_n-2
gen number_group=group+0.3*filt


sum estimate, det
local ylower = round(r(min),.01) - 0.10
di `ylower'
local yupper = round(r(max),.01) + 0.06
di `yupper'

graph twoway ///
    (scatter estimate number_group if group == 1, ///
        msymbol(circle) mcolor(navy) lcolor(navy) ///
        mlabel(estimate) mlabsize(vsmall) mlabposition(1) mlabformat(%8.2fc)) ///
    (rcap min95 max95 number_group if group == 1, ///
        lcolor(navy) lpattern(solid)) ///
    ///
    (scatter estimate number_group if group == 3, ///
        msymbol(square) mcolor(maroon) lcolor(maroon) ///
        mlabel(estimate) mlabsize(vsmall) mlabposition(1) mlabformat(%8.2fc)) ///
    (rcap min95 max95 number_group if group == 3, ///
        lcolor(maroon) lpattern(solid)) ///
    ///
    (scatter estimate number_group if group == 5, ///
        msymbol(diamond) mcolor(forest_green) lcolor(forest_green) ///
        mlabel(estimate) mlabsize(vsmall) mlabposition(1) mlabformat(%8.2fc)) ///
    (rcap min95 max95 number_group if group == 5,lcolor(forest_green) lpattern(solid)) (scatter estimate number_group if group==7, ///
        msymbol(triangle) mcolor(gray) lcolor(black) ///
        mlabel(estimate) mlabsize(vsmall) mlabposition(1) mlabformat(%8.2fc)) ///
    (rcap min95 max95 number_group if group==7, ///
        lcolor(gray) lpattern(solid)) ///
, ///
		legend(order(1 "Baseline" 3 "By Peak Type" 5 "By MRT Buffer" 7 "By Precpitation") position(7) ring(0) region(lstyle(none))) ytitle("Estimated Effects On The Number of Trips") xtitle(" ")  ylabel(`ylower'(0.04) 0.16,format(%8.2g) nogrid) yline(0 , lpattern(dash) lcolor(black)) title("") ///
	xlabel(0 " " 0.7 "Overall" 2.7 "Non-peak" 3 "Morning-peak" 3.3 "Evening-peak" 4.7 "0-400m" 5 "400-800m" 5.3 "800-1200m" 6.7 "Low-rainfall" 7 "Medium-rainfall" 7.3 "High-rainfall" 8 " ", nogrid labsize(vsmall) angle(45)) aspect(0.5) 
    graph save baseline_outdoor.gph, replace
	graph export baseline_outdoor.pdf, as(pdf) replace	
restore

*************************************************Figure 6a 6b+ Table S3: Heterogeneity by Rainfall*************************************************
cap: drop Treat_prcp_*
	gen Treat_prcp_1=1 if Treat==1&prcp>0.2&prcp<=2
    replace Treat_prcp_1=0 if Treat_prcp_1==.

	gen Treat_prcp_2=1 if Treat==1&prcp>2&prcp<=9.5
    replace Treat_prcp_2=0 if Treat_prcp_2==.

	gen Treat_prcp_3=1 if Treat==1&prcp>9.5
    replace Treat_prcp_3=0 if Treat_prcp_3==.
////main modes
eststo clear /*clearing all the previous saved results*/
local dep_var "walk bus mrt car"
foreach z in `dep_var'{
local controls "i.age i.employ i.p2_gender i.hhtype control_trip i.car_own max_mode_w"
local fe "postal_code group_time i.region#i.group_time"
local condition `"weekday>=1&weekday<=5"' 
local cluster "postal_code"

eststo: reghdfe dummy_`z'_t8 1.Treat_prcp_*##1.Post `controls' if `condition', a(`fe') cluster(`cluster')
	sum dummy_`z'_t8 if e(sample)==1, meanonly
    estadd scalar mean = r(mean) 
parmest, format (estimate min95 max95 %8.2f p %8.3f) saving(Dummyrainfall_`z'.dta, replace)

}
////first-mile modes
local dep_var "walk bus car"
foreach z in `dep_var'{
local controls "i.age i.employ i.p2_gender i.hhtype control_trip i.car_own max_mode_w"
local fe "postal_code group_time i.region#i.group_time"
local condition `"weekday>=1&weekday<=5"' 
local cluster "postal_code"

eststo: reghdfe `z'_transfer 1.Treat_prcp_*##1.Post `controls' if `condition', a(`fe') cluster(`cluster')
	sum `z'_transfer if e(sample)==1, meanonly
    estadd scalar mean = r(mean) 
parmest, format (estimate min95 max95 %8.2f p %8.3f) saving(Transferrain_`z'.dta, replace)

}

estout using hete_prcp.tex, replace style(tex) cells(b(star fmt(3))  se(label("Standard Error") par fmt(3)) p(label("P value" ) fmt(3))) starlevels(\textsuperscript{*} 0.10 \textsuperscript{**} 0.05 \textsuperscript{***} 0.01) ///
keep (1.Treat_* 1.Post 1.Treat_*#1.Post) ///
stats (N r2 mean, fmt(0 2 2) label("Observations" "R2" "Mean Value of Dep.Var") ) //////
varlabels (1.Treat_prcp_1#1.Post "Low-rainfall*Post" 1.Treat_prcp_1 "Low-rainfall" 1.Treat_prcp_2#1.Post "Medium-rainfall*Post" 1.Treat_prcp_2 "Medium-rainfall" 1.Treat_prcp_3#1.Post "High-rainfall*Post" 1.Treat_prcp_3 "High-rainfall" 1.Post "Post" , elist(1.Treat#1.Post \hline)) ///
collabels(none) mlabels(none) eqlabels(none)

////present the estimates of main mode in one figure
preserve
use Dummyrainfall_walk.dta, replace 
gen type="walk"
append using Dummyrainfall_mrt.dta
replace type="mrt" if type==""
append using Dummyrainfall_bus.dta
replace type="bus" if type==""
append using Dummyrainfall_car.dta
replace type="car" if type==""


split parm, p("_" ".")
keep if parm5=="Post"
gen filt=1 if parm4=="1#1"
replace filt=2 if parm4=="2#1"
replace filt=3 if parm4=="3#1"
// replace filt=4 if parm3=="24#1"

replace filt=filt+0.1 if type=="bus"
replace filt=filt+0.2 if type=="mrt"
replace filt=filt+0.3 if type=="car"

sum estimate, det
local ylower = round(r(min),.01) - 0.10
di `ylower'
local yupper = round(r(max),.01) + 0.06
di `yupper'

graph twoway ///
    (scatter estimate filt if type == "walk", ///
        msymbol(circle) mcolor(navy) lcolor(navy) ///
        mlabel(estimate) mlabsize(vsmall) mlabposition(9) mlabformat(%8.2fc)) ///
    (rcap min95 max95 filt if type == "walk", ///
        lcolor(navy) lpattern(solid)) ///
    ///
    (scatter estimate filt if type == "bus", ///
        msymbol(square) mcolor(maroon) lcolor(maroon) ///
        mlabel(estimate) mlabsize(vsmall) mlabposition(6) mlabformat(%8.2fc)) ///
    (rcap min95 max95 filt if type == "bus", ///
        lcolor(maroon) lpattern(solid)) ///
    ///
    (scatter estimate filt if type == "mrt", ///
        msymbol(diamond) mcolor(forest_green) lcolor(forest_green) ///
        mlabel(estimate) mlabsize(vsmall) mlabposition(6) mlabformat(%8.2fc)) ///
    (rcap min95 max95 filt if type == "mrt",lcolor(forest_green) lpattern(solid))  (scatter estimate filt if type == "car", ///
        msymbol(triangle) mcolor(black) lcolor(black) ///
        mlabel(estimate) mlabsize(vsmall) mlabposition(3) mlabformat(%8.2fc)) ///
    (rcap min95 max95 filt if type == "car", ///
        lcolor(black) lpattern(solid)) , ///
		legend(order(1 "Walk" 3 "Bus" 5 "MRT" 7 "Car") position(11) ring(0) region(lstyle(none))) ytitle("Estimated Effects On The Main Travel Mode") xtitle("Daily Precpitation")  ylabel(-0.15(0.05) 0.15,format(%8.2g) nogrid) yline(0 , lpattern(dash) lcolor(black)) title("") ///
	xlabel(0 " " 1 "Low-rainfall" 2 "Medium-rainfall" 3 "High-rainfall" 4 " " , nogrid) aspect(0.5) 
    graph save Hete_main_rainfall.gph, replace
	graph export Hete_main_rainfall.png, as(png) replace	

restore

////present the estimates of first-mile mode in one figure
preserve
use Transferrain_walk.dta, replace 
gen type="walk"
append using Transferrain_bus.dta
replace type="bus" if type==""
append using Transferrain_car.dta
replace type="car" if type==""


split parm, p("_" ".")
keep if parm5=="Post"
gen filt=1 if parm4=="1#1"
replace filt=2 if parm4=="2#1"
replace filt=3 if parm4=="3#1"
// replace filt=4 if parm3=="24#1"

replace filt=filt+0.1 if type=="bus"
// replace filt=filt+0.2 if type=="mrt"
replace filt=filt+0.2 if type=="car"

sum estimate, det
local ylower = round(r(min),.01) - 0.10
di `ylower'
local yupper = round(r(max),.01) + 0.06
di `yupper'

graph twoway ///
    (scatter estimate filt if type == "walk", ///
        msymbol(circle) mcolor(navy) lcolor(navy) ///
        mlabel(estimate) mlabsize(vsmall) mlabposition(9) mlabformat(%8.2fc)) ///
    (rcap min95 max95 filt if type == "walk", ///
        lcolor(navy) lpattern(solid)) ///
    ///
    (scatter estimate filt if type == "bus", ///
        msymbol(square) mcolor(maroon) lcolor(maroon) ///
        mlabel(estimate) mlabsize(vsmall) mlabposition(6) mlabformat(%8.2fc)) ///
    (rcap min95 max95 filt if type == "bus", ///
        lcolor(maroon) lpattern(solid)) ///
    ///
    (scatter estimate filt if type == "car", ///
        msymbol(triangle) mcolor(black) lcolor(black) ///
        mlabel(estimate) mlabsize(vsmall) mlabposition(3) mlabformat(%8.2fc)) ///
    (rcap min95 max95 filt if type == "car", ///
        lcolor(black) lpattern(solid)) , ///
		legend(order(1 "Walk" 3 "Bus" 5 "Car" ) position(11) ring(0) region(lstyle(none))) ytitle("Estimated Effects On The First Travel Mode") xtitle("Daily Precpitation")  ylabel(-0.32(0.08) 0.32,format(%8.2g) nogrid) yline(0 , lpattern(dash) lcolor(black)) title("") ///
	xlabel(0 " " 1 "Low-rainfall" 2 "Medium-rainfall" 3 "High-rainfall" 4 " " , nogrid) aspect(0.5) 
    graph save Hete_first_rainfall.gph, replace
	graph export Hete_first_rainfall.png, as(png) replace	

restore

*******************************************Figure 6c 6d+Table S4: Heterogeneity by Distance to Hub*************************************************
cap: drop Treat_*_*
gen Treat_0_4=1 if Treat==1&distance_mrt_walkway_m>0&distance_mrt_walkway_m<=400
replace Treat_0_4=0 if Treat_0_4==.

gen Treat_4_8=1 if Treat==1&distance_mrt_walkway_m>400&distance_mrt_walkway_m<=800
replace Treat_4_8=0 if Treat_4_8==.

gen Treat_8_12=1 if Treat==1&distance_mrt_walkway_m>800&distance_mrt_walkway_m<=1200
replace Treat_8_12=0 if Treat_8_12==.

////main modes
eststo clear /*clearing all the previous saved results*/
local dep_var "walk bus mrt car"
foreach z in `dep_var'{
local controls "i.age i.employ i.p2_gender i.hhtype control_trip i.car_own max_mode_w"
local fe "postal_code group_time i.region#i.group_time"
local condition `"weekday>=1&weekday<=5"' 
local cluster "postal_code"

eststo: reghdfe dummy_`z'_t8 1.Treat_*_*##1.Post `controls' if `condition', a(`fe') cluster(`cluster')
	sum dummy_`z'_t8 if e(sample)==1, meanonly
    estadd scalar mean = r(mean) 
parmest, format (estimate min95 max95 %8.2f p %8.3f) saving(Dummybuffer_`z'.dta, replace)

}
////first-mile modes
local dep_var "walk bus car"
foreach z in `dep_var'{
local controls "i.age i.employ i.p2_gender i.hhtype control_trip i.car_own max_mode_w"
local fe "postal_code group_time i.region#i.group_time"
local condition `"weekday>=1&weekday<=5 "' 
local cluster "postal_code"

eststo: reghdfe `z'_transfer 1.Treat_*_*##1.Post `controls' if `condition', a(`fe') cluster(`cluster')
	sum `z'_transfer if e(sample)==1, meanonly
    estadd scalar mean = r(mean) 
parmest, format (estimate min95 max95 %8.2f p %8.3f) saving(Transferbuffer_`z'.dta, replace)

}

estout using hete_mrtbuffer.tex, replace style(tex) cells(b(star fmt(3)) se(par fmt(3)) p(fmt(3))) starlevels(\textsuperscript{*} 0.10 \textsuperscript{**} 0.05 \textsuperscript{***} 0.01)  ///
keep (1.Treat_* 1.Post 1.Treat_*#1.Post) ///
stats (N r2 mean, fmt(0 2 2) label("Observations" "R2" "Mean Value of Dep.Var") ) //////
varlabels (1.Treat_0_4#1.Post "Buffer0-400m*Post" 1.Treat_0_4 "Buffer0-400m" 1.Treat_4_8#1.Post "Buffer400-800m*Post" 1.Treat_4_8 "Buffer400-800m" 1.Treat_8_12#1.Post "Buffer800-1200m*Post" 1.Treat_8_12 "Buffer800-1200m" 1.Post "Post", elist(1.Treat#1.Post \hline)) ///
collabels(none) mlabels(none) eqlabels(none)


////present the estimates of main mode in one figure
preserve
use Dummybuffer_walk.dta, replace 
gen type="walk"
append using Dummybuffer_mrt.dta
replace type="mrt" if type==""
append using Dummybuffer_bus.dta
replace type="bus" if type==""
append using Dummybuffer_car.dta
replace type="car" if type==""


split parm, p("_" ".")
keep if parm5=="Post"
gen filt=1 if parm4=="4#1"
replace filt=2 if parm4=="8#1"
replace filt=3 if parm4=="12#1"
// replace filt=4 if parm3=="24#1"

replace filt=filt+0.1 if type=="bus"
replace filt=filt+0.2 if type=="mrt"
replace filt=filt+0.3 if type=="car"

sum estimate, det
local ylower = round(r(min),.01) - 0.10
di `ylower'
local yupper = round(r(max),.01) + 0.06
di `yupper'

graph twoway ///
    (scatter estimate filt if type == "walk", ///
        msymbol(circle) mcolor(navy) lcolor(navy) ///
        mlabel(estimate) mlabsize(vsmall) mlabposition(9) mlabformat(%8.2fc)) ///
    (rcap min95 max95 filt if type == "walk", ///
        lcolor(navy) lpattern(solid)) ///
    ///
    (scatter estimate filt if type == "bus", ///
        msymbol(square) mcolor(maroon) lcolor(maroon) ///
        mlabel(estimate) mlabsize(vsmall) mlabposition(6) mlabformat(%8.2fc)) ///
    (rcap min95 max95 filt if type == "bus", ///
        lcolor(maroon) lpattern(solid)) ///
    ///
    (scatter estimate filt if type == "mrt", ///
        msymbol(diamond) mcolor(forest_green) lcolor(forest_green) ///
        mlabel(estimate) mlabsize(vsmall) mlabposition(6) mlabformat(%8.2fc)) ///
    (rcap min95 max95 filt if type == "mrt",lcolor(forest_green) lpattern(solid))  (scatter estimate filt if type == "car", ///
        msymbol(triangle) mcolor(black) lcolor(black) ///
        mlabel(estimate) mlabsize(vsmall) mlabposition(3) mlabformat(%8.2fc)) ///
    (rcap min95 max95 filt if type == "car", ///
        lcolor(black) lpattern(solid)) , ///
		legend(order(1 "Walk" 3 "Bus" 5 "MRT" 7 "Car") position(11) ring(0) region(lstyle(none))) ytitle("Estimated Effects On The Main Travel Mode") xtitle("Walking Distance to the Nearest MRT")  ylabel(-0.15(0.05) 0.15,format(%8.2g) nogrid) yline(0 , lpattern(dash) lcolor(black)) title("") ///
	xlabel(0 " " 1 "0-400m" 2 "400-800m" 3 "800-1200m" 4 " " , nogrid) aspect(0.5) 
    graph save Hete_main_mrtbuffer.gph, replace
	graph export Hete_main_mrtbuffer.png, as(png) replace	

restore

////present the estimates of first-mile mode in one figure
preserve
use Transferbuffer_walk.dta, replace 
gen type="walk"
append using Transferbuffer_bus.dta
replace type="bus" if type==""
append using Transferbuffer_car.dta
replace type="car" if type==""


split parm, p("_" ".")
keep if parm5=="Post"
gen filt=1 if parm4=="4#1"
replace filt=2 if parm4=="8#1"
replace filt=3 if parm4=="12#1"
// replace filt=4 if parm3=="24#1"

replace filt=filt+0.1 if type=="bus"
replace filt=filt+0.2 if type=="car"

sum estimate, det
local ylower = round(r(min),.01) - 0.10
di `ylower'
local yupper = round(r(max),.01) + 0.06
di `yupper'

graph twoway ///
    (scatter estimate filt if type == "walk", ///
        msymbol(circle) mcolor(navy) lcolor(navy) ///
        mlabel(estimate) mlabsize(vsmall) mlabposition(9) mlabformat(%8.2fc)) ///
    (rcap min95 max95 filt if type == "walk", ///
        lcolor(navy) lpattern(solid)) ///
    ///
    (scatter estimate filt if type == "bus", ///
        msymbol(square) mcolor(maroon) lcolor(maroon) ///
        mlabel(estimate) mlabsize(vsmall) mlabposition(6) mlabformat(%8.2fc)) ///
    (rcap min95 max95 filt if type == "bus", ///
        lcolor(maroon) lpattern(solid)) ///
    ///
    (scatter estimate filt if type == "car", ///
        msymbol(triangle) mcolor(black) lcolor(black) ///
        mlabel(estimate) mlabsize(vsmall) mlabposition(3) mlabformat(%8.2fc)) ///
    (rcap min95 max95 filt if type == "car",lcolor(black) lpattern(solid)), ///
		legend(order(1 "Walk" 3 "Bus" 5 "Car") position(11) ring(0) region(lstyle(none))) ytitle("Estimated Effects On The First Travel Mode") xtitle("Walking Distance to the Nearest MRT")  ylabel(-0.24(0.06) 0.3,format(%8.2g) nogrid) yline(0 , lpattern(dash) lcolor(black)) title("") ///
	xlabel(0 " " 1 "0-400m" 2 "400-800m" 3 "800-1200m" 4 " " , nogrid) aspect(0.5) 
    graph save Hete_first_mrtbuffer.gph, replace
	graph export Hete_first_mrtbuffer.png, as(png) replace	

restore

*******************************************Figure 6e 6f+Table S5: Heterogeneity by Time of Day*************************************************
cap: drop Treat_*
gen Treat_NonPeak=1 if Treat==1&Peak=="non"
replace Treat_NonPeak=0 if Treat_NonPeak==.

gen Treat_MornPeak=1 if Treat==1&Peak=="Morn_peak"
replace Treat_MornPeak=0 if Treat_MornPeak==.

gen Treat_EvenPeak=1 if Treat==1&Peak=="Even_peak"
replace Treat_EvenPeak=0 if Treat_EvenPeak==.

eststo clear /*clearing all the previous saved results*/
local dep_var "walk bus mrt car"
foreach z in `dep_var'{
local controls "i.age i.employ i.p2_gender i.hhtype control_trip i.car_own max_mode_w"
local fe "postal_code group_time i.region#i.group_time"
local condition `"weekday>=1&weekday<=5"' 
local cluster "postal_code"

eststo: reghdfe dummy_`z'_t8 1.Treat_*##1.Post `controls' if `condition', a(`fe') cluster(`cluster')
	sum dummy_`z'_t8 if e(sample)==1, meanonly
    estadd scalar mean = r(mean) 
parmest, format (estimate min95 max95 %8.2f p %8.3f) saving(Dummypeak_`z'.dta, replace)

}

local dep_var "walk bus car"
foreach z in `dep_var'{
local controls "i.age i.employ i.p2_gender i.hhtype control_trip i.car_own max_mode_w"
local fe "postal_code group_time i.region#i.group_time"
local condition `"weekday>=1&weekday<=5 "' 
local cluster "postal_code"

eststo: reghdfe `z'_transfer 1.Treat_*##1.Post `controls' if `condition', a(`fe') cluster(`cluster')
	sum `z'_transfer if e(sample)==1, meanonly
    estadd scalar mean = r(mean) 
parmest, format (estimate min95 max95 %8.2f p %8.3f) saving(Transferpeak_`z'.dta, replace)

}

estout using hete_peak.tex, replace style(tex) cells(b(star fmt(3)) se(par fmt(3)) p(fmt(3))) starlevels(\textsuperscript{*} 0.10 \textsuperscript{**} 0.05 \textsuperscript{***} 0.01)  ///
keep (1.Treat_* 1.Post 1.Treat_*#1.Post) ///
stats (N r2 mean, fmt(0 2 2) label("Observations" "R2" "Mean Value of Dep.Var") ) //////
varlabels (1.Treat_NonPeak#1.Post "Non-peak*Post" 1.Treat_NonPeak "Non-peak" 1.Treat_MornPeak#1.Post "Morning-peak*Post" 1.Treat_MornPeak "Morning-peak" 1.Treat_EvenPeak#1.Post "Evening-peak*Post" 1.Treat_EvenPeak "Evening-peak" 1.Post "Post" , elist(1.Treat#1.Post \hline)) ///
collabels(none) mlabels(none) eqlabels(none)

////present the estimates of main mode in one figure
preserve
use Dummypeak_walk.dta, replace 
gen type="walk"
append using Dummypeak_mrt.dta
replace type="mrt" if type==""
append using Dummypeak_bus.dta
replace type="bus" if type==""
append using Dummypeak_car.dta
replace type="car" if type==""


split parm, p("_" ".")
keep if parm4=="Post"
gen filt=1 if parm3=="NonPeak#1"
replace filt=2 if parm3=="MornPeak#1"
replace filt=3 if parm3=="EvenPeak#1"

replace filt=filt+0.1 if type=="bus"
replace filt=filt+0.2 if type=="mrt"
replace filt=filt+0.3 if type=="car"

sum estimate, det
local ylower = round(r(min),.01) - 0.10
di `ylower'
local yupper = round(r(max),.01) + 0.06
di `yupper'

graph twoway ///
    (scatter estimate filt if type == "walk", ///
        msymbol(circle) mcolor(navy) lcolor(navy) ///
        mlabel(estimate) mlabsize(vsmall) mlabposition(9) mlabformat(%8.2fc)) ///
    (rcap min95 max95 filt if type == "walk", ///
        lcolor(navy) lpattern(solid)) ///
    ///
    (scatter estimate filt if type == "bus", ///
        msymbol(square) mcolor(maroon) lcolor(maroon) ///
        mlabel(estimate) mlabsize(vsmall) mlabposition(6) mlabformat(%8.2fc)) ///
    (rcap min95 max95 filt if type == "bus", ///
        lcolor(maroon) lpattern(solid)) ///
    ///
    (scatter estimate filt if type == "mrt", ///
        msymbol(diamond) mcolor(forest_green) lcolor(forest_green) ///
        mlabel(estimate) mlabsize(vsmall) mlabposition(6) mlabformat(%8.2fc)) ///
    (rcap min95 max95 filt if type == "mrt",lcolor(forest_green) lpattern(solid)) (scatter estimate filt if type == "car", ///
        msymbol(triangle) mcolor(black) lcolor(black) ///
        mlabel(estimate) mlabsize(vsmall) mlabposition(3) mlabformat(%8.2fc)) ///
    (rcap min95 max95 filt if type == "car", ///
        lcolor(black) lpattern(solid)) ///
, ///
		legend(order(1 "Walk" 3 "Bus" 5 "MRT" 7 "Car") position(11) ring(0) region(lstyle(none))) ytitle("Estimated Effects On The Main Travel Mode") xtitle("Peak Type")  ylabel(-0.1(0.02) 0.1,format(%8.2g) nogrid) yline(0 , lpattern(dash) lcolor(black)) title("") ///
	xlabel(0 " " 1 "Non-Peak" 2 "Morning Peak" 3 "Evening Peak" 4 " " , nogrid) aspect(0.5) 
    graph save Hete_main_peak.gph, replace
	graph export Hete_main_peak.png, as(png) replace	

restore

////present the estimates of first-mile mode in one figure
preserve
use Transferpeak_walk.dta, replace 
gen type="walk"
append using Transferpeak_bus.dta
replace type="bus" if type==""
append using Transferpeak_car.dta
replace type="car" if type==""


split parm, p("_" ".")
keep if parm4=="Post"
gen filt=1 if parm3=="NonPeak#1"
replace filt=2 if parm3=="MornPeak#1"
replace filt=3 if parm3=="EvenPeak#1"

replace filt=filt+0.1 if type=="bus"
replace filt=filt+0.2 if type=="car"

sum estimate, det
local ylower = round(r(min),.01) - 0.10
di `ylower'
local yupper = round(r(max),.01) + 0.06
di `yupper'

graph twoway ///
    (scatter estimate filt if type == "walk", ///
        msymbol(circle) mcolor(navy) lcolor(navy) ///
        mlabel(estimate) mlabsize(vsmall) mlabposition(9) mlabformat(%8.2fc)) ///
    (rcap min95 max95 filt if type == "walk", ///
        lcolor(navy) lpattern(solid)) ///
    ///
    (scatter estimate filt if type == "bus", ///
        msymbol(square) mcolor(maroon) lcolor(maroon) ///
        mlabel(estimate) mlabsize(vsmall) mlabposition(6) mlabformat(%8.2fc)) ///
    (rcap min95 max95 filt if type == "bus", ///
        lcolor(maroon) lpattern(solid)) ///
    ///
    (scatter estimate filt if type == "car", ///
        msymbol(triangle) mcolor(black) lcolor(black) ///
        mlabel(estimate) mlabsize(vsmall) mlabposition(3) mlabformat(%8.2fc)) ///
    (rcap min95 max95 filt if type == "car",lcolor(black) lpattern(solid)), ///
		legend(order(1 "Walk" 3 "Bus" 5 "Car") position(11) ring(0) region(lstyle(none))) ytitle("Estimated Effects On The First Travel Mode") xtitle("Peak Type")  ylabel(-0.25(0.05) 0.3,format(%8.2g) nogrid) yline(0 , lpattern(dash) lcolor(black)) title("") ///
	xlabel(0 " " 1 "Non-Peak" 2 "Morning Peak" 3 "Evening Peak" 4 " " , nogrid) aspect(0.5) 
    graph save Hete_first_peak.gph, replace
	graph export Hete_first_peak.png, as(png) replace	

restore
