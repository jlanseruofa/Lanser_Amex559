*** Joseph Lanser ***
*** Doing some prelim analysis on my 1 percent rolled up and cleaned dataset ***


* Open cleaned dataset from box *

clear all

* --------- settings (same base as your working raw path) ---------
local HOME : env HOME
local box  "`HOME'/Library/CloudStorage/Box-Box"

* Target folder inside Amex_2025_Class
local outdir "`box'/Amex_2025_Class/Joseph"

* --------- load the cleaned rolled dataset ---------
use "`outdir'/Cleaned_Rolled_Joseph.dta", clear

* Quick checks
describe
summarize
count
