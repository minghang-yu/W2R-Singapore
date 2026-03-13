use  HITS_combine_three.dta, clear
**processing
do 01_process_data.do

**create tables in the main text, Table 1 and Table 2
do 02_main_table.do

**create figures in the main text, Figure 4, Figure 5 and Figure 6
do 03_main_figure.do

**create tables in the supplementary, Table S1-S9
do 04_supple_table.do
