*** This code with test 2 different MLA with the rolled up on EN 1% Data Sample ***
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
 drop __000000






******************************************************
* Random Forest (H2O) — robust script (Option A)
* - DV: past_60_bi  (factored to enum in H2O)
* - mtry = 3, maxdepth = 8, bootstrap .632, seed 42
* - preserve/restore; safe pulls; positive-class prob = phat1
******************************************************

* --- 0) Define DV and any non-feature columns to drop
local dep past_60_bi
local dropvars id account_id date_var __rowid   // edit/remove to match your data

* --- 0.5) Stable row id for merging predictions later
capture confirm variable __rowid
if _rc gen long __rowid = _n

* --- 1) Build predictor list X = all vars minus DV and dropvars
ds
local all `r(varlist)'
local X : list all - `dep'
foreach v of local dropvars {
    local X : list X - `v'
}

* --- 2) Start / connect to H2O
h2o init

* --- 3) Clean leftover H2O frames
capture noisily _h2oframe remove rfdata
capture noisily _h2oframe remove rfdata2
capture noisily _h2oframe remove train
capture noisily _h2oframe remove test

* --- 4) Send data to H2O and select it
_h2oframe put, into(rfdata) replace
_h2oframe change rfdata

* --- 5) Factor DV to enum in H2O
_h2oframe factor `dep', replace
* _h2oframe describe   // optional type check

* --- 6) Train Random Forest (binary)
global Xvars `X'
h2oml rfbinclass `dep' $Xvars, ///
    ntrees(500) maxdepth(8) predsampvalue(3) samprate(.632) h2orseed(42)

* --- 7) OOB-style metrics + var importance
h2omlestat confmatrix
h2omlgraph varimp

******************************************************
* 8) TRAINING ACCURACY (0.50 & best-threshold by accuracy)
******************************************************
* Predict probabilities on H2O frame
h2omlpredict phat, pr   // H2O default printed note shows Pr(past_60_bi==0)

* Pull predictions back safely (no DV to avoid type clash)
preserve
    _h2oframe get rfdata, clear
    keep __rowid phat
    tempfile trainpull
    save `trainpull'
restore
merge 1:1 __rowid using `trainpull', nogen

* Flip to positive-class probability (Pr(y==1))
gen double phat1 = 1 - phat

* (A) Accuracy at 0.50
gen byte yhat_c50 = (phat1 >= 0.50)
gen byte correct50 = (yhat_c50 == `dep')
quietly summ correct50
di as res "Training accuracy at threshold 0.50: " %6.3f r(mean)

* (B) Find threshold that maximizes accuracy (grid 0:.01:1)
tempname best_t best_acc
scalar `best_acc' = -1
forvalues i = 0/100 {
    local t = `i'/100
    gen byte __yhat = (phat1 >= `t')
    gen byte __ok   = (__yhat == `dep')
    quietly summ __ok
    if (r(mean) > `best_acc') {
        scalar `best_acc' = r(mean)
        scalar `best_t' = `t'
    }
    drop __yhat __ok
}
di as res "Best training threshold by accuracy: " %5.2f scalar(`best_t') "   Accuracy: " %6.3f scalar(`best_acc')

******************************************************
* OPTIONAL: 67/33 HOLDOUT for a clean test estimate
******************************************************
* Split rfdata; train on 67%, test on 33%
_h2oframe split rfdata, into(train test) split(0.67 0.33) rseed(42)

* Train on train
_h2oframe change train
h2oml rfbinclass `dep' $Xvars, ///
    ntrees(500) maxdepth(8) predsampvalue(3) samprate(.632) h2orseed(42)

* Predict on test (prob of class 0 again)
_h2oframe change test
h2omlpredict phat_test, pr

* Pull test predictions (no DV)
preserve
    _h2oframe get test, clear
    keep __rowid phat_test
    tempfile testpull
    save `testpull'
restore
merge 1:1 __rowid using `testpull', nogen keep(match)

* Flip to positive-class prob
gen double phat1_test = 1 - phat_test

* Use best training threshold if present; else 0.50
capture confirm scalar `best_t'
if _rc scalar `best_t' = 0.50

gen byte yhat_c_test = (phat1_test >= scalar(`best_t'))
gen byte correct_test = (yhat_c_test == `dep')
quietly summ correct_test
di as res "Holdout accuracy (threshold " %5.2f scalar(`best_t') "): " %6.3f r(mean)

* Baseline at 0.50
gen byte yhat_c50_test = (phat1_test >= 0.50)
gen byte correct50_test = (yhat_c50_test == `dep')
quietly summ correct50_test
di as res "Holdout accuracy (threshold 0.50): " %6.3f r(mean)

* (Optional) h2o shutdown, force


******************************************************
* ROC curve for holdout (test) data
******************************************************

* Ensure variables exist
confirm variable past_60_bi
confirm variable phat1_test

* Generate ROC curve
roctab past_60_bi phat1_test, graph summary

* Optional: save AUC
local auc = r(area)
di as res "Holdout AUC: " %6.3f `auc'

* Export the ROC graph
graph export "`outdir'/ROC_holdout.png", replace width(800) height(600)












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
 drop __000000

 
 
******************************************************
* Gradient Boosting (H2O GBM) — robust script (Option A)
* - DV: past_60_bi  (factored to enum in H2O)
* - ntrees = 500, maxdepth = 5, seed 42
* - preserve/restore; safe pulls; positive-class prob = phat1_gbm
******************************************************

* --- 0) Define DV and any non-feature columns to drop
local dep past_60_bi
local dropvars id account_id date_var __rowid   // edit/remove to match your data

* --- 0.5) Stable row id for merging predictions later
capture confirm variable __rowid
if _rc gen long __rowid = _n

* --- 1) Build predictor list X = all vars minus DV and dropvars
ds
local all `r(varlist)'
local X : list all - `dep'
foreach v of local dropvars {
    local X : list X - `v'
}

* --- 2) Start / connect to H2O
h2o init

* --- 3) Clean leftover H2O frames
capture noisily _h2oframe remove rfdata
capture noisily _h2oframe remove rfdata2
capture noisily _h2oframe remove train
capture noisily _h2oframe remove test

* --- 4) Send data to H2O and select it
_h2oframe put, into(rfdata) replace
_h2oframe change rfdata

* --- 5) Factor DV to enum in H2O (required for H2O classifiers)
_h2oframe factor `dep', replace

* --- 6) Train Gradient Boosting (binary)
global Xvars `X'

cap noi h2oml gbbinclass `dep' $Xvars, ///
    ntrees(500) maxdepth(5) h2orseed(42)
if _rc {
    di as txt "Retrying GBM with wrapper defaults..."
    h2oml gbbinclass `dep' $Xvars, ntrees(500) maxdepth(5) h2orseed(42)
}

* --- 7) Confusion matrix + variable importance
h2omlestat confmatrix
h2omlgraph varimp

******************************************************
* 8) TRAINING ACCURACY (0.50 & best-threshold by accuracy)
******************************************************
* Predict probabilities on H2O frame (GBM returns Pr(y==0))
capture drop phat_gbm
h2omlpredict phat_gbm, pr

* Pull predictions back safely (no DV to avoid type clash)
preserve
    _h2oframe get rfdata, clear
    keep __rowid phat_gbm
    tempfile gbm_trainpull
    save `gbm_trainpull'
restore
merge 1:1 __rowid using `gbm_trainpull', nogen

* Flip to positive-class probability (Pr(y==1))
capture drop phat1_gbm
gen double phat1_gbm = 1 - phat_gbm

* (A) Accuracy at 0.50
capture drop yhat_gbm_c50 correct_gbm50
gen byte yhat_gbm_c50 = (phat1_gbm >= 0.50)
gen byte correct_gbm50 = (yhat_gbm_c50 == `dep')
quietly summ correct_gbm50
di as res "GBM Training accuracy at threshold 0.50: " %6.3f r(mean)

* (B) Best threshold by accuracy (grid 0:.01:1)
tempname gbm_best_t gbm_best_acc
scalar `gbm_best_acc' = -1
forvalues i = 0/100 {
    local t = `i'/100
    gen byte __yhat_g = (phat1_gbm >= `t')
    gen byte __ok_g   = (__yhat_g == `dep')
    quietly summ __ok_g
    if (r(mean) > `gbm_best_acc') {
        scalar `gbm_best_acc' = r(mean)
        scalar `gbm_best_t' = `t'
    }
    drop __yhat_g __ok_g
}
di as res "GBM Best training threshold by accuracy: " %5.2f scalar(`gbm_best_t') "   Accuracy: " %6.3f scalar(`gbm_best_acc')

* ROC (training)
roctab `dep' phat1_gbm, graph summary
local auc_gbm_train = r(area)
di as res "GBM Training AUC: " %6.3f `auc_gbm_train'

******************************************************
* OPTIONAL: 67/33 HOLDOUT for a clean test estimate
******************************************************
* Split rfdata; train on 67%, test on 33%
_h2oframe split rfdata, into(train test) split(0.67 0.33) rseed(42)

* Ensure DV is enum in both splits
_h2oframe change train
_h2oframe factor `dep', replace
_h2oframe change test
_h2oframe factor `dep', replace

* Train on train (GBM)
_h2oframe change train
cap noi h2oml gbbinclass `dep' $Xvars, ///
    ntrees(500) maxdepth(5) h2orseed(42)
if _rc {
    h2oml gbbinclass `dep' $Xvars, ntrees(500) maxdepth(5) h2orseed(42)
}

* Predict on test (Pr(y==0))
_h2oframe change test
capture drop phat_gbm_test
h2omlpredict phat_gbm_test, pr

* Pull test predictions (no DV)
preserve
    _h2oframe get test, clear
    keep __rowid phat_gbm_test
    tempfile gbm_testpull
    save `gbm_testpull'
restore
merge 1:1 __rowid using `gbm_testpull', nogen keep(match)

* Flip to positive-class prob
capture drop phat1_gbm_test
gen double phat1_gbm_test = 1 - phat_gbm_test

* Use best training threshold if present; else 0.50
capture confirm scalar `gbm_best_t'
if _rc scalar `gbm_best_t' = 0.50

* Holdout accuracy at GBM best threshold
capture drop yhat_gbm_c_test correct_gbm_test
gen byte yhat_gbm_c_test = (phat1_gbm_test >= scalar(`gbm_best_t'))
gen byte correct_gbm_test = (yhat_gbm_c_test == `dep')
quietly summ correct_gbm_test
di as res "GBM Holdout accuracy (threshold " %5.2f scalar(`gbm_best_t') "): " %6.3f r(mean)

* Baseline holdout accuracy at 0.50
capture drop yhat_gbm_c50_test correct_gbm50_test
gen byte yhat_gbm_c50_test = (phat1_gbm_test >= 0.50)
gen byte correct_gbm50_test = (yhat_gbm_c50_test == `dep')
quietly summ correct_gbm50_test
di as res "GBM Holdout accuracy (threshold 0.50): " %6.3f r(mean)

* ROC (holdout)
roctab `dep' phat1_gbm_test, graph summary
local auc_gbm_test = r(area)
di as res "GBM Holdout AUC: " %6.3f `auc_gbm_test'
