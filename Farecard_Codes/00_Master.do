// Sheltered walkway and travel behavior
// Farecard complementary analyses
// General setup
// Last edited: 13/10/2026

version 17
args project_root_arg

clear all
set more off
set varabbrev off
capture log close _all

if strtrim(`"`project_root_arg'"') == "" {
    display as error "Pass the project root as the first argument."
    exit 198
}

local project_root = subinstr(strtrim(`"`project_root_arg'"'),"\","/",.)
local restricted_dir "`project_root'/Data/Restricted Inputs"
local public_dir "`project_root'/Data/Public Inputs"
local work_dir "`project_root'/Data/Working Data"
local code_dir "`project_root'/Farecard_Codes"
local figure_dir "`project_root'/Figures"
local log_dir "`project_root'/Logs"

foreach file in transithub_v4.dta busstop_hubaffiliated_wk.dta ///
        "Bus routes_stop loc.csv" "Bus routes_stop seq.csv" {
    capture confirm file "`restricted_dir'/`file'"
    if _rc {
        display as error "Required restricted input not found: `restricted_dir'/`file'"
        exit 601
    }
}

foreach month in 03 04 05 07 08 09 10 11 12 {
    capture confirm file ///
        "`restricted_dir'/Farecard/origin_destination_bus_2019`month'.csv"
    if _rc {
        display as error "Required farecard input not found for 2019-`month'."
        exit 601
    }
}

foreach file in ///
        "`restricted_dir'/LTA Apr2022/CoveredLinkWay.shp" ///
        "`public_dir'/OSM/covered_20220101.shp" ///
        "`public_dir'/OSM/footway_fallback.shp" ///
        "`public_dir'/MP2019/subzone2019_shp.shp" {
    capture confirm file "`file'"
    if _rc {
        display as error "Required spatial input not found: `file'"
        exit 601
    }
}

local qgis_python : environment QGIS_PYTHON
if strtrim(`"`qgis_python'"') == "" {
    display as error "Set QGIS_PYTHON to the QGIS Python executable."
    exit 198
}

capture mkdir "`work_dir'"
capture mkdir "`figure_dir'"
capture mkdir "`log_dir'"
log using "`log_dir'/farecard_figure_rebuild.log", text replace

use "`restricted_dir'/transithub_v4.dta", clear
replace pt_code_hub = upper(strtrim(pt_code_hub))
replace pt_code_hub = "CE2-NS27" if inlist(pt_code_hub, ///
    "CE2-NS27-TE20", "NS27-CE2-TE20", "NS27-CE2")
isid pt_code_hub
assert !missing(pt_code_hub,hub_name,hub_long,hub_lat,hub_type)
assert inlist(hub_type,"MRT","MRT/LRT","LRT","BUS")
generate int policy_radius_m = cond(inlist(hub_type,"MRT","MRT/LRT"),400,200)
export delimited using "`work_dir'/transithub_v4_for_qgis.csv", replace

shell "`qgis_python'" "`code_dir'/01_build_hub_coverage.py" "`project_root'"
capture confirm file "`work_dir'/hub_coverage_apr22_osm22_5m.csv"
if _rc {
    display as error "Hub-level coverage data were not generated."
    exit 601
}

do "`code_dir'/02_build_farecard_working_data.do" "`project_root'"

shell "`qgis_python'" "`code_dir'/03_build_figure6_map.py" "`project_root'"
capture confirm file "`figure_dir'/figure6_spatial_distribution.qgz"
if _rc {
    display as error "Figure 6 QGIS project was not generated."
    exit 601
}

do "`code_dir'/04_build_figure7_plotting_data.do" "`project_root'"
do "`code_dir'/05_draw_figure7.do" "`project_root'"

foreach file in figure7_a.pdf figure7_b.pdf figure7_c.pdf ///
        figure7_d.pdf figure7_e.pdf figure7_f.pdf {
    capture confirm file "`figure_dir'/`file'"
    if _rc {
        display as error "Expected Figure 7 panel not found: `file'"
        exit 601
    }
}

display as result "FARECARD_FIGURE_REBUILD_COMPLETE"
log close
