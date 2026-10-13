# Linking Neighborhoods to Transit: Climate-Adaptive Mobility through Sheltered Walkways

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

The farecard master script expects the `QGIS_PYTHON` environment variable to identify the Python executable bundled with QGIS.

## Data

The analyses draw on the following data sources:

- Household Interview Travel Survey microdata and derived residential and transit-access measures.
- Bus farecard origin-destination records and supporting bus-route, bus-stop, and transit-hub files.
- The April 2022 Land Transport Authority (LTA) covered-linkway snapshot used in the study.
- OpenStreetMap covered-way and pedestrian-network data observed on 1 January 2022.
- Urban Redevelopment Authority Master Plan 2019 subzone boundaries.

The HITS microdata, farecard records, project-specific LTA snapshot, and other restricted supporting data are not redistributed in this repository. Full execution of the workflows therefore requires authorized access to the relevant source data. OpenStreetMap data are available under the [Open Database License](https://www.openstreetmap.org/copyright), and other source data should be obtained from their original providers subject to the applicable access and licensing conditions.

For the farecard analysis, sheltered-walkway coverage combines the April 2022 LTA polygons with OpenStreetMap covered ways observed on 1 January 2022. This later-observed spatial measure is used to characterize hub-level coverage and is not interpreted as verified 2019 coverage or as a segment-level inventory of infrastructure delivered exclusively under the Walk2Ride Programme.

## Citation

Citation metadata are provided in `CITATION.cff`. After the versioned release is archived, please cite the specific software version using the DOI shown in its archival record. Please also cite the associated manuscript:

> Gao, Qiuxia, Kwan Ok Lee, Minghang Yu, and Shuting Zhang. "Linking Neighborhoods to Transit: Climate-Adaptive Mobility through Sheltered Walkways." Manuscript.

## License

The source code in this repository is available under the [MIT License](LICENSE). This license applies only to the code in this repository and does not grant rights to any third-party or restricted data used in the study. Those data remain subject to the terms of their respective providers.

## Contact

Questions about the repository may be directed to Kwan Ok Lee at `kwan.lee@nus.edu.sg`.
