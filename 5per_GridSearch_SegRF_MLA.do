*** Random Forest — ALL OBS with Grid Search (H2O)
*** Joseph Lanser — AREC 559

clear all
set more off

* --------- paths ----------
local HOME : env HOME
local box  "`HOME'/Library/CloudStorage/Box-Box"
local outdir "`box'/Amex_2025_Class/Joseph"

* --------- load dataset ----------
use "`outdir'/5per_MLA_Cleaned_Rolled_Joseph.dta", clear
count
di as txt "Rows in ALL OBS: " r(N)
if (r(N)==0) {
    di as err "Dataset is empty — stopping."
    exit
}

* Confirm DV exists
capture confirm variable roll_forward
if _rc {
    di as err "DV roll_forward not found in this dataset!"
    exit
}

* Stable ID for bootstrap/OOB
capture confirm variable __rowid
if _rc gen long __rowid = _n

* Snapshot full data (with __rowid)
tempfile seg_all
save `seg_all', replace

* --------- TRAIN bootstrap (clustered by __rowid) ----------
use `seg_all', clear
set seed 42
capture drop selid
bsample, cluster(__rowid) idcluster(selid)
tempfile train_b
save `train_b', replace

* --------- OOB = rows NOT drawn ----------
use `train_b', clear
keep __rowid
duplicates drop
tempfile in_ids
save `in_ids', replace

use `seg_all', clear
merge 1:1 __rowid using `in_ids'
keep if _merge==1
drop _merge
tempfile oob_b
save `oob_b', replace

* --------- Labels ----------
use `seg_all', clear
keep __rowid roll_forward
tempfile yseg
save `yseg', replace

* --------- Predictor list (exclude DV, IDs, segment flags) ----------
use `seg_all', clear
ds
local all `r(varlist)'
local X : list all - roll_forward
foreach v in id account_id date_var __rowid selid cv5 d_consumer d_chrg d_chrg_lend {
    capture confirm variable `v'
    if !_rc local X : list X - `v'
}
global Xvars `X'
di as txt "Predictors: $Xvars"

* --------- H2O setup ----------
cap h2o shutdown, force
h2o init

capture noisily _h2oframe remove train_b
capture noisily _h2oframe remove oob_b

use `train_b', clear
_h2oframe put, into(train_b) replace

use `oob_b', clear
_h2oframe put, into(oob_b) replace

_h2oframe change train_b
_h2oframe factor roll_forward, replace
_h2oframe change oob_b
_h2oframe factor roll_forward, replace

* --------- Grid definitions ----------
local Nlist 500 800 1000
local Dlist 10 30 90
local Mlist 3 5 10

* --------- Results container ----------
tempfile grid
postfile handle ntrees maxdepth mtry ///
    double oob_auc oob_acc50 best_t best_acc ///
    using `grid', replace

* =========================
* GRID SEARCH
* =========================
foreach nt of local Nlist {
    foreach md of local Dlist {
        foreach mtry of local Mlist {

            * Train on TRAIN
            _h2oframe change train_b
            h2oml rfbinclass roll_forward $Xvars, ///
                ntrees(`nt') maxdepth(`md') predsampvalue(`mtry') ///
                h2orseed(42)

            * -------- TRAIN predictions -> best threshold --------
            _h2oframe change train_b
            local ptrain phat_tr_`nt'_`md'_`mtry'
            capture noisily _h2oframe drop `ptrain'
            h2omlpredict `ptrain', pr

            _h2oframe get train_b, clear
            keep __rowid `ptrain'
            rename `ptrain' phat_tr
            tempfile train_preds
            save `train_preds', replace

            use `yseg', clear
            merge 1:m __rowid using `train_preds'
            keep if _merge==3
            drop _merge

            capture confirm numeric variable roll_forward
            if _rc destring roll_forward, replace
            gen double phat1_tr = 1 - phat_tr

            scalar __best_acc = -1
            scalar __best_t   = 0
            forvalues i = 0/100 {
                local t = `i'/100
                gen byte __yhat = (phat1_tr >= `t')
                gen byte __ok   = (__yhat == roll_forward)
                quietly summarize __ok
                if (r(mean) > __best_acc) {
                    scalar __best_acc = r(mean)
                    scalar __best_t   = `t'
                }
                drop __yhat __ok
            }

            * -------- OOB predictions + metrics --------
            _h2oframe change oob_b
            local poob phat_oob_`nt'_`md'_`mtry'
            capture noisily _h2oframe drop `poob'
            h2omlpredict `poob', pr

            _h2oframe get oob_b, clear
            keep __rowid `poob'
            rename `poob' phat_oob
            tempfile oob_preds
            save `oob_preds', replace

            use `yseg', clear
            merge 1:1 __rowid using `oob_preds'
            keep if _merge==3
            drop _merge

            capture confirm numeric variable roll_forward
            if _rc destring roll_forward, replace

            gen double phat1 = 1 - phat_oob

            * OOB AUC
            capture noisily roctab roll_forward phat1, summary
            local auc = .
            if !_rc local auc = r(area)

            * OOB Accuracy @ .50
            gen byte yhat50 = (phat1 >= 0.50)
            gen byte ok50   = (yhat50 == roll_forward)
            quietly summarize ok50
            local acc50 = r(mean)
            capture drop yhat50 ok50

            * Save one grid row
            post handle (`nt') (`md') (`mtry') ///
                (`auc') (`acc50') (scalar(__best_t)) (scalar(__best_acc))

            * ---- safe cleanup so loops never error ----
            capture drop phat1 phat1_tr phat_tr phat_oob
        }
    }
}
postclose handle

* --------- Show grid + best row ----------
use `grid', clear
gsort -oob_auc -oob_acc50
format oob_auc oob_acc50 best_acc %9.3f
format best_t %9.2f

di as res "==============================="
di as res "GRID RESULTS — ALL OBS"
di as res "-------------------------------"
list ntrees maxdepth mtry oob_auc oob_acc50 best_t best_acc, noobs abbreviate(12)

quietly keep in 1
local b_nt    = ntrees[1]
local b_md    = maxdepth[1]
local b_mtry  = mtry[1]
local b_auc   = oob_auc[1]
local b_acc50 = oob_acc50[1]
local b_t     = best_t[1]
local b_bacc  = best_acc[1]

di as res "-------------------------------"
di as res "BEST COMBO — ALL OBS"
di as res "ntrees=`b_nt', maxdepth=`b_md', mtry=`b_mtry'"
di as res "OOB AUC:              " %5.3f `b_auc'
di as res "OOB ACC @ .50:        " %5.3f `b_acc50'
di as res "TRAIN best threshold: " %5.2f `b_t'
di as res "TRAIN best acc:       " %5.3f `b_bacc'
di as res "==============================="

* Optional persistence:
* export delimited using "`outdir'/rf_allobs_grid.csv", replace
* save "`outdir'/rf_allobs_grid.dta", replace
