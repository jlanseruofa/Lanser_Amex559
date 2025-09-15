



clear all


*** Step 1: Load in .dta 1 percent data sample to be used ***
local HOME : env HOME
local box  "`HOME'/Library/CloudStorage/Box-Box"
local proj "Amex_2025_Class/Joseph"

use "`box'/`proj'/amex_1_pct.dta", clear
describe
count
