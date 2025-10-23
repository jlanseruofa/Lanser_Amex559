*------------------------------------------------------------
* Project: PR Heat Survey
* Created on: Oct 2025
* Created by: Joseph Lanser and Anna Josephson
* Edited on: 23 Oct 2025
* Edited by: JL
* Stata v.18.5
*
* Does:
*   - Gets summary stats and graphs for new cleaned dataset
*------------------------------------------------------------


clear all
use "$data/prheatsurvey_clean_oct25.dta", clear


*------------------------------------------------------------
* Summary stats: mean, median, p25, p75, min, max, sd
*------------------------------------------------------------

* Get variable list
quietly ds
local vars `r(varlist)'
local nvars : word count `vars'

* Create an empty matrix (rows = # of vars, cols = 7 stats)
tempname stats
matrix define `stats' = J(`nvars', 7, .)

local row = 1

foreach v of local vars {
    quietly summarize `v', detail
    matrix `stats'[`row',1] = r(mean)
    matrix `stats'[`row',2] = r(p25)
    matrix `stats'[`row',3] = r(p50)
    matrix `stats'[`row',4] = r(p75)
    matrix `stats'[`row',5] = r(min)
    matrix `stats'[`row',6] = r(max)
    matrix `stats'[`row',7] = r(sd)
    local ++row
}

* Label columns and rows
matrix colnames `stats' = Mean P25 Median P75 Min Max SD
matrix rownames `stats' = `vars'

* Display nicely
matlist `stats', format(%9.3f)

* Optional: Export to CSV
clear
svmat double `stats', names(col)
gen variable = ""
local i = 1
foreach v of local vars {
    replace variable = "`v'" in `i'
    local ++i
}
order variable Mean P25 Median P75 Min Max SD
export delimited summary_stats.csv, replace
