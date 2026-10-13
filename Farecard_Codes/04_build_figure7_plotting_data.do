// Sheltered walkway and travel behavior
// Farecard complementary analyses
// Figure 7: Data processing
// Last edited: 13/10/2026

/* Build Figure 7 plotting data from the packaged analysis datasets. */

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
local data_dir "`project_root'/Data/Working Data"

foreach file in figure7_panels_ab_hubmonth.dta ///
        figure7_panels_cf_weekday_period_hubmonth.dta {
    capture confirm file "`data_dir'/`file'"
    if _rc {
        display as error "Required analysis data not found: `data_dir'/`file'"
        exit 601
    }
}

*******************************************************************************
* Panels a-b
*******************************************************************************

use "`data_dir'/figure7_panels_ab_hubmonth.dta", clear

isid hub_code ym day_type panel
assert inlist(panel,1,2)
assert inlist(hub_type,"MRT","MRT/LRT","LRT")
assert policy_radius_m == 400 if inlist(hub_type,"MRT","MRT/LRT")
assert policy_radius_m == 200 if hub_type == "LRT"
assert coverage_definition == ///
    "Apr2022_LTA_plus_OSM_20220101_5m_on_common_footway"
assert denominator_definition == "locally_available_OSM_footway_fallback"
assert month != 6
assert farecard_source_warning == 0
assert inrange(coverage_pct,0,100)
assert inrange(share_pp,0,100)
assert trips_all > 0
bysort hub_code ym day_type: assert _N == 2

tempfile bins1 bins2 regression_results
tempname result_post
postfile `result_post' str7 panel_name str80 outcome_definition ///
    double beta_10pp se_10pp ci_low_10pp ci_high_10pp p_value N hubs ///
    fit_intercept fit_slope_1pp using `regression_results', replace

forvalues p = 1/2 {
    preserve
        keep if panel == `p'
        isid hub_code ym day_type

        if `p' == 1 {
            local panel_name "Panel a"
            local outcome_definition ///
                "straight<=policy radius & route<=800m / all hub flows"
        }
        else {
            local panel_name "Panel b"
            local outcome_definition ///
                "straight>policy radius & route<=800m / all hub flows"
        }

        quietly regress share_pp c.coverage_10pp i.ym i.day_type_id, ///
            vce(cluster hub_id)
        local beta10 = _b[coverage_10pp]
        local se10 = _se[coverage_10pp]
        local pvalue = 2*ttail(e(df_r),abs(`beta10'/`se10'))
        local cilow = `beta10' - invttail(e(df_r),.025)*`se10'
        local cihigh = `beta10' + invttail(e(df_r),.025)*`se10'
        local n = e(N)
        local hubs = e(N_clust)

        quietly summarize share_pp, meanonly
        local ymean = r(mean)
        quietly regress share_pp i.ym i.day_type_id
        predict double share_residual, residuals
        generate double share_fe_adjusted = share_residual + `ymean'

        quietly summarize coverage_pct, meanonly
        local xmean = r(mean)
        quietly regress coverage_pct i.ym i.day_type_id
        predict double coverage_residual, residuals
        generate double coverage_fe_adjusted = coverage_residual + `xmean'

        quietly regress share_fe_adjusted c.coverage_fe_adjusted
        local fit_intercept = _b[_cons]
        local fit_slope = _b[coverage_fe_adjusted]
        assert abs(10*`fit_slope' - `beta10') < 1e-8

        quietly summarize coverage_fe_adjusted, meanonly
        local xmin = r(min)
        local xmax = r(max)

        xtile coverage_bin = coverage_fe_adjusted, nq(20)
        collapse (mean) coverage_bin_mean=coverage_fe_adjusted ///
            share_bin_mean=share_fe_adjusted ///
            (count) bin_n=share_fe_adjusted, by(coverage_bin)
        isid coverage_bin
        assert _N == 20

        generate byte panel = `p'
        generate double beta_10pp = `beta10'
        generate double se_10pp = `se10'
        generate double p_value = `pvalue'
        generate double fit_intercept = `fit_intercept'
        generate double fit_slope_1pp = `fit_slope'
        generate double fit_xmin = `xmin'
        generate double fit_xmax = `xmax'
        order panel coverage_bin coverage_bin_mean share_bin_mean bin_n
        save `bins`p'', replace

        post `result_post' ("`panel_name'") ("`outcome_definition'") ///
            (`beta10') (`se10') (`cilow') (`cihigh') (`pvalue') ///
            (`n') (`hubs') (`fit_intercept') (`fit_slope')
    restore
}

use `bins1', clear
append using `bins2'
isid panel coverage_bin
assert _N == 40
compress
save "`data_dir'/figure7_panels_ab_source.dta", replace

*******************************************************************************
* Panels c-f
*******************************************************************************

use "`data_dir'/figure7_panels_cf_weekday_period_hubmonth.dta", clear

isid hub_code ym period
assert inrange(period,1,4)
assert inlist(hub_type,"MRT","MRT/LRT","LRT")
assert policy_radius_m == 400 if inlist(hub_type,"MRT","MRT/LRT")
assert policy_radius_m == 200 if hub_type == "LRT"
assert coverage_definition == ///
    "Apr2022_LTA_plus_OSM_20220101_5m_on_common_footway"
assert denominator_definition == "locally_available_OSM_footway_fallback"
assert month != 6
assert farecard_source_warning == 0
assert inrange(coverage_pct,0,100)
assert inrange(share_pp,0,100)
assert trips_all > 0
bysort hub_code ym: assert _N == 4

quietly regress share_pp c.coverage_10pp##ib4.period i.ym, ///
    vce(cluster hub_id)
quietly test (1.period#c.coverage_10pp = 0) ///
    (2.period#c.coverage_10pp = 0) ///
    (3.period#c.coverage_10pp = 0)
local equality_p = r(p)

tempfile period1 period2 period3 period4
forvalues p = 1/4 {
    preserve
        keep if period == `p'
        isid hub_code ym

        quietly regress share_pp c.coverage_10pp i.ym, vce(cluster hub_id)
        local beta10 = _b[coverage_10pp]
        local se10 = _se[coverage_10pp]
        local pvalue = 2*ttail(e(df_r),abs(`beta10'/`se10'))
        local cilow = `beta10' - invttail(e(df_r),.025)*`se10'
        local cihigh = `beta10' + invttail(e(df_r),.025)*`se10'
        local n = e(N)
        local hubs = e(N_clust)

        local panel_letter : word `p' of c d e f
        local panel_name "Panel `panel_letter'"
        if `p' == 1 local period_name "AM peak"
        if `p' == 2 local period_name "Daytime off-peak"
        if `p' == 3 local period_name "PM peak"
        if `p' == 4 local period_name "Nighttime off-peak"
        local outcome_definition ///
            "within-policy-radius short-flow share, `period_name'"

        quietly summarize share_pp, meanonly
        local ymean = r(mean)
        quietly regress share_pp i.ym
        predict double share_residual, residuals
        generate double share_fe_adjusted = share_residual + `ymean'

        quietly summarize coverage_pct, meanonly
        local xmean = r(mean)
        quietly regress coverage_pct i.ym
        predict double coverage_residual, residuals
        generate double coverage_fe_adjusted = coverage_residual + `xmean'

        quietly regress share_fe_adjusted c.coverage_fe_adjusted
        local fit_intercept = _b[_cons]
        local fit_slope = _b[coverage_fe_adjusted]
        assert abs(10*`fit_slope' - `beta10') < 1e-8

        quietly summarize coverage_fe_adjusted, meanonly
        local xmin = r(min)
        local xmax = r(max)

        xtile coverage_bin = coverage_fe_adjusted, nq(20)
        collapse (mean) coverage_bin_mean=coverage_fe_adjusted ///
            share_bin_mean=share_fe_adjusted ///
            (count) bin_n=share_fe_adjusted, by(coverage_bin)
        isid coverage_bin
        assert _N == 20

        generate byte period = `p'
        generate double beta_10pp = `beta10'
        generate double se_10pp = `se10'
        generate double p_value = `pvalue'
        generate double equality_p = `equality_p'
        generate double fit_intercept = `fit_intercept'
        generate double fit_slope_1pp = `fit_slope'
        generate double fit_xmin = `xmin'
        generate double fit_xmax = `xmax'
        save `period`p'', replace

        post `result_post' ("`panel_name'") ("`outcome_definition'") ///
            (`beta10') (`se10') (`cilow') (`cihigh') (`pvalue') ///
            (`n') (`hubs') (`fit_intercept') (`fit_slope')
    restore
}

use `period1', clear
forvalues p = 2/4 {
    append using `period`p''
}
isid period coverage_bin
assert _N == 80
label define figure7_period_label ///
    1 "AM peak" ///
    2 "Daytime off-peak" ///
    3 "PM peak" ///
    4 "Nighttime off-peak", replace
label values period figure7_period_label
compress
save "`data_dir'/figure7_panels_cf_source.dta", replace

postclose `result_post'
use `regression_results', clear
format beta_10pp se_10pp ci_low_10pp ci_high_10pp p_value %9.4f
export delimited using ///
    "`data_dir'/figure7_plotting_residualized_regression_check.csv", replace

display as result "FIGURE7_PLOTTING_DATA_BUILD_COMPLETE"
