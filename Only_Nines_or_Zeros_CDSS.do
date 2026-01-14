*** Joseph Lanser | AREC 559
*** Log Models for when CDSS = Exactly 0 or .999


* SB .999
version 18.5
clear all
set more off
set seed 42

// =========================================================================
// =============== RUN 1: SMALL BUSINESS (FINAL_SB.dta) ====================
// =========================================================================
local HOME : env HOME
local box  "`HOME'/Library/CloudStorage/Box-Box"
local outdir "`box'/Amex_2025_Class/Joseph"
local datafile "`outdir'/FINAL_SB.dta"

di as txt "============================================================"
di as txt "Data: `datafile'"
di as txt "Model: LOGIT (train: d_train==1, validate: d_train==0)"
di as txt "============================================================"

use "`datafile'", clear
drop __000000
rename probc_score probc
drop if probc > 1
drop if probc < 0
drop if cdss < .999



* Log Full Model
logit roll_forward fico tsr probc num_products bal_due bal_over_expr tenure cs_other cs_low_balance cs_currents cs_seg_a cs_high_balance cs_cfs_team cs_arct_team d_chrg_lend d_chrg tsr_sq
margins, dydx(fico tsr probc num_products bal_due bal_over_expr tenure cs_other cs_low_balance cs_currents cs_seg_a cs_high_balance cs_cfs_team cs_arct_team d_chrg_lend d_chrg tsr_sq)
lroc














* CONS .999
version 18.5
clear all
set more off
set seed 42

// =========================================================================
// =============== RUN 2: Consumer (FINAL_CONS.dta) ====================
// =========================================================================
local HOME : env HOME
local box  "`HOME'/Library/CloudStorage/Box-Box"
local outdir "`box'/Amex_2025_Class/Joseph"
local datafile "`outdir'/FINAL_CONS.dta"

di as txt "============================================================"
di as txt "Data: `datafile'"
di as txt "Model: LOGIT (train: d_train==1, validate: d_train==0)"
di as txt "============================================================"

use "`datafile'", clear
drop if probc > 1
drop if probc < 0
drop if cdss < .999


* Log Full Model
logit roll_forward fico tsr probc num_products bal_due bal_over_expr tenure cs_other cs_low_balance cs_currents cs_seg_a cs_high_balance cs_cfs_team cs_arct_team d_chrg_lend d_chrg tsr_sq
margins, dydx(fico tsr probc num_products bal_due bal_over_expr tenure cs_other cs_low_balance cs_currents cs_seg_a cs_high_balance cs_cfs_team cs_arct_team d_chrg_lend d_chrg tsr_sq)
lroc














* SB 0
version 18.5
clear all
set more off
set seed 42

// =========================================================================
// =============== RUN 1: SMALL BUSINESS (FINAL_SB.dta) ====================
// =========================================================================
local HOME : env HOME
local box  "`HOME'/Library/CloudStorage/Box-Box"
local outdir "`box'/Amex_2025_Class/Joseph"
local datafile "`outdir'/FINAL_SB.dta"

di as txt "============================================================"
di as txt "Data: `datafile'"
di as txt "Model: LOGIT (train: d_train==1, validate: d_train==0)"
di as txt "============================================================"

use "`datafile'", clear
drop __000000
rename probc_score probc
drop if probc > 1
drop if probc < 0
drop if cdss > 0


* Log Full Model
logit roll_forward fico tsr probc num_products bal_due bal_over_expr tenure cs_other cs_low_balance cs_currents cs_seg_a cs_high_balance cs_cfs_team cs_arct_team d_chrg_lend d_chrg tsr_sq
margins, dydx(fico tsr probc num_products bal_due bal_over_expr tenure cs_other cs_low_balance cs_currents cs_seg_a cs_high_balance cs_cfs_team cs_arct_team d_chrg_lend d_chrg tsr_sq)
lroc










* CONS 0
version 18.5
clear all
set more off
set seed 42

// =========================================================================
// =============== RUN 2: Consumer (FINAL_CONS.dta) ====================
// =========================================================================
local HOME : env HOME
local box  "`HOME'/Library/CloudStorage/Box-Box"
local outdir "`box'/Amex_2025_Class/Joseph"
local datafile "`outdir'/FINAL_CONS.dta"

di as txt "============================================================"
di as txt "Data: `datafile'"
di as txt "Model: LOGIT (train: d_train==1, validate: d_train==0)"
di as txt "============================================================"

use "`datafile'", clear
drop if probc > 1
drop if probc < 0
drop if cdss > 0


* Log Full Model
logit roll_forward fico tsr probc num_products bal_due bal_over_expr tenure cs_other cs_low_balance cs_currents cs_seg_a cs_high_balance cs_cfs_team cs_arct_team d_chrg_lend d_chrg tsr_sq
margins, dydx(fico tsr probc num_products bal_due bal_over_expr tenure cs_other cs_low_balance cs_currents cs_seg_a cs_high_balance cs_cfs_team cs_arct_team d_chrg_lend d_chrg tsr_sq)
lroc












* SB 0 to 0.25
version 18.5
clear all
set more off
set seed 42

// =========================================================================
// =============== RUN 1: SMALL BUSINESS (FINAL_SB.dta) ====================
// =========================================================================
local HOME : env HOME
local box  "`HOME'/Library/CloudStorage/Box-Box"
local outdir "`box'/Amex_2025_Class/Joseph"
local datafile "`outdir'/FINAL_SB.dta"

di as txt "============================================================"
di as txt "Data: `datafile'"
di as txt "Model: LOGIT (train: d_train==1, validate: d_train==0)"
di as txt "============================================================"

use "`datafile'", clear
drop __000000
rename probc_score probc
drop if probc > 1
drop if probc < 0
drop if cdss > 0.25


* Log Full Model
logit roll_forward fico tsr probc num_products bal_due bal_over_expr tenure cs_other cs_low_balance cs_currents cs_seg_a cs_high_balance cs_cfs_team cs_arct_team d_chrg_lend d_chrg tsr_sq
margins, dydx(fico tsr probc num_products bal_due bal_over_expr tenure cs_other cs_low_balance cs_currents cs_seg_a cs_high_balance cs_cfs_team cs_arct_team d_chrg_lend d_chrg tsr_sq)
lroc










* CONS 0 to 0.25
version 18.5
clear all
set more off
set seed 42

// =========================================================================
// =============== RUN 2: Consumer (FINAL_CONS.dta) ====================
// =========================================================================
local HOME : env HOME
local box  "`HOME'/Library/CloudStorage/Box-Box"
local outdir "`box'/Amex_2025_Class/Joseph"
local datafile "`outdir'/FINAL_CONS.dta"

di as txt "============================================================"
di as txt "Data: `datafile'"
di as txt "Model: LOGIT (train: d_train==1, validate: d_train==0)"
di as txt "============================================================"

use "`datafile'", clear
drop if probc > 1
drop if probc < 0
drop __000000
drop if cdss > 0.25


* Log Full Model
logit roll_forward fico tsr probc num_products bal_due bal_over_expr tenure cs_other cs_low_balance cs_currents cs_seg_a cs_high_balance cs_cfs_team cs_arct_team d_chrg_lend d_chrg tsr_sq
margins, dydx(fico tsr probc num_products bal_due bal_over_expr tenure cs_other cs_low_balance cs_currents cs_seg_a cs_high_balance cs_cfs_team cs_arct_team d_chrg_lend d_chrg tsr_sq)
lroc
