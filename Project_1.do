*** Joseph's Project 1 Stata Code ***
*** For 2025 AREC 559 Amex Class ***
*** In this code, I will work through the 1st class project questions in order ***




*** Step 1: Load in .dta 1 percent data sample to be used ***

* Base Box path
local HOME : env HOME
local box  "`HOME'/Library/CloudStorage/Box-Box"

* Point to your Joseph folder instead of Random Samples
local proj "Amex_2025_Class/Joseph"

* Load the saved .dta
use "`box'/`proj'/amex_1_pct.dta", clear

describe
count



*** 1a. Number of Unique Triplicates ***
* If triplicate is a string, normalize a bit (optional but helps)
capture confirm string variable triplicate
if !_rc {
    replace triplicate = lower(strtrim(triplicate))
}

* Count unique non-missing values (robust, no limits)
bysort triplicate: gen byte __tag = (_n==1) if !missing(triplicate)
quietly count if __tag
di as result "Unique triplicate values (non-missing): " r(N)
drop __tag




*** 1b. Earliest and latest case open and case closed Dates ***
*** EN means case opened, RI means case closed. Look at that using the act_dt date variable ***
* Convert act_dt from string to Stata daily date
gen double act_date = date(act_dt, "YMD")
format act_date %td

* Earliest case opened (EN)
summarize act_date if act_type_cd=="EN", meanonly
di as result "Earliest case OPEN date: " %td r(min)
di as result "Latest  case OPEN date: " %td r(max)

* Earliest case closed (RI)
summarize act_date if act_type_cd=="RI", meanonly
di as result "Earliest case CLOSED date: " %td r(min)
di as result "Latest  case CLOSED date: " %td r(max)
