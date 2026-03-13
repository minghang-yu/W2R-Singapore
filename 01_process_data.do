
gen house_location=string(latitude)+","+string(longitude)
////merge with the data of distances between the housing and walkway
merge m:1 house_location using house_walkwaystraight_distance.dta, nogen keep(master match) keepusing(distance_*)
////merge with the data of walking distances between housing and the nearest transit hub
merge m:1 postal_code using house_mrt_walkdistance_2008.dta, nogen keep(master match) keepusing(entry_cost exit_cost total_cost_walkdistance)
////merge with the data of walkway ratio from housing to the nearest transit hub
merge m:1 postal_code using postal_hub_circle_ratio.dta, nogen keep(master match) keepusing(length_walkway ratio_walkway)

gen ratio_walking=length_walkway/total_cost_walkdistance


gen Year=year(stata_date)
gen Post=( Year>2014)
cap: drop filt
////calculate the number of sub-trips in one trip
bysort trip_id Year(tripleg_id): gen filt_mode=_n
bysort trip_id Year: egen max_mode=max(filt_mode)

cap: drop tripleg_id
egen trip_ID=group(trip_id Year)
drop if trip_ID==.
drop p6bii_postal
////change the data structure to each trip at individual level
reshape wide t7_tripmode t8_triplegmode st10a_walktime st13_waittime st14_invehtime t22_tripendwalktime, i(trip_ID) j(filt_mode) 

gen time_start = clock(t3_timestart, "hm")
format time_start %tcHH:MM

gen time_end = clock(t4_timeend, "hm")
format time_end %tcHH:MM
gen time_diff_ms = time_end - time_start  
gen time_diff_min = time_diff_ms / 60000
replace time_diff_min=. if time_diff_min<=0

////define the treated residential buildings if their distance to the nearest walkway is below 100 meters
cap: drop Treat
gen Treat=(distance_straight_walkway<=100)
gen survey_id=_n
////merge with the information on the nearest transit hubs
geonear survey_id latitude longitude using transit_hub.dta, n(transit_id latitude longitude) wide
rename nid transit_id
rename km_to_nid km_to_mrt_id
merge m:1 transit_id using transit_hub.dta, nogen keep(master match) keepusing(phase_mrt)

replace p5_employ="Employed Full Time" if p5_employ=="Employed Full-time"
replace p5_employ="Employed Part Time" if p5_employ=="Employed Part-time"
replace p5_employ="Full Time Student" if p5_employ=="Full time student"
replace p5_employ="National Service" if p5_employ=="National service"
replace p5_employ="Self-Employed" if p5_employ=="Self-employed"
replace p5_employ="Voluntary Worker" if p5_employ=="Voluntary worker"

replace h2_housetype="Private flat/condo" if h2_housetype=="Private flat/condominium"
replace p4_age="85 yrs & above" if p4_age=="85 yrs & over"
encode p4_age, gen(age)
encode p5_employ, gen(employ)
encode h2_housetype, gen(hhtype)
gen hour=hh(time_start)
gen weekday = dow(stata_date)
egen group_time=group(stata_date hour)
compress
////generate region codes using the first two digits of the postal code.
cap: drop region
gen region = substr(string(postal_code), 1, 2)
destring region, replace
////define the morning, evening peak and off-peak time
cap: drop Peak
gen Peak="non"
replace Peak="Morn_peak" if (weekday==1|weekday==2|weekday==3|weekday==4|weekday==5)&(hour>=8&hour<=10)
replace Peak="Even_peak" if (weekday==1|weekday==2|weekday==3|weekday==4|weekday==5)&(hour>=18&hour<=20)
replace Peak="base" if (weekday==1|weekday==2|weekday==3|weekday==4|weekday==5)&(hour>=1&hour<=6)
////identify the first-mile mode as walking if the walking time is larger than or equal to 1 minute
cap: drop t8_triplegmode0 
cap: drop st14_invehtime0
gen t8_triplegmode0=""
replace t8_triplegmode0="Walk" if st10a_walktime1>=1&st10a_walktime1!=.
gen st14_invehtime0=st10a_walktime1 if t8_triplegmode0=="Walk"

////identify the travel mode of each stage in one trip
forval i = 0/9 {
	gen trip_mode`i'=""
	replace trip_mode`i'="Walk" if t8_triplegmode`i'=="Walk" 
	replace trip_mode`i'="MRT" if t8_triplegmode`i'=="MRT"|t8_triplegmode`i'=="LRT"|t8_triplegmode`i'=="MRT/LRT"
	replace trip_mode`i'="Bus" if t8_triplegmode`i'=="Public Bus"|t8_triplegmode`i'=="Public bus"|t8_triplegmode`i'=="School Bus"|t8_triplegmode`i'=="School bus"|t8_triplegmode`i'=="Shuttle Bus"|t8_triplegmode`i'=="Shuttle bus"|t8_triplegmode`i'=="Company Bus"|t8_triplegmode`i'=="Company bus"
	replace trip_mode`i'="Car" if t8_triplegmode`i'=="Car Driver"|t8_triplegmode`i'=="Car Passenger"|t8_triplegmode`i'=="Car driver"|t8_triplegmode`i'=="Car passenger"|t8_triplegmode`i'=="Private Hire Car"|t8_triplegmode`i'=="Mortorcycle/Scooter Passenger"|t8_triplegmode`i'=="Motorcycle passenger"|t8_triplegmode`i'=="Motorcycle rider"|t8_triplegmode`i'=="Motorcycle/Scooter Rider"|t8_triplegmode`i'=="Taxi"|t8_triplegmode`i'=="Van / Lorry driver"|t8_triplegmode`i'=="Van / Lorry passenger"|t8_triplegmode`i'=="Van/Lorry Driver"|t8_triplegmode`i'=="Van/Lorry Passenger"
	replace trip_mode`i'="Cycle" if t8_triplegmode`i'=="Cycle"
}
////calculate the time spent on different mode
gen trip_time_Walk=0
gen trip_time_MRT=0
gen trip_time_Bus=0
gen trip_time_Car=0

local var "Walk MRT Bus Car"
foreach x in `var'{
	forval i = 0/9 {
    replace trip_time_`x'=trip_time_`x'+st14_invehtime`i' if trip_mode`i'=="`x'"
	}
}


egen total_time=rowtotal(st14_invehtime*)
gen t8_triplegmode = ""
gen st14_invehtime=.
////define the main mode as the mode with the most time spent during a trip
local var "Walk MRT Bus Car"
foreach x in `var'{
    replace t8_triplegmode = "`x'" if trip_time_`x' == ///
        max(trip_time_Walk, trip_time_MRT, trip_time_Bus,trip_time_Car) & ///
        !missing(trip_time_`x')
		
	replace st14_invehtime = trip_time_`x' if trip_time_`x' == ///
        max(trip_time_Walk, trip_time_MRT, trip_time_Bus,trip_time_Car) & ///
        !missing(trip_time_`x')

}


////define the dummy variable for main modes
//walk
gen dummy_walk_t8=1 if t8_triplegmode=="Walk"
replace dummy_walk_t8=0 if dummy_walk_t8==.&t8_triplegmode!=""
//mrt
gen dummy_mrt_t8=1 if t8_triplegmode=="MRT"
replace dummy_mrt_t8=0 if dummy_mrt_t8==.&t8_triplegmode!=""
//bus
cap: drop dummy_bus_t8
gen dummy_bus_t8=1 if t8_triplegmode=="Bus"
replace dummy_bus_t8=0 if dummy_bus_t8==.&t8_triplegmode!=""
//car
gen dummy_car_t8=1 if t8_triplegmode=="Car"
replace dummy_car_t8=0 if dummy_car_t8==.&t8_triplegmode!=""

// cap: drop distance_w
cap: drop time_diff_min_w
winsor2 time_diff_min max_mode, cut(5 95)

cap: drop control_trip
gen control_trip=time_diff_min_w


////define the dummy variable for first-mile modes before taking MRT
gen first_mode=""
gen first_triptime=.
forval i = 0/8 {
	local j=`i'+1
	replace first_mode=trip_mode`i' if trip_mode`j'=="MRT"&trip_mode`i'!="MRT"
	replace first_triptime=st14_invehtime`i' if trip_mode`j'=="MRT"&trip_mode`i'!="MRT"
}

forval i = 0/7 {
	local j=`i'+2
	local m=`i'+1
	replace first_mode=trip_mode`i' if trip_mode`j'=="MRT"&trip_mode`m'=="MRT"&first_mode==""&trip_mode`i'!="MRT"
	replace first_triptime=st14_invehtime`i' if trip_mode`j'=="MRT"&trip_mode`m'=="MRT"&first_mode==""&trip_mode`i'!="MRT"
}

forval i = 0/6 {
	local j=`i'+3
	local m=`i'+2
	local n=`i'+1
	replace first_mode=trip_mode`i' if trip_mode`j'=="MRT"&trip_mode`m'=="MRT"&first_mode==""&trip_mode`n'=="MRT"
	replace first_triptime=st14_invehtime`i' if trip_mode`j'=="MRT"&trip_mode`m'=="MRT"&first_mode==""&trip_mode`n'=="MRT"
}

drop if first_mode=="MRT"
//walk
gen walk_transfer=1 if first_mode=="Walk"|first_mode=="Cycle"
replace walk_transfer=0 if walk_transfer==.&first_mode!=""
//bus
gen bus_transfer=1 if first_mode=="Bus"
replace bus_transfer=0 if bus_transfer==.&first_mode!=""
//car
gen car_transfer=1 if first_mode=="Car"
replace car_transfer=0 if car_transfer==.&first_mode!=""

////merge with the daily climate data using Inverse-Distance-Weight
geonear survey_id latitude longitude using nea_climate.dta, n(station latitude_c longitude_c) wide near(5) genstub(bgid)
gen weight1=1/km_to_bgid1
gen weight2=1/km_to_bgid2
gen weight3=1/km_to_bgid3
gen weight4=1/km_to_bgid4
gen weight5=1/km_to_bgid5

forv i=1(1)5{
rename bgid`i' station
merge m:1 station stata_date using nea_climate.dta
drop if _merge==2
rename station bgid`i'
drop _merge
rename temp_month temp_month`i'
rename dewp_month dewp_month`i'
rename slp_month slp_month`i'
rename visib_month visib_month`i'
rename wdsp_month wdsp_month`i'
rename prcp_month prcp_month`i'
}
gen temp_idw=0
gen dewp_idw=0
gen slp_idw=0
gen visib_idw=0
gen wdsp_idw=0
gen prcp_idw=0
gen weight_temp=0
gen weight_dewp=0
gen weight_slp=0
gen weight_visib=0
gen weight_wdsp=0
gen weight_prcp=0
forv i=1(1)5{
gen temp_idw`i'=weight`i'*temp_month`i' if temp_month`i'!=.
replace weight_temp=weight_temp+weight`i' if temp_month`i'!=.
replace temp_idw=temp_idw+temp_idw`i' if temp_idw`i'!=.

gen dewp_idw`i'=weight`i'*dewp_month`i' if dewp_month`i'!=.
replace weight_dewp=weight_dewp+weight`i' if dewp_month`i'!=.
replace dewp_idw=dewp_idw+dewp_idw`i' if dewp_idw`i'!=.


gen slp_idw`i'=weight`i'*slp_month`i' if slp_month`i'!=.
replace weight_slp=weight_slp+weight`i' if slp_month`i'!=.
replace slp_idw=slp_idw+slp_idw`i' if slp_idw`i'!=.


gen visib_idw`i'=weight`i'*visib_month`i' if visib_month`i'!=.
replace weight_visib=weight_visib+weight`i' if visib_month`i'!=.
replace visib_idw=visib_idw+visib_idw`i' if visib_idw`i'!=.


gen wdsp_idw`i'=weight`i'*wdsp_month`i' if wdsp_month`i'!=.
replace weight_wdsp=weight_wdsp+weight`i' if wdsp_month`i'!=.
replace wdsp_idw=wdsp_idw+wdsp_idw`i' if wdsp_idw`i'!=.

gen prcp_idw`i'=weight`i'*prcp_month`i' if prcp_month`i'!=.
replace weight_prcp=weight_prcp+weight`i' if prcp_month`i'!=.
replace prcp_idw=prcp_idw+prcp_idw`i' if prcp_idw`i'!=.
}

replace temp_idw=. if (temp_idw==0)&(weight_temp==0)
replace dewp_idw=. if (dewp_idw==0)&(weight_dewp==0)
replace slp_idw=. if (slp_idw==0)&(weight_slp==0)
replace visib_idw=. if (visib_idw==0)&(weight_visib==0)
replace wdsp_idw=. if (wdsp_idw==0)&(weight_wdsp==0)
replace prcp_idw=. if (prcp_idw==0)&(weight_prcp==0)

gen temp=temp_idw/weight_temp
gen dewp=dewp_idw/weight_dewp
gen slp=slp_idw/weight_slp
gen visib=visib_idw/weight_visib
gen wdsp=wdsp_idw/weight_wdsp
gen prcp=prcp_idw/weight_prcp

drop temp_idw1-prcp_idw5
////drop if age below 14 years old
keep if age!=1
////drop if the person refused to answer the employment status
drop if p5_employ=="Refused"

gen year_mon=ym( year(stata_date),month( stata_date ) )
format year_mon %tm
