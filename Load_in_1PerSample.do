*** Joseph Lanser ***
*** Loading in 1 percent random sample of Amex Data ***




** Joseph Lanser — Load 1% Random Sample **

* --------- settings (same base as your working raw path) ---------
local HOME : env HOME
local box  "`HOME'/Library/CloudStorage/Box-Box"

* Swap Raw Data -> Random Samples
local proj_raw  "Amex_2025_Class/Raw Data"
local proj_rand : subinstr local proj_raw "Raw Data" "Random Samples", all

* --------- import the 1% sample CSV ---------
import delimited using "`box'/`proj_rand'/amex_1_pct.csv", varnames(1) clear

* (optional) save a .dta copy for fast reloads
compress
save "`box'/`proj_rand'/amex_1_pct.dta", replace

describe
count

