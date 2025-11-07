*** Joseph Lanser | AREC 559
*** Logistic model with only cdss, tsr, and portfolio variables



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

drop fico num_products d_train bal_due bal_over_expr tenure cs_other cs_low_balance cs_currents cs_seg_a cs_high_balance cs_cfs_team cs_arct_team d_chrg_lend d_chrg


* --- run logit (edit RHS as needed) ---
logit roll_forward cdss d_cdss_zero d_cdss_nines cdss_sq

* --- average marginal effects (delta method is the default) ---
margins, dydx(*)
* (Output header will say "Delta-method")

* AUC
lroc













version 18.5
clear all
set more off
set seed 42

// =========================================================================
// =============== RUN 1: CONSUMER (FINAL_CONS.dta) ====================
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

drop fico num_products d_train bal_due bal_over_expr tenure cs_other cs_low_balance cs_currents cs_seg_a cs_high_balance cs_cfs_team cs_arct_team d_chrg_lend d_chrg


* --- run logit (edit RHS as needed) ---
logit roll_forward cdss d_cdss_zero d_cdss_nines cdss_sq

* --- average marginal effects (delta method is the default) ---
margins, dydx(*)
* (Output header will say "Delta-method")

* AUC
lroc

