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







*------------------------------------------------------------
* Crosstabs: Scatter plots
*------------------------------------------------------------

tab slept_in_hot_temp d_finances_constr_ac_use, row col
tab slept_in_hot_temp perceived_risk_index, row col

tab ac_frac d_finances_constr_ac_use, row col
tab ac_frac perceived_risk_index, row col

tab d_non_ac_cool_methods d_finances_constr_ac_use, row col
tab d_non_ac_cool_methods perceived_risk_index, row col


scatter ac_frac heat_related_symptoms
corr ac_frac heat_related_symptoms


scatter slept_in_hot_temp exposure_index
scatter slept_in_hot_temp perceived_risk_index
corr slept_in_hot_temp perceived_risk_index
corr slept_in_hot_temp d_finances_constr_ac_use

scatter ac_frac exposure_index
scatter ac_frac perceived_risk_index
scatter ac_frac d_finances_constr_ac_use

scatter d_non_ac_cool_methods exposure_index
scatter d_non_ac_cool_methods perceived_risk_index
scatter d_non_ac_cool_methods d_finances_constr_ac_use


* Corr Coeffs
corr slept_in_hot_temp d_finances_constr_ac_use
corr slept_in_hot_temp exposure_index
corr slept_in_hot_temp perceived_risk_index

corr ac_frac d_finances_constr_ac_use
corr ac_frac exposure_index
corr ac_frac perceived_risk_index

corr d_non_ac_cool_methods d_finances_constr_ac_use
corr d_non_ac_cool_methods exposure_index
corr d_non_ac_cool_methods perceived_risk_index

