*** This code with test Random Forest MLA on the !% Rolled up Data ***
*** Joseph Lanser ***
*** AREC 559 ***



* Open cleaned MLA dataset from box *

clear all

* --------- settings (same base as your working raw path) ---------
local HOME : env HOME
local box  "`HOME'/Library/CloudStorage/Box-Box"

* Target folder inside Amex_2025_Class
local outdir "`box'/Amex_2025_Class/Joseph"

* --------- load the cleaned rolled dataset ---------
use "`outdir'/MLA_Cleaned_Rolled_Joseph.dta", clear

* Quick checks
describe
summarize
count
*drop __000000





******************************************************
* Random Forest (H2O) GRID SEARCH with Bootstrap + OOB
* - DV: roll_forward (classification)
* - Train = bootstrap sample (size N, with replacement)
* - Test  = OOB (not drawn)
* - Grid: ntrees, maxdepth, predsampvalue (mtry)
* - Logs per combo:
*     OOB AUC (threshold-free)
*     OOB acc @ 0.50
*     OOB acc @ TRAIN best-t (by accuracy)
*     OOB precision/recall/F1 @ TRAIN best-t
*     TRAIN best-t and its TRAIN accuracy
******************************************************

* -------- Settings
local dep roll_forward
local dropvars id account_id date_var __rowid selid cv5
local base_seed 42

* ---- Define your grid here ----
local GRID_ntrees      200 500 800
local GRID_maxdepth    3 5 8
local GRID_mtry        2 3 4
* -------------------------------

* Helper: accuracy at a threshold
capture program drop _acc_at_thr
program define _acc_at_thr, rclass
    // Usage: quietly _acc_at_thr <probvar>, truth(<var>) thr(#)
    syntax varname(numeric) , TRUTH(varname numeric) THR(real)
    tempvar yhat ok
    gen byte `yhat' = (`varlist' >= `thr')
    gen byte `ok'   = (`yhat' == `truth')
    quietly summarize `ok'
    return scalar acc = r(mean)
    drop `yhat' `ok'
end

* --- 0) Stable row id
capture confirm variable __rowid
if _rc gen long __rowid = _n

* --- 1) Predictor list
ds
local all `r(varlist)'
local X : list all - `dep'
foreach v of local dropvars {
    local X : list X - `v'
}
global Xvars `X'

* --- 2) Save clean copy
tempfile orig
save `orig', replace

* --- 3) Start/Connect H2O
cap h2o shutdown, force
h2o init
capture noisily _h2oframe remove train_b
capture noisily _h2oframe remove oob_b

* --- 4) Bootstrap TRAIN sample
set seed `base_seed'
use `orig', clear
bsample, cluster(__rowid) idcluster(selid)
tempfile train_b
save `train_b', replace

* --- 5) Build OOB (TEST)
use `train_b', clear
keep __rowid
duplicates drop
tempfile in_ids
save `in_ids', replace

use `orig', clear
merge 1:1 __rowid using `in_ids'   // _merge==1 are OOB (not drawn)
keep if _merge==1
drop _merge
tempfile oob_b
save `oob_b', replace

* --- 6) One-time label pulls
use `orig', clear
keep __rowid `dep'
tempfile ytrain
save `ytrain', replace   // labels for TRAIN
tempfile yorig
save `yorig', replace    // labels for OOB (same content, separate temp handle)

* --- 7) Prepare result collector
tempfile gridres
tempname H
capture postclose `H'
postfile `H' ///
    int ntree byte maxdepth mtry ///
    double train_best_t train_acc_bt ///
    double oob_auc oob_acc50 oob_acc_bt ///
    double oob_prec_bt oob_rec_bt oob_f1_bt ///
    using `gridres', replace

******************************************************
* --- 8) GRID SEARCH LOOP
******************************************************
foreach NT of local GRID_ntrees {
    foreach MD of local GRID_maxdepth {
        foreach MV of local GRID_mtry {

            * ---- REFRESH H2O FRAMES (prevents "var already exists")
            use `train_b', clear
            _h2oframe put, into(train_b) replace
            use `oob_b', clear
            _h2oframe put, into(oob_b) replace

            * Ensure DV is enum on both frames
            _h2oframe change train_b
            _h2oframe factor `dep', replace
            _h2oframe change oob_b
            _h2oframe factor `dep', replace

            * ---- Train model on TRAIN (bootstrap)
            _h2oframe change train_b
            h2oml rfbinclass `dep' $Xvars, ///
                ntrees(`NT') maxdepth(`MD') predsampvalue(`MV') ///
                h2orseed(`base_seed')
                // Optional: add samprate(1) to disable per-tree bootstrap inside RF

            * ---- TRAIN predictions to choose best threshold by ACC
            _h2oframe change train_b
            h2omlpredict phat_tr, pr   // may overwrite if exists, but we just refreshed
            _h2oframe get train_b, clear
            keep __rowid phat_tr
            tempfile train_preds
            save `train_preds', replace

            * master = ytrain (one per __rowid), using = train_preds (many per __rowid)
            use `ytrain', clear
            merge 1:m __rowid using `train_preds'
            keep if _merge==3
            drop _merge

            * Numeric ground truth on TRAIN
            tempvar y_true_tr
            capture confirm numeric variable `dep'
            if _rc {
                gen byte `y_true_tr' = .
                replace `y_true_tr' = 1 if inlist(lower(`dep'),"1","yes","true","y","t")
                replace `y_true_tr' = 0 if inlist(lower(`dep'),"0","no","false","n","f")
                count if missing(`y_true_tr')
                if r(N) capture destring `dep', gen(`y_true_tr') force
            }
            else gen double `y_true_tr' = `dep'

            gen double phat1_tr = 1 - phat_tr   // flip if H2O gave Pr(y==0)

            * Sweep thresholds 0..1 by .01 to get best_t by TRAIN accuracy
            tempname best_t best_acc
            scalar `best_acc' = -1
            forvalues i = 0/100 {
                local t = `i'/100
                gen byte __yhat = (phat1_tr >= `t')
                gen byte __ok   = (__yhat == `y_true_tr')
                quietly summarize __ok
                if (r(mean) > `best_acc') {
                    scalar `best_acc' = r(mean)
                    scalar `best_t' = `t'
                }
                drop __yhat __ok
            }

            * ---- OOB predictions
            _h2oframe change oob_b
            h2omlpredict phat_oob, pr
            _h2oframe get oob_b, clear
            keep __rowid phat_oob
            tempfile oob_preds
            save `oob_preds', replace

            use `yorig', clear
            merge 1:1 __rowid using `oob_preds'
            keep if _merge==3
            drop _merge

            * Numeric ground truth on OOB
            tempvar y_true_oob
            capture confirm numeric variable `dep'
            if _rc {
                gen byte `y_true_oob' = .
                replace `y_true_oob' = 1 if inlist(lower(`dep'),"1","yes","true","y","t")
                replace `y_true_oob' = 0 if inlist(lower(`dep'),"0","no","false","n","f")
                count if missing(`y_true_oob')
                if r(N) capture destring `dep', gen(`y_true_oob') force
            }
            else gen double `y_true_oob' = `dep'

            gen double phat1 = 1 - phat_oob

            * OOB accuracy @ 0.50
            quietly _acc_at_thr phat1, truth(`y_true_oob') thr(0.50)
            local acc50 = r(acc)

            * OOB AUC (threshold-free)
            capture noisily roctab `y_true_oob' phat1, summary
            local auc = .
            if !_rc local auc = r(area)

            * OOB accuracy at TRAIN best_t
            quietly _acc_at_thr phat1, truth(`y_true_oob') thr(`=scalar(`best_t')')
            local acc_bt = r(acc)

            * Precision/Recall/F1 @ TRAIN best_t on OOB (quiet counts)
            tempvar yhat_bt
            gen byte `yhat_bt' = (phat1 >= scalar(`best_t'))

            quietly count if `y_true_oob'==1 & `yhat_bt'==1
            scalar TP = r(N)
            quietly count if `y_true_oob'==0 & `yhat_bt'==1
            scalar FP = r(N)
            quietly count if `y_true_oob'==1 & `yhat_bt'==0
            scalar FN = r(N)

            scalar prec_ = cond(TP+FP>0, TP/(TP+FP), .)
            scalar rec_  = cond(TP+FN>0, TP/(TP+FN), .)
            scalar f1_   = cond((prec_+rec_)>0, 2*prec_*rec_/(prec_+rec_), .)

            drop `yhat_bt'

            * Post the row to results
            post `H' ( `NT' ) ( `MD' ) ( `MV' ) ///
                      ( scalar(`best_t') ) ( scalar(`best_acc') ) ///
                      ( `auc' ) ( `acc50' ) ( `acc_bt' ) ///
                      ( scalar(prec_) ) ( scalar(rec_) ) ( scalar(f1_) )

            di as txt "Done combo -> ntrees=" `NT' "  maxdepth=" `MD' "  mtry=" `MV' ///
                "  | OOB AUC=" %5.3f `auc' "  OOB acc@.50=" %5.3f `acc50' ///
                "  OOB acc@best_t=" %5.3f `acc_bt'
        }
    }
}
postclose `H'

* --- 9) Inspect results
use `gridres', clear
order ntree maxdepth mtry train_best_t train_acc_bt oob_auc oob_acc50 oob_acc_bt oob_prec_bt oob_rec_bt oob_f1_bt

di as txt "---- Top by OOB AUC ----"
gsort -oob_auc
list ntree maxdepth mtry oob_auc oob_acc_bt oob_prec_bt oob_rec_bt oob_f1_bt in 1/10, abbrev(12)

di as txt "---- Top by OOB Accuracy @ best_t ----"
gsort -oob_acc_bt
list ntree maxdepth mtry oob_acc_bt oob_auc oob_prec_bt oob_rec_bt oob_f1_bt in 1/10, abbrev(12)

di as txt "---- Top by OOB F1 @ best_t ----"
gsort -oob_f1_bt
list ntree maxdepth mtry oob_f1_bt oob_prec_bt oob_rec_bt oob_auc oob_acc_bt in 1/10, abbrev(12)

* Optionally save results table
* save "rf_grid_oob_results.dta", replace
******************************************************
* Notes:
* - Refreshing frames each combo avoids column-name collisions in H2O.
* - AUC is threshold-free; best_t affects accuracy/precision/recall/F1 only.
* - Expand GRID_* lists to explore more settings (watch runtime).
******************************************************
