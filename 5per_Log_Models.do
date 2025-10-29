*** This file will run Log Models on the 5% dataset ***
*** Joseph Lanser ***
*** AREC 559 ***




******************************************************
* Load data and run two logistic models
* - Split: 70/30 train/test (stratified)
* - Subsets: Consumers (d_consumer==1), Small Business (d_consumer==0)
* - DV: roll_forward
* - IVs: all except d_consumer itself
* - Output: AUC for train/test for each group
******************************************************

clear all
set more off
set seed 42

* --------- settings (same base as your working raw path) ---------
local HOME : env HOME
local box  "`HOME'/Library/CloudStorage/Box-Box"

* Target folder inside Amex_2025_Class
local outdir "`box'/Amex_2025_Class/Joseph"

* --------- load dataset ---------
use "`outdir'/5per_MLA_Cleaned_Rolled_Joseph.dta", clear


******************************************************
* DEFINE MACRO FOR EXPLANATORY VARIABLES
******************************************************
local xvars cdss fico
******************************************************
* --- MODEL 1: CONSUMER (d_consumer == 1) ---
******************************************************
preserve
keep if d_consumer == 1
tempvar u1
bysort roll_forward: gen double `u1' = runiform()
gen byte train = (`u1' < 0.70)

* Fit model on train
logit roll_forward `xvars' if train == 1
predict phat if e(sample), pr   // restrict to estimation sample only

* AUC - Train
quietly roctab roll_forward phat if train == 1
local auc_train_cons = r(area)

* AUC - Test
predict phat_all, pr   // predictions for everyone
quietly roctab roll_forward phat_all if train == 0
local auc_test_cons = r(area)

* Display
di as txt "---------------------------------------------"
di as txt "CONSUMER MODEL (d_consumer==1)"
di as txt "AUC (Train, 70%): " as res %6.3f `auc_train_cons'
di as txt "AUC (Test,  30%): " as res %6.3f `auc_test_cons'
di as txt "---------------------------------------------"

restore

******************************************************
* --- MODEL 2: SMALL BUSINESS (d_consumer == 0) ---
******************************************************
keep if d_consumer == 0
tempvar u2
bysort roll_forward: gen double `u2' = runiform()
gen byte train = (`u2' < 0.70)

* Fit model on train
logit roll_forward `xvars' if train == 1
predict phat if e(sample), pr

* AUC - Train
quietly roctab roll_forward phat if train == 1
local auc_train_sb = r(area)

* AUC - Test
predict phat_all, pr
quietly roctab roll_forward phat_all if train == 0
local auc_test_sb = r(area)

* Display
di as txt "---------------------------------------------"
di as txt "SMALL BUSINESS MODEL (d_consumer==0)"
di as txt "AUC (Train, 70%): " as res %6.3f `auc_train_sb'
di as txt "AUC (Test,  30%): " as res %6.3f `auc_test_sb'
di as txt "---------------------------------------------"
