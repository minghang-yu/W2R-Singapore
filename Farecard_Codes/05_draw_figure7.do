// Sheltered walkway and travel behavior
// Farecard complementary analyses
// Figure 7: Visualization
// Last edited: 13/10/2026

/* Draw Figure 7 panels from the fixed plotting datasets. */

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
local figure_dir "`project_root'/Figures"

foreach file in figure7_panels_ab_source.dta figure7_panels_cf_source.dta {
    capture confirm file "`data_dir'/`file'"
    if _rc {
        display as error "Required plotting data not found: `file'"
        display as error "Run 04_build_figure7_plotting_data.do first."
        exit 601
    }
}

capture mkdir "`figure_dir'"

*******************************************************************************
* Panels a-b
*******************************************************************************

use "`data_dir'/figure7_panels_ab_source.dta", clear
isid panel coverage_bin
assert _N == 40

forvalues p = 1/2 {
    local letter : word `p' of a b
    foreach parameter in fit_intercept fit_slope_1pp fit_xmin fit_xmax p_value {
        quietly summarize `parameter' if panel == `p', meanonly
        local parameter_n = r(N)
        local parameter_min = r(min)
        local parameter_max = r(max)
        local `parameter' = r(mean)
        assert `parameter_n' == 20 & `parameter_min' == `parameter_max'
    }

    local intercept = `fit_intercept'
    local slope = `fit_slope_1pp'
    local xmin = `fit_xmin'
    local xmax = `fit_xmax' - 7
    local pval = `p_value'
    local slope_label : display %5.3f `slope'
    if `pval' < 0.001 local p_label "p < 0.001"
    else {
        local p_value_label : display %5.3f `pval'
        local p_label "p = `p_value_label'"
    }

    if `p' == 1 {
        local text_y1 4
        local text_y2 3.25
    }
    else {
        local text_y1 10.5
        local text_y2 9.75
    }

    twoway ///
        (scatter share_bin_mean coverage_bin_mean if panel == `p', ///
            msymbol(O) msize(small) mcolor(navy%85)) ///
        (function y=`intercept'+`slope'*x, range(`xmin' `xmax') ///
            lcolor(maroon) lwidth(medthick)), ///
        xtitle("Sheltered walkway coverage (%, FE-adjusted)", size(vsmall)) ///
        ytitle("Hub-associated bus-flow share (%, FE-adjusted)", ///
            size(vsmall)) ///
        xlabel(0(5)50, format(%3.0f) labsize(vsmall)) ///
        ylabel(0(5)20, format(%4.1f) labsize(vsmall) angle(horizontal)) ///
        legend(off) aspectratio(1) xsize(5) ysize(5) ///
        text(`text_y1' 47.5 "Slope: `slope_label'", ///
            place(n) size(vsmall) color(black)) ///
        text(`text_y2' 47.5 "`p_label'", ///
            place(n) size(vsmall) color(black)) ///
        plotregion(margin(small) color(white)) ///
        graphregion(margin(small) color(white)) ///
        name(figure7_panel_`letter', replace)

    graph export "`figure_dir'/figure7_`letter'.png", ///
        name(figure7_panel_`letter') width(1800) replace
    graph export "`figure_dir'/figure7_`letter'.pdf", ///
        name(figure7_panel_`letter') replace
    graph close figure7_panel_`letter'
}

*******************************************************************************
* Panels c-f
*******************************************************************************

use "`data_dir'/figure7_panels_cf_source.dta", clear
isid period coverage_bin
assert _N == 80

forvalues p = 1/4 {
    local letter : word `p' of c d e f
    foreach parameter in fit_intercept fit_slope_1pp fit_xmin fit_xmax p_value {
        quietly summarize `parameter' if period == `p', meanonly
        local parameter_n = r(N)
        local parameter_min = r(min)
        local parameter_max = r(max)
        local `parameter' = r(mean)
        assert `parameter_n' == 20 & `parameter_min' == `parameter_max'
    }

    local intercept = `fit_intercept'
    local slope = `fit_slope_1pp'
    local xmin = `fit_xmin'
    local xmax = `fit_xmax' - 7
    local pval = `p_value'
    local slope_label : display %5.3f `slope'
    if `pval' < 0.001 local p_label "p < 0.001"
    else {
        local p_value_label : display %5.3f `pval'
        local p_label "p = `p_value_label'"
    }

    twoway ///
        (scatter share_bin_mean coverage_bin_mean if period == `p', ///
            msymbol(O) msize(small) mcolor(navy%85)) ///
        (function y=`intercept'+`slope'*x, range(`xmin' `xmax') ///
            lcolor(maroon) lwidth(medthick)), ///
        xtitle("Sheltered walkway coverage (%, FE-adjusted)", size(vsmall)) ///
        ytitle("Hub-associated bus-flow share (%, FE-adjusted)", ///
            size(vsmall)) ///
        xlabel(0(5)50, format(%3.0f) labsize(vsmall)) ///
        ylabel(0(2.5)10, format(%4.1f) labsize(vsmall) angle(horizontal)) ///
        legend(off) aspectratio(1) xsize(5) ysize(5) ///
        text(3.25 47.5 "Slope: `slope_label'", ///
            place(n) size(vsmall) color(black)) ///
        text(3  47.5 "`p_label'", ///
            place(n) size(vsmall) color(black)) ///
        plotregion(margin(small) color(white)) ///
        graphregion(margin(small) color(white)) ///
        name(figure7_panel_`letter', replace)

    graph export "`figure_dir'/figure7_`letter'.png", ///
        name(figure7_panel_`letter') width(1800) replace
    graph export "`figure_dir'/figure7_`letter'.pdf", ///
        name(figure7_panel_`letter') replace
    graph close figure7_panel_`letter'
}

display as result "FIGURE7_DRAW_COMPLETE"
