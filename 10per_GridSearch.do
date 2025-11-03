*** Joseph Lanser ***
*** AREC 559 ***
*** This file will perform a grid search using the 10% data file with the same 70% 30# Train/Test Split ***
*** Data file courtesy of Nicole and Dr. Thompson, who saved me time not having to make it myself ***
*** Done separately for Consumers and Small Business ***








*** SMALL BUSINESS RANDOM FOREST ***
******************************************************
* RANDOM FOREST — Trimmed Grid (Forced Split via d_train)
* DV: roll_forward (0/1)
* Train: d_train==1 | Validation: d_train==0
* Grid: ntrees(100,250,500) × maxdepth(3,5,10,20) × mtry(3,5,8)
******************************************************

version 18.5
clear all
set more off
set seed 42

*--------------------------------------
* 0) Load data
*--------------------------------------
local HOME : env HOME
local box  "`HOME'/Library/CloudStorage/Box-Box"
local outdir "`box'/Amex_2025_Class/Joseph"
use "`outdir'/FINAL_SB.dta", clear

*--------------------------------------
* 1) Sanity checks
*--------------------------------------
capture confirm variable roll_forward
if _rc {
    di as err "DV roll_forward not found — stopping."
    exit 198
}

capture confirm variable d_train
if _rc {
    di as err "Split flag d_train not found — stopping."
    exit 198
}

capture confirm numeric variable roll_forward
if _rc {
    destring roll_forward, replace
}

assert inlist(roll_forward,0,1)

capture confirm variable __rowid
if _rc {
    gen long __rowid = _n
}

*--------------------------------------
* 2) Build predictor list X (exclude DV + non-features)
*--------------------------------------
local dep roll_forward
local dropvars d_train __rowid id account_id date_var cv5 d_consumer d_chrg d_chrg_lend

ds
local all `r(varlist)'
local X : list all - `dep'
foreach v of local dropvars {
    capture confirm variable `v'
    if !_rc {
        local X : list X - `v'
    }
}

* Optional: remove string predictors (uncomment if needed)
* foreach v of local X {
*     capture confirm string variable `v'
*     if !_rc {
*         local X : list X - `v'
*     }
* }

local k : word count `X'
di as txt "Predictor count: `k'"
if `k'==0 {
    di as err "No predictors after exclusions — stopping."
    exit 459
}

global Xvars `X'

*--------------------------------------
* 3) Materialize forced train/validation splits
*--------------------------------------
tempfile train_d valid_d yvalid_only

preserve
    keep if d_train==1
    count
    if r(N)==0 {
        di as err "No rows where d_train==1 — stopping."
        restore, not
        exit 459
    }
    save `train_d', replace
restore

preserve
    keep if d_train==0
    count
    if r(N)==0 {
        di as err "No rows where d_train==0 — stopping."
        restore, not
        exit 459
    }
    save `valid_d', replace
restore

use `valid_d', clear
keep __rowid roll_forward
save `yvalid_only', replace

*--------------------------------------
* 4) Start H2O and push frames
*--------------------------------------
cap h2o shutdown, force
h2o init

capture noisily _h2oframe remove train_h2o
capture noisily _h2oframe remove valid_h2o

use `train_d', clear
_h2oframe put, into(train_h2o) replace

use `valid_d', clear
_h2oframe put, into(valid_h2o) replace

_h2oframe change train_h2o
_h2oframe factor roll_forward, replace
_h2oframe change valid_h2o
_h2oframe factor roll_forward, replace

*--------------------------------------
* 5) Trimmed grid definitions
*--------------------------------------
local ntrees_list   100 250 500
local depth_list    3 5 10 20
local mtry_list     3 5 8

tempname results
capture postutil clear
postfile `results' int(ntrees maxdepth mtry) ///
    double(valid_auc valid_acc_p50 valid_f1_best valid_thresh_best) ///
    using rf_grid_forcedsplit_trimmed.dta, replace

*--------------------------------------
* 6) Grid loop with failure-safe continue
*--------------------------------------
foreach nt of local ntrees_list {
    foreach md of local depth_list {
        foreach mt of local mtry_list {

            di as text ">>> RF: ntrees=`nt' | maxdepth=`md' | mtry=`mt'"

            * -- Train (skip on failure)
            _h2oframe change train_h2o
            capture noisily h2oml rfbinclass roll_forward $Xvars, ///
                ntrees(`nt') maxdepth(`md') predsampvalue(`mt') ///
                h2orseed(42)
            local rc = _rc
            if `rc'!=0 {
                di as err "SKIP TRAIN: nt=`nt' md=`md' mt=`mt' (rc=`rc')"
                continue
            }

            * -- Predict on VALIDATION with a UNIQUE column name
            local prednm phat_v_nt`nt'_md`md'_mt`mt'
            _h2oframe change valid_h2o
            capture noisily h2omlpredict `prednm', pr
            local rc = _rc
            if `rc'!=0 {
                di as err "SKIP PRED : nt=`nt' md=`md' mt=`mt' (rc=`rc')"
                continue
            }

            * -- Bring preds to Stata and merge with labels
            _h2oframe get valid_h2o, clear
            keep __rowid `prednm'
            rename `prednm' phat_v
            tempfile valid_preds
            save `valid_preds', replace

            use `yvalid_only', clear
            merge 1:1 __rowid using `valid_preds'
            keep if _merge==3
            drop _merge

            capture confirm numeric variable roll_forward
            if _rc {
                destring roll_forward, replace
            }

            * --- Robust AUC flip: better of phat_v vs 1 - phat_v
            tempvar phat1a phat1b
            gen double `phat1a' = phat_v
            gen double `phat1b' = 1 - phat_v

            capture noisily roctab roll_forward `phat1a', summary
            local auc_a = .
            if !_rc {
                local auc_a = r(area)
            }

            capture noisily roctab roll_forward `phat1b', summary
            local auc_b = .
            if !_rc {
                local auc_b = r(area)
            }

            local use_flip = (`auc_b' > `auc_a')
            gen double phat1 = cond(`use_flip', `phat1b', `phat1a')
            local v_auc = max(`auc_a', `auc_b')

            * --- Accuracy @ .50
            tempvar yhat50 ok50
            gen byte `yhat50' = (phat1 >= 0.50)
            gen byte `ok50'   = (`yhat50' == roll_forward)
            quietly summarize `ok50'
            local v_acc_p50 = r(mean)

            * --- Best F1 + threshold (sweep 0→1 by .01)
            scalar best_f1 = -1
            scalar best_t  = 0
            forvalues i = 0/100 {
                local t = `i'/100
                tempvar yhat p tp fp fn
                gen byte `yhat' = (phat1 >= `t')
                gen byte `p'  = (roll_forward==1)
                gen byte `tp' = (`yhat'==1 & `p'==1)
                gen byte `fp' = (`yhat'==1 & `p'==0)
                gen byte `fn' = (`yhat'==0 & `p'==1)

                quietly summarize `tp'
                scalar TP = r(sum)
                quietly summarize `fp'
                scalar FP = r(sum)
                quietly summarize `fn'
                scalar FN = r(sum)

                scalar PREC = cond(TP+FP>0, TP/(TP+FP), 0)
                scalar REC  = cond(TP+FN>0, TP/(TP+FN), 0)
                scalar F1   = cond(PREC+REC>0, 2*PREC*REC/(PREC+REC), 0)

                if (F1 > best_f1) {
                    scalar best_f1 = F1
                    scalar best_t  = `t'
                }

                drop `yhat' `p' `tp' `fp' `fn'
            }

            post `results' (`nt') (`md') (`mt') ///
                (`v_auc') (`v_acc_p50') (best_f1) (best_t)

            * Optional: tidy H2O validation frame (only if supported)
            * _h2oframe change valid_h2o
            * capture noisily _h2oframe drop `prednm'
        }
    }
}

postclose `results'

use rf_grid_forcedsplit_trimmed.dta, clear
gsort -valid_auc
list ntrees maxdepth mtry valid_auc valid_acc_p50 valid_f1_best valid_thresh_best in 1/12, abbrev(16)
di as res "Done."


























* CONSUMER RANDOM FOREST *
******************************************************
* RANDOM FOREST — Trimmed Grid (Consumers, Forced Split)
* File: FINAL_CONS.dta
* Split: d_train==1 (train), d_train==0 (validation)
* Grid: ntrees(100,250,500) × maxdepth(3,5,10,20) × mtry(3,5,8)
******************************************************

version 18.5
clear all
set more off
set seed 42

*--------------------------------------
* 0) Load data (Consumers)
*--------------------------------------
local HOME : env HOME
local box  "`HOME'/Library/CloudStorage/Box-Box"
local outdir "`box'/Amex_2025_Class/Joseph"
use "`outdir'/FINAL_CONS.dta", clear

*--------------------------------------
* 1) Sanity checks
*--------------------------------------
capture confirm variable roll_forward
if _rc {
    di as err "DV roll_forward not found — stopping."
    exit 198
}
capture confirm variable d_train
if _rc {
    di as err "Split flag d_train not found — stopping."
    exit 198
}
capture confirm numeric variable roll_forward
if _rc destring roll_forward, replace
assert inlist(roll_forward,0,1)

capture confirm variable __rowid
if _rc gen long __rowid = _n

*--------------------------------------
* 2) Predictor list X (exclude DV + non-features)
*--------------------------------------
local dep roll_forward
local dropvars d_train __rowid id account_id date_var cv5 d_consumer d_chrg d_chrg_lend

ds
local all `r(varlist)'
local X : list all - `dep'
foreach v of local dropvars {
    capture confirm variable `v'
    if !_rc local X : list X - `v'
}

* (Optional) strip strings if needed by your H2O wrapper:
* foreach v of local X {
*     capture confirm string variable `v'
*     if !_rc local X : list X - `v'
* }

local k : word count `X'
di as txt "Predictor count: `k'"
if `k'==0 {
    di as err "No predictors after exclusions — stopping."
    exit 459
}
global Xvars `X'

*--------------------------------------
* 3) Materialize forced train/validation splits
*--------------------------------------
tempfile train_d valid_d yvalid_only

preserve
    keep if d_train==1
    count
    if r(N)==0 {
        di as err "No rows where d_train==1 — stopping."
        restore, not
        exit 459
    }
    save `train_d', replace
restore

preserve
    keep if d_train==0
    count
    if r(N)==0 {
        di as err "No rows where d_train==0 — stopping."
        restore, not
        exit 459
    }
    save `valid_d', replace
restore

use `valid_d', clear
keep __rowid roll_forward
save `yvalid_only', replace

*--------------------------------------
* 4) Start H2O and push frames
*--------------------------------------
cap h2o shutdown, force
h2o init

capture noisily _h2oframe remove train_h2o
capture noisily _h2oframe remove valid_h2o

use `train_d', clear
_h2oframe put, into(train_h2o) replace
use `valid_d', clear
_h2oframe put, into(valid_h2o) replace

_h2oframe change train_h2o
_h2oframe factor roll_forward, replace
_h2oframe change valid_h2o
_h2oframe factor roll_forward, replace

*--------------------------------------
* 5) Trimmed grid definitions (your request)
*--------------------------------------
local ntrees_list   100 250 500
local depth_list    3 5 10 20
local mtry_list     3 5 8

tempname results
capture postutil clear
postfile `results' int(ntrees maxdepth mtry) ///
    double(valid_auc valid_acc_p50 valid_f1_best valid_thresh_best) ///
    using rf_grid_forcedsplit_CONS_TRIM.dta, replace

*--------------------------------------
* 6) Grid loop — failure-safe, brace-free
*--------------------------------------
foreach nt of local ntrees_list {
    foreach md of local depth_list {
        foreach mt of local mtry_list {

            di as text ">>> RF: ntrees=`nt' | maxdepth=`md' | mtry=`mt'"

            * Train (skip on failure)
            _h2oframe change train_h2o
            capture noisily h2oml rfbinclass roll_forward $Xvars, ///
                ntrees(`nt') maxdepth(`md') predsampvalue(`mt') ///
                h2orseed(42)
            local rc = _rc
            if `rc'!=0 di as err "SKIP TRAIN: nt=`nt' md=`md' mt=`mt' (rc=`rc')"
            if `rc'!=0 continue

            * Predict on validation with a unique column
            local prednm phat_v_nt`nt'_md`md'_mt`mt'
            _h2oframe change valid_h2o
            capture noisily h2omlpredict `prednm', pr
            local rc = _rc
            if `rc'!=0 di as err "SKIP PRED : nt=`nt' md=`md' mt=`mt' (rc=`rc')"
            if `rc'!=0 continue

            * Bring preds back and merge with labels
            _h2oframe get valid_h2o, clear
            keep __rowid `prednm'
            rename `prednm' phat_v
            tempfile valid_preds
            save `valid_preds', replace

            use `yvalid_only', clear
            merge 1:1 __rowid using `valid_preds'
            keep if _merge==3
            drop _merge

            capture confirm numeric variable roll_forward
            if _rc destring roll_forward, replace

            * Robust AUC flip (ensure P(y==1))
            tempvar p1a p1b
            gen double `p1a' = phat_v
            gen double `p1b' = 1 - phat_v

            capture noisily roctab roll_forward `p1a', summary
            local auc_a = .
            if !_rc local auc_a = r(area)

            capture noisily roctab roll_forward `p1b', summary
            local auc_b = .
            if !_rc local auc_b = r(area)

            local use_flip = (`auc_b' > `auc_a')
            gen double phat1 = cond(`use_flip', `p1b', `p1a')
            local v_auc = max(`auc_a', `auc_b')

            * Accuracy @ .50
            tempvar yhat50 ok50
            gen byte `yhat50' = (phat1 >= 0.50)
            gen byte `ok50'   = (`yhat50' == roll_forward)
            quietly summarize `ok50'
            local v_acc_p50 = r(mean)

            * Best F1 + threshold (0→1 by .01)
            scalar best_f1 = -1
            scalar best_t  = 0
            forvalues i = 0/100 {
                local t = `i'/100
                tempvar yhat p tp fp fn
                gen byte `yhat' = (phat1 >= `t')
                gen byte `p'  = (roll_forward==1)
                gen byte `tp' = (`yhat'==1 & `p'==1)
                gen byte `fp' = (`yhat'==1 & `p'==0)
                gen byte `fn' = (`yhat'==0 & `p'==1)

                quietly summarize `tp'
                scalar TP = r(sum)
                quietly summarize `fp'
                scalar FP = r(sum)
                quietly summarize `fn'
                scalar FN = r(sum)

                scalar PREC = cond(TP+FP>0, TP/(TP+FP), 0)
                scalar REC  = cond(TP+FN>0, TP/(TP+FN), 0)
                scalar F1   = cond(PREC+REC>0, 2*PREC*REC/(PREC+REC), 0)

                if (F1 > best_f1) scalar best_f1 = F1
                if (F1 == best_f1) scalar best_t  = `t'

                drop `yhat' `p' `tp' `fp' `fn'
            }

            post `results' (`nt') (`md') (`mt') ///
                (`v_auc') (`v_acc_p50') (best_f1) (best_t)
        }
    }
}

postclose `results'

use rf_grid_forcedsplit_CONS_TRIM.dta, clear
gsort -valid_auc
list ntrees maxdepth mtry valid_auc valid_acc_p50 valid_f1_best valid_thresh_best in 1/12, abbrev(16)
di as res "Done (Consumers trimmed grid)."

