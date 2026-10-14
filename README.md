# Linking Neighborhoods to Transit: Climate-Adaptive Mobility through Sheltered Walkways

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.23355220.svg)](https://doi.org/10.5281/zenodo.23355220)

This repository contains code accompanying the manuscript *Linking Neighborhoods to Transit: Climate-Adaptive Mobility through Sheltered Walkways* by Qiuxia Gao, Kwan Ok Lee, Minghang Yu, and Shuting Zhang.


## Overview


The repository is organized into two analytical modules:


- `HITS_Codes` contains the household-level analysis based on Singapore's Household Interview Travel Survey (HITS), including the difference-in-differences estimates reported in the main text and Supplementary Information.
- `Farecard_Codes` constructs hub-level sheltered-walkway coverage and bus-flow measures and produces the analyses reported in Figures 6 and 7.


## Repository Structure


```text
.
|-- HITS_Codes/
|   |-- 00_main.do
|   |-- 01_process_data.do
|   |-- 02_main_table.do
|   |-- 03_main_figure.do
|   `-- 04_supple_infor.do
|-- Farecard_Codes/
|   |-- 00_Master.do
|   |-- 01_build_hub_coverage.py
|   |-- 02_build_farecard_working_data.do
|   |-- 03_build_figure6_map.py
|   |-- 04_build_figure7_plotting_data.do
|   `-- 05_draw_figure7.do
|-- CITATION.cff
|-- LICENSE
|-- .gitignore
`-- README.md
```


### HITS Analysis


- `00_main.do` defines the project directories and calls the HITS scripts in sequence.
- `01_process_data.do` merges the analysis inputs and constructs the variables used in the household-level analysis.
- `02_main_table.do` estimates the main regression specifications and exports the associated table components.
- `03_main_figure.do` produces the main HITS-based figures and additional robustness results.
- `04_supple_infor.do` produces supplementary analyses, figures, and table components.


### Farecard Analysis


- `00_Master.do` coordinates the Figure 6 and Figure 7 workflow.
- `01_build_hub_coverage.py` constructs hub-level sheltered-walkway coverage measures.
- `02_build_farecard_working_data.do` processes the farecard records and creates the common working data for Figures 6 and 7.
- `03_build_figure6_map.py` aggregates the hub measures to subzones and creates the editable QGIS project for Figure 6.
- `04_build_figure7_plotting_data.do` estimates the reported hub-level associations and creates the plotting data for Figure 7.
- `05_draw_figure7.do` exports Figure 7 panels a-f.


## Manuscript Output Crosswalk


| Code | Related manuscript outputs |
| --- | --- |
| `HITS_Codes/02_main_table.do` | Tables 1, 2, and S5 |
| `HITS_Codes/03_main_figure.do` | Figures 3-5 and Tables S8-S11 |
| `HITS_Codes/04_supple_infor.do` | Tables S3-S4 and S6; Figures S2-S3 |
| `Farecard_Codes/01_build_hub_coverage.py` to `05_draw_figure7.do` | Figures 6 and 7 |


The scripts produce the analytical results and source components used to assemble the manuscript tables and figures. Final formatting follows the layout of the manuscript and Supplementary Information.


## Software Requirements


- Stata 17 or later.
- Python 3.
- QGIS with Python bindings for the geospatial components of the farecard workflow.
- The following user-contributed Stata commands: `reghdfe`, `estout`, `coefplot`, `parmest`, `geonear`, and `winsor2`.
