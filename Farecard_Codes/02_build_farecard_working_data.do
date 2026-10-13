// Sheltered walkway and travel behavior
// Farecard complementary analyses
// Farecard working datasets cleaning
// Last edited: 13/10/2026

/*
Build the farecard working data used by manuscript Figures 6 and 7.

Exposure: Apr2022 LTA sheltered-walkway snapshot plus 2022-01-01 OSM covered
ways, matched to the common fallback footway network with a 5 m tolerance.

Figure 7 panels a-b compare route<=800 m flows inside and outside the applicable
policy radius. Both use all hub-associated endpoint flows as the denominator.

Figure 7 panels c-f use these weekday periods:
  1 AM peak                   06:00-09:59
  2 Daytime off-peak          10:00-15:59
  3 PM peak                   16:00-19:59
  4 Nighttime off-peak        20:00-00:59
Hourly bins 01:00-05:59 are retained for accounting QA but excluded from the
four-period analysis dataset.
No graph or regression is produced here.
*/

version 17
args project_root_arg

clear all
set more off
set varabbrev off

if strtrim(`"`project_root_arg'"') == "" {
    display as error "Pass the project root as the first argument."
    exit 198
}

local project_root = subinstr(strtrim(`"`project_root_arg'"'),"\","/",.)
global FIG7_DATA "`project_root'/Data/Restricted Inputs"
global FIG7_WORK "`project_root'/Data/Working Data"

capture confirm file "$FIG7_DATA/transithub_v4.dta"
if _rc {
    display as error "Required input not found: $FIG7_DATA/transithub_v4.dta"
    exit 601
}

capture mkdir "$FIG7_WORK"

* -----------------------------------------------------------------------------
* 1. Unique hub master, hub-stop map, bus-stop coordinates, and exposure.
* -----------------------------------------------------------------------------
use "$FIG7_DATA/transithub_v4.dta", clear
rename pt_code_hub hub_code
replace hub_code = upper(strtrim(hub_code))
replace hub_code = "CE2-NS27" if inlist(hub_code, ///
    "CE2-NS27-TE20", "NS27-CE2-TE20", "NS27-CE2")
isid hub_code
assert !missing(hub_code,hub_name,hub_lat,hub_long,hub_type)
assert inlist(hub_type,"MRT","MRT/LRT","LRT","BUS")
gen int policy_radius_m = cond(inlist(hub_type,"MRT","MRT/LRT"),400,200)
assert policy_radius_m == 400 if inlist(hub_type,"MRT","MRT/LRT")
assert policy_radius_m == 200 if inlist(hub_type,"LRT","BUS")
keep hub_code hub_name hub_lat hub_long hub_type policy_radius_m
tempfile hubs
save `hubs'

use "$FIG7_DATA/busstop_hubaffiliated_wk.dta", clear
keep if hubstop == 1
keep hubstop_pt_code hubstn_pt_code
recast long hubstop_pt_code, force
replace hubstn_pt_code = upper(strtrim(hubstn_pt_code))
replace hubstn_pt_code = "CE2-NS27" if inlist(hubstn_pt_code, ///
    "CE2-NS27-TE20", "NS27-CE2-TE20", "NS27-CE2")
isid hubstop_pt_code
rename (hubstop_pt_code hubstn_pt_code) (origin_pt_code origin_hub)
tempfile origin_hub_map destination_hub_map
save `origin_hub_map'
rename (origin_pt_code origin_hub) ///
    (destination_pt_code destination_hub)
save `destination_hub_map'

import delimited using "$FIG7_DATA/Bus routes_stop loc.csv", ///
    varnames(1) case(lower) clear
rename (busstopcode latitude longitude) ///
    (nonhub_pt_code nonhub_lat nonhub_long)
destring nonhub_pt_code nonhub_lat nonhub_long, replace force
drop if missing(nonhub_pt_code)
recast long nonhub_pt_code, force
isid nonhub_pt_code
assert !missing(nonhub_lat,nonhub_long)
assert inrange(nonhub_lat,1.1,1.6)
assert inrange(nonhub_long,103.5,104.2)
keep nonhub_pt_code nonhub_lat nonhub_long
tempfile stop_coordinates
save `stop_coordinates'

import delimited using ///
    "$FIG7_WORK/hub_coverage_apr22_osm22_5m.csv", ///
    varnames(1) case(lower) clear
replace hub_code = upper(strtrim(hub_code))
replace hub_code = "CE2-NS27" if inlist(hub_code, ///
    "CE2-NS27-TE20", "NS27-CE2-TE20", "NS27-CE2")
isid hub_code
assert radius_m == 400 if inlist(hub_type,"MRT","MRT/LRT")
assert radius_m == 200 if inlist(hub_type,"LRT","BUS")
assert tolerance_m == 5
assert footway_denominator_m > 0
assert sheltered_union_numerator_m >= 0
assert sheltered_union_numerator_m <= footway_denominator_m + 1e-5
assert inrange(coverage_apr22_osm22_5m,0,1)
assert coverage_definition == ///
    "Apr2022_LTA_plus_OSM_20220101_5m_on_common_footway"
assert denominator_definition == "locally_available_OSM_footway_fallback"
rename radius_m coverage_policy_radius_m
keep hub_code coverage_policy_radius_m footway_denominator_m sheltered_union_numerator_m ///
    coverage_apr22_osm22_5m coverage_definition denominator_definition
tempfile coverage
save `coverage'

* -----------------------------------------------------------------------------
* 2. Complete directed minimum scheduled-route-distance crosswalk.
* -----------------------------------------------------------------------------
import delimited using "$FIG7_DATA/Bus routes_stop seq.csv", ///
    varnames(1) case(lower) clear
rename (bu busstopcode) (route pt_code)
destring pt_code distance direction, replace force
count if missing(route,pt_code,distance,direction)
display as text "ROUTE_INVALID_ROWS_DROPPED=" r(N)
drop if missing(route,pt_code,distance,direction)
recast long pt_code, force
assert distance >= 0

duplicates tag route direction pt_code distance, gen(exact_duplicate)
count if exact_duplicate > 0
display as text "ROUTE_ROWS_IN_EXACT_DUPLICATE_GROUPS=" r(N)
drop exact_duplicate

* Source order resolves tied cumulative distances; stop code is not a tie-breaker.
gen long source_order = _n
sort route direction distance source_order
by route direction: gen int stop_order = _n
isid route direction stop_order

preserve
    keep route direction stop_order pt_code distance
    rename (stop_order pt_code distance) ///
        (origin_order origin_pt_code origin_distance)
    tempfile origins
    save `origins'
restore
rename (stop_order pt_code distance) ///
    (destination_order destination_pt_code destination_distance)
joinby route direction using `origins'
keep if destination_order > origin_order
gen double route_distance_km = destination_distance-origin_distance
assert route_distance_km >= -1e-8
replace route_distance_km = 0 if abs(route_distance_km) < 1e-8
collapse (min) route_distance_km, ///
    by(origin_pt_code destination_pt_code)
isid origin_pt_code destination_pt_code
assert route_distance_km >= 0 & !missing(route_distance_km)
count
display as result "DIRECTED_ROUTE_CROSSWALK_PAIRS=" r(N)
tempfile route_crosswalk
save `route_crosswalk'

* -----------------------------------------------------------------------------
* 3. Process March-May and July-December 2019 one month at a time.
*    June is excluded because the supplied CSV is truncated/incomplete.
* -----------------------------------------------------------------------------
local first_month 1
tempfile all_direction_cells

display as text "FARECARD_MONTHS_INCLUDED=03 04 05 07 08 09 10 11 12"
display as text "FARECARD_MONTH_EXCLUDED=06 (truncated source file)"
foreach month in 3 4 5 7 8 9 10 11 12 {
    local mm : display %02.0f `month'
    local raw "$FIG7_DATA/Farecard/origin_destination_bus_2019`mm'.csv"
    capture confirm file "`raw'"
    if _rc {
        display as error "RAW_FARECARD_FILE_MISSING=2019-`mm'"
        exit 601
    }

    display as text "RAW_FARECARD_FILE_READ=2019-`mm'"
    import delimited using "`raw'", varnames(1) case(lower) clear
    count if year_month != "2019-`mm'"
    assert r(N) == 0
    count if upper(strtrim(pt_type)) != "BUS"
    display as text "RAW_NONBUS_OR_MALFORMED_ROWS_DROPPED_2019_`mm'=" r(N)
    drop if upper(strtrim(pt_type)) != "BUS"
    keep day_type time_per_hour origin_pt_code destination_pt_code total_trips
    destring time_per_hour origin_pt_code destination_pt_code total_trips, ///
        replace force
    count if missing(origin_pt_code,destination_pt_code,day_type, ///
        time_per_hour,total_trips)
    display as text "RAW_INVALID_ROWS_DROPPED_2019_`mm'=" r(N)
    drop if missing(origin_pt_code,destination_pt_code,day_type, ///
        time_per_hour,total_trips)
    assert total_trips >= 0
    assert inrange(time_per_hour,0,23)
    recast long origin_pt_code destination_pt_code, force
    replace day_type = upper(strtrim(day_type))
    assert inlist(day_type,"WEEKDAY","WEEKENDS/HOLIDAY")

    * Wide period totals preserve time-of-day information without carrying a
    * full hourly contact panel through the route and spatial merges.
    gen double trips_all_tod0 = total_trips* ///
        (day_type == "WEEKDAY" & inrange(time_per_hour,1,5))
    gen double trips_all_tod1 = total_trips* ///
        (day_type == "WEEKDAY" & inrange(time_per_hour,6,9))
    gen double trips_all_tod2 = total_trips* ///
        (day_type == "WEEKDAY" & inrange(time_per_hour,10,15))
    gen double trips_all_tod3 = total_trips* ///
        (day_type == "WEEKDAY" & inrange(time_per_hour,16,19))
    gen double trips_all_tod4 = total_trips* ///
        (day_type == "WEEKDAY" & ///
        (time_per_hour == 0 | inrange(time_per_hour,20,23)))
    assert abs(total_trips - trips_all_tod0 - trips_all_tod1 - ///
        trips_all_tod2 - trips_all_tod3 - trips_all_tod4) < 1e-8 ///
        if day_type == "WEEKDAY"

    collapse (sum) total_trips trips_all_tod0 trips_all_tod1 ///
        trips_all_tod2 trips_all_tod3 trips_all_tod4, ///
        by(day_type origin_pt_code destination_pt_code)
    gen int year = 2019
    gen byte month = `month'
    gen int ym = ym(year,month)
    format ym %tm

    merge m:1 origin_pt_code destination_pt_code using `route_crosswalk'
    tab _merge
    drop if _merge == 2
    gen byte route_matched = (_merge == 3)
    drop _merge

    merge m:1 origin_pt_code using `origin_hub_map'
    tab _merge
    drop if _merge == 2
    drop _merge
    merge m:1 destination_pt_code using `destination_hub_map'
    tab _merge
    drop if _merge == 2
    drop _merge
    gen byte both_hub_od = !missing(origin_hub) & !missing(destination_hub)

    tempfile mapped_od from_contacts towards_contacts
    save `mapped_od'

    keep if !missing(origin_hub)
    gen byte direction = 1
    rename origin_hub hub_code
    gen long nonhub_pt_code = destination_pt_code
    save `from_contacts'

    use `mapped_od', clear
    keep if !missing(destination_hub)
    gen byte direction = 2
    rename destination_hub hub_code
    gen long nonhub_pt_code = origin_pt_code
    save `towards_contacts'

    use `from_contacts', clear
    append using `towards_contacts'
    assert !missing(hub_code,ym,day_type,direction,total_trips)

    merge m:1 nonhub_pt_code using `stop_coordinates'
    tab _merge
    gen byte coordinate_matched = (_merge == 3)
    drop if _merge == 2
    drop _merge
    merge m:1 hub_code using `hubs'
    tab _merge
    assert _merge != 1
    drop if _merge == 2
    drop _merge

    gen double dlat = (nonhub_lat-hub_lat)*c(pi)/180 if coordinate_matched
    gen double dlon = (nonhub_long-hub_long)*c(pi)/180 if coordinate_matched
    gen double hav_a = sin(dlat/2)^2 + cos(hub_lat*c(pi)/180)* ///
        cos(nonhub_lat*c(pi)/180)*sin(dlon/2)^2 if coordinate_matched
    replace hav_a = min(1,max(0,hav_a)) if coordinate_matched
    gen double straight_distance_km = ///
        2*6371.0088*asin(sqrt(hav_a)) if coordinate_matched
    assert straight_distance_km >= 0 if coordinate_matched
    drop dlat dlon hav_a

    gen byte route800 = route_matched & ///
        route_distance_km <= .8 + 1e-8
    gen byte inside_policy = coordinate_matched & ///
        straight_distance_km <= policy_radius_m/1000 + 1e-8
    gen byte outside_policy = coordinate_matched & ///
        straight_distance_km > policy_radius_m/1000 + 1e-8

    gen double trips_policy_r800 = total_trips*route800*inside_policy
    gen double trips_outside_policy_r800 = total_trips*route800*outside_policy
    gen double trips_coordmiss_r800 = ///
        total_trips*route800*(coordinate_matched == 0)
    gen double trips_route800 = total_trips*route800
    gen double trips_inside_policy_all = total_trips*inside_policy
    gen double trips_outside_policy_all = total_trips*outside_policy
    gen double trips_coordmiss_all = total_trips*(coordinate_matched == 0)
    gen double trips_route_matched = total_trips*route_matched
    gen double trips_both_hub = total_trips*both_hub_od
    forvalues period = 0/4 {
        gen double trips_short_tod`period' = ///
            trips_all_tod`period'*route800*inside_policy
        assert trips_short_tod`period' <= trips_all_tod`period'
    }

    assert abs(trips_policy_r800 + trips_outside_policy_r800 + ///
        trips_coordmiss_r800 - trips_route800) < 1e-6
    assert trips_policy_r800 <= total_trips
    assert trips_outside_policy_r800 <= total_trips

    collapse (sum) trips_all=total_trips trips_policy_r800 ///
        trips_outside_policy_r800 trips_coordmiss_r800 trips_route800 ///
        trips_inside_policy_all trips_outside_policy_all trips_coordmiss_all ///
        trips_route_matched trips_both_hub trips_all_tod0 ///
        trips_all_tod1 trips_all_tod2 trips_all_tod3 trips_all_tod4 ///
        trips_short_tod0 trips_short_tod1 trips_short_tod2 ///
        trips_short_tod3 trips_short_tod4, ///
        by(year month ym day_type hub_code hub_type policy_radius_m direction)
    isid hub_code ym day_type direction

    if `first_month' {
        save `all_direction_cells'
        local first_month 0
    }
    else {
        append using `all_direction_cells'
        save `all_direction_cells', replace
    }
}

* -----------------------------------------------------------------------------
* 4. Direction and combined hub-month-day-type working panels.
* -----------------------------------------------------------------------------
use `all_direction_cells', clear
isid hub_code ym day_type direction
assert month != 6
label define direction_label 1 "From hub" 2 "Towards hub", replace
label values direction direction_label

* -----------------------------------------------------------------------------
* 4A. Figure 7 panels c-f: weekday hub-month-period data.
* -----------------------------------------------------------------------------
preserve
    keep if day_type == "WEEKDAY"
    assert abs(trips_all - trips_all_tod0 - trips_all_tod1 - ///
        trips_all_tod2 - trips_all_tod3 - trips_all_tod4) < 1e-6
    assert abs(trips_policy_r800 - trips_short_tod0 - trips_short_tod1 - ///
        trips_short_tod2 - trips_short_tod3 - trips_short_tod4) < 1e-6

    reshape long trips_all_tod trips_short_tod, ///
        i(hub_code ym direction) j(period)
    assert inrange(period,0,4)
    drop if period == 0
    collapse (sum) trips_all=trips_all_tod ///
        trips_policy_r800=trips_short_tod, ///
        by(year month ym hub_code hub_type policy_radius_m period)
    isid hub_code ym period
    assert trips_all >= 0
    assert trips_policy_r800 >= 0 & trips_policy_r800 <= trips_all

    merge m:1 hub_code using `coverage'
    tab _merge
    assert _merge != 1
    drop if _merge == 2
    drop _merge
    assert coverage_policy_radius_m == policy_radius_m
    drop coverage_policy_radius_m
    keep if inlist(hub_type,"MRT","MRT/LRT","LRT")

    * A period share is undefined when its denominator is zero. Keep the four
    * period comparison balanced by dropping the full hub-month group rather
    * than recoding an undefined share to zero.
    bysort hub_code ym: egen byte zero_period_in_hubmonth = ///
        max(trips_all <= 0)
    count if zero_period_in_hubmonth
    display as text "FIGURE7_PANELS_CF_ROWS_DROPPED_ZERO_PERIOD_GROUP=" r(N)
    drop if zero_period_in_hubmonth
    drop zero_period_in_hubmonth
    bysort hub_code ym: assert _N == 4
    assert trips_all > 0

    egen long hub_id = group(hub_code)
    gen double coverage_pct = 100*coverage_apr22_osm22_5m
    gen double coverage_10pp = 10*coverage_apr22_osm22_5m
    gen double share_pp = 100*trips_policy_r800/trips_all
    gen byte farecard_source_warning = 0

    label define figure7_period_label 1 "AM peak" ///
        2 "Daytime off-peak" 3 "PM peak" ///
        4 "Nighttime off-peak", replace
    label values period figure7_period_label
    label data "Figure 7 panels c-f weekday hub-month-period data"
    label variable period ///
        "Weekday period; hourly bins 01:00-05:59 excluded"
    label variable coverage_pct ///
        "Apr2022 LTA + OSM2022 sheltered coverage, 5m tolerance (%)"
    label variable coverage_10pp ///
        "Sheltered coverage, 10-percentage-point units"
    label variable trips_all ///
        "All hub-associated endpoint flows in period"
    label variable policy_radius_m "Applicable W2R policy radius (m)"
    label variable trips_policy_r800 ///
        "Straight<=policy radius and route<=800m endpoint flows in period"
    label variable share_pp ///
        "Policy-area short-flow share within period (pp)"
    label variable farecard_source_warning ///
        "Source warning flag; June excluded because its CSV is truncated"

    assert inrange(share_pp,0,100)
    assert month != 6
    assert farecard_source_warning == 0
    assert !missing(hub_code,ym,period,trips_all,share_pp,coverage_pct, ///
        policy_radius_m)
    isid hub_code ym period
    bysort hub_code ym: assert _N == 4
    count
    local figure7_cells = r(N)
    count if hub_type == "LRT"
    assert r(N) > 0
    local figure7_lrt_cells = r(N)
    egen byte figure7_hub_tag = tag(hub_code)
    count if figure7_hub_tag
    local figure7_hubs = r(N)
    drop figure7_hub_tag

    order hub_code hub_id hub_type policy_radius_m year month ym period ///
        coverage_pct coverage_10pp trips_all trips_policy_r800 share_pp ///
        farecard_source_warning
    sort hub_code ym period
    compress
    save "$FIG7_WORK/figure7_panels_cf_weekday_period_hubmonth.dta", replace
    display as result ///
        "FIGURE7_PANELS_CF_HUB_MONTH_PERIOD_CELLS=`figure7_cells'"
    display as result "FIGURE7_PANELS_CF_HUBS=`figure7_hubs'"
    display as result "FIGURE7_PANELS_CF_LRT_CELLS=`figure7_lrt_cells'"
restore

drop trips_all_tod0 trips_all_tod1 trips_all_tod2 trips_all_tod3 ///
    trips_all_tod4 trips_short_tod0 trips_short_tod1 ///
    trips_short_tod2 trips_short_tod3 trips_short_tod4

foreach numerator in trips_policy_r800 trips_outside_policy_r800 ///
        trips_coordmiss_r800 trips_route800 {
    local share = subinstr("`numerator'","trips_","share_",1)
    gen double `share'_pp = 100*`numerator'/trips_all
    assert inrange(`share'_pp,0,100)
}
gen double share_route800_given_inside_pp = ///
    100*trips_policy_r800/trips_inside_policy_all ///
    if trips_inside_policy_all > 0
gen double share_route800_given_outside_pp = ///
    100*trips_outside_policy_r800/trips_outside_policy_all ///
    if trips_outside_policy_all > 0
assert inrange(share_route800_given_inside_pp,0,100) ///
    if !missing(share_route800_given_inside_pp)
assert inrange(share_route800_given_outside_pp,0,100) ///
    if !missing(share_route800_given_outside_pp)

merge m:1 hub_code using `coverage'
tab _merge
assert _merge != 1
drop if _merge == 2
drop _merge
assert coverage_policy_radius_m == policy_radius_m
drop coverage_policy_radius_m
gen byte rail_policy_sample = inlist(hub_type,"MRT","MRT/LRT","LRT")
egen long hub_id = group(hub_code)
encode day_type, gen(day_type_id)
gen double coverage_pct = 100*coverage_apr22_osm22_5m
gen double coverage_10pp = 10*coverage_apr22_osm22_5m
label variable coverage_pct ///
    "Apr2022 LTA + OSM2022 sheltered coverage, 5m tolerance (%)"
label variable coverage_10pp "Sheltered coverage, 10-percentage-point units"
label variable policy_radius_m "Applicable W2R policy radius (m)"
label variable share_policy_r800_pp ///
    "Figure 7a: straight<=policy radius & route<=800m share (pp)"
label variable share_outside_policy_r800_pp ///
    "Figure 7b: straight>policy radius & route<=800m share (pp)"
compress

collapse (sum) trips_all trips_policy_r800 trips_outside_policy_r800 ///
    trips_coordmiss_r800 trips_route800 trips_inside_policy_all ///
    trips_outside_policy_all trips_coordmiss_all trips_route_matched ///
    trips_both_hub, ///
    by(year month ym day_type hub_code hub_type policy_radius_m hub_id ///
       day_type_id rail_policy_sample coverage_apr22_osm22_5m coverage_pct ///
       coverage_10pp ///
       footway_denominator_m sheltered_union_numerator_m ///
       coverage_definition denominator_definition)
isid hub_code ym day_type
assert abs(trips_policy_r800 + trips_outside_policy_r800 + ///
    trips_coordmiss_r800 - trips_route800) < 1e-6
gen byte farecard_source_warning = 0
label variable farecard_source_warning ///
    "Source warning flag; June excluded because its CSV is truncated"

gen double share_policy_r800_pp = 100*trips_policy_r800/trips_all
gen double share_outside_policy_r800_pp = ///
    100*trips_outside_policy_r800/trips_all
gen double share_coordmiss_r800_pp = 100*trips_coordmiss_r800/trips_all
gen double share_route800_pp = 100*trips_route800/trips_all
gen double share_route800_given_inside_pp = ///
    100*trips_policy_r800/trips_inside_policy_all ///
    if trips_inside_policy_all > 0
gen double share_route800_given_outside_pp = ///
    100*trips_outside_policy_r800/trips_outside_policy_all ///
    if trips_outside_policy_all > 0

assert inrange(share_policy_r800_pp,0,100)
assert inrange(share_outside_policy_r800_pp,0,100)
assert inrange(share_route800_pp,0,100)
assert abs(share_policy_r800_pp + share_outside_policy_r800_pp + ///
    share_coordmiss_r800_pp - share_route800_pp) < 1e-8

label data "Figure 7 hub-month-day-type data; Mar-May and Jul-Dec 2019"
label variable coverage_pct ///
    "Apr2022 LTA + OSM2022 sheltered coverage, 5m tolerance (%)"
label variable coverage_10pp "Sheltered coverage, 10-percentage-point units"
label variable policy_radius_m "Applicable W2R policy radius (m)"
label variable share_policy_r800_pp ///
    "Figure 7a: straight<=policy radius & route<=800m share (pp)"
label variable share_outside_policy_r800_pp ///
    "Figure 7b: straight>policy radius & route<=800m share (pp)"
label variable trips_all "All hub-associated endpoint flows"

keep if rail_policy_sample == 1
isid hub_code ym day_type
assert month != 6
assert farecard_source_warning == 0
assert !missing(hub_code,ym,day_type,trips_all,coverage_apr22_osm22_5m, ///
    policy_radius_m)
assert trips_all > 0
count
display as result "FINAL_MRT_LRT_HUB_MONTH_DAYTYPE_CELLS=" r(N)
count if hub_type == "LRT"
assert r(N) > 0
display as result "FINAL_LRT_HUB_MONTH_DAYTYPE_CELLS=" r(N)
quietly summarize share_policy_r800_pp
display as result "FINAL_CELL_EQUAL_MEAN_POLICY_R800_SHARE_PP=" %12.8f r(mean)
if round(r(mean),.01) != 2.29 {
    display as error "Cell-equal within-policy short-flow mean does not round to 2.29%."
    exit 459
}
sort hub_code ym day_type
compress

* Long hub-month data for Figure 7 panels a-b.
preserve
    keep hub_code hub_id hub_type year month ym day_type day_type_id ///
        policy_radius_m coverage_apr22_osm22_5m coverage_pct coverage_10pp ///
        trips_all farecard_source_warning share_policy_r800_pp ///
        share_outside_policy_r800_pp coverage_definition ///
        denominator_definition
    reshape long share_, i(hub_code ym day_type) j(panel_key) string
    gen byte panel = cond(panel_key == "policy_r800_pp",1,2)
    assert inlist(panel,1,2)
    label define panel_label 1 "Policy-area short flows" ///
        2 "Outside-policy-area short flows", replace
    label values panel panel_label
    rename share_ share_pp
    drop panel_key
    isid hub_code ym day_type panel
    label variable share_pp "Hub-associated flow share (pp)"
    save "$FIG7_WORK/figure7_panels_ab_hubmonth.dta", replace
restore

* One pooled observation per hub for the Figure 6 subzone aggregation.
collapse (sum) trips_all trips_policy_r800 trips_outside_policy_r800 ///
    trips_route800 trips_inside_policy_all trips_outside_policy_all ///
    (max) farecard_source_warning ///
    (firstnm) coverage_apr22_osm22_5m coverage_pct coverage_10pp ///
    footway_denominator_m sheltered_union_numerator_m, ///
    by(hub_code hub_id hub_type policy_radius_m)
isid hub_code
gen double share_policy_r800_pp = 100*trips_policy_r800/trips_all
gen double share_outside_policy_r800_pp = ///
    100*trips_outside_policy_r800/trips_all
gen double share_route800_pp = 100*trips_route800/trips_all
gen double share_route800_given_inside_pp = ///
    100*trips_policy_r800/trips_inside_policy_all ///
    if trips_inside_policy_all > 0
gen double share_route800_given_outside_pp = ///
    100*trips_outside_policy_r800/trips_outside_policy_all ///
    if trips_outside_policy_all > 0
assert inrange(share_policy_r800_pp,0,100)
assert inrange(share_outside_policy_r800_pp,0,100)
sort hub_code
label data "Figure 6 pooled-hub data; Mar-May and Jul-Dec 2019"
export delimited using ///
    "$FIG7_WORK/figure6_hub_pooled_working.csv", replace

count
display as result "FINAL_MRT_LRT_HUBS=" r(N)
quietly summarize coverage_apr22_osm22_5m
display as result "FINAL_MEAN_COVERAGE_RATIO=" r(mean)
quietly summarize share_policy_r800_pp
display as result "FINAL_POOLED_MEAN_FIGURE7A_SHARE_PP=" r(mean)
quietly summarize share_outside_policy_r800_pp
display as result "FINAL_POOLED_MEAN_FIGURE7B_SHARE_PP=" r(mean)
display as result "FARECARD_WORKING_DATA_COMPLETE"
