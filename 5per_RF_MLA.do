*** This code will test Random Forest based on Segments to decide if segmenting is worth it ***
*** Joseph Lanser ***
*** AREC 559 ***



* Open cleaned MLA dataset from box *

clear all

* --------- settings (same base as your working raw path) ---------
local HOME : env HOME
local box  "`HOME'/Library/CloudStorage/Box-Box"

* Target folder inside Amex_2025_Class
local outdir "`box'/Amex_2025_Class/Joseph"

* --------- load the cleaned rolled 5% dataset ---------
use "`outdir'/5per_MLA_Cleaned_Rolled_Joseph.dta", clear

* Quick checks
describe
summarize
count
*drop __000000




*************************************************************
* Random Forest — Consumer & Charge Customers ONLY (fixed)
* DV: roll_forward
* TRAIN: bootstrap (clustered by __rowid)
* TEST: out-of-bag (not drawn)
* RF Hyperparams: ntrees=1000 maxdepth=10 mtry=5
*************************************************************

clear all
set more off

* 1) Load the dataset
local HOME : env HOME
local box  "`HOME'/Library/CloudStorage/Box-Box"
local outdir "`box'/Amex_2025_Class/Joseph"

use "`outdir'/5per_MLA_Cleaned_Rolled_Joseph.dta", clear

* 2) Keep ONLY Consumer Charge segment
keep if d_consumer == 1 & d_chrg == 1
count
di as txt "Rows in Consumer-Charge segment: " r(N)
if (r(N) == 0) {
    di as err "No rows in this segment — stopping."
    exit
}

* Confirm DV exists
capture confirm variable roll_forward
if _rc {
    di as err "DV roll_forward not found in this dataset!"
    exit
}

* Ensure stable ID (must exist BEFORE we make temp copies)
capture confirm variable __rowid
if _rc gen long __rowid = _n

* Snapshot this filtered segment (with __rowid) for later merges
tempfile seg_all
save `seg_all', replace

*************************************************************
* 3) Build TRAIN bootstrap sample (from the segment snapshot)
*************************************************************
use `seg_all', clear
set seed 42
capture drop selid
bsample, cluster(__rowid) idcluster(selid)
tempfile train_b
save `train_b', replace

*************************************************************
* 4) Build OOB sample = rows NOT drawn into TRAIN
*************************************************************
use `train_b', clear
keep __rowid
duplicates drop
tempfile in_ids
save `in_ids', replace

use `seg_all', clear                   // <-- use the segment snapshot (has __rowid)
merge 1:1 __rowid using `in_ids'
keep if _merge == 1                    // _merge==1 are the OOB rows
drop _merge
tempfile oob_b
save `oob_b', replace

*************************************************************
* 5) Prepare labels (from the same segment snapshot)
*************************************************************
use `seg_all', clear
keep __rowid roll_forward
tempfile yseg
save `yseg', replace

*************************************************************
* 6) Predictor list (exclude DV, IDs, segment dummies)
*************************************************************
use `seg_all', clear    // just to build X on the same column set
ds
local all `r(varlist)'
local X : list all - roll_forward
foreach v in id account_id date_var __rowid selid cv5 d_consumer d_chrg d_chrg_lend {
    capture confirm variable `v'
    if !_rc local X : list X - `v'
}
global Xvars `X'
display as text "Predictors: $Xvars"

*************************************************************
* 7) Start H2O & load TRAIN/OOB frames
*************************************************************
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

*************************************************************
* 8) Train Random Forest
*************************************************************
_h2oframe change train_b
h2oml rfbinclass roll_forward $Xvars, ///
    ntrees(1000) maxdepth(10) predsampvalue(5) ///
    h2orseed(42)

* TRAIN predictions — find best threshold
_h2oframe change train_b
capture drop phat_tr
h2omlpredict phat_tr, pr
_h2oframe get train_b, clear
keep __rowid phat_tr
tempfile train_preds
save `train_preds', replace

use `yseg', clear
merge 1:m __rowid using `train_preds'
keep if _merge == 3
drop _merge

* numeric ground truth + sweep thresholds
capture confirm numeric variable roll_forward
if _rc destring roll_forward, replace

gen double phat1_tr = 1 - phat_tr

scalar best_acc = -1
scalar best_t = 0

forvalues i = 0/100 {
    local t = `i'/100
    gen byte __yhat = (phat1_tr >= `t')
    gen byte __ok   = (__yhat == roll_forward)
    quietly summarize __ok
    if (r(mean) > best_acc) {
        scalar best_acc = r(mean)
        scalar best_t = `t'
    }
    drop __yhat __ok
}

*************************************************************
* 9) OOB predictions + metrics
*************************************************************
_h2oframe change oob_b
capture drop phat_oob
h2omlpredict phat_oob, pr
_h2oframe get oob_b, clear
keep __rowid phat_oob
tempfile oob_preds
save `oob_preds', replace

use `yseg', clear
merge 1:1 __rowid using `oob_preds'
keep if _merge == 3
drop _merge

capture confirm numeric variable roll_forward
if _rc destring roll_forward, replace

gen double phat1 = 1 - phat_oob

* AUC (threshold-free)
capture noisily roctab roll_forward phat1, summary
local auc = .
if !_rc local auc = r(area)

* Accuracy @ .50
gen byte yhat50 = (phat1 >= 0.50)
gen byte ok50 = (yhat50 == roll_forward)
quietly summarize ok50
local acc50 = r(mean)
drop yhat50 ok50

*************************************************************
* ✅ RESULTS — PRINT TO SCREEN
*************************************************************
di as res "==============================="
di as res "RF SEGMENT: Consumer + Charge"
di as res "-------------------------------"
di as res "OOB AUC:              " %5.3f `auc'
di as res "OOB ACC @ .50:        " %5.3f `acc50'
di as res "TRAIN best threshold: " %5.2f best_t
di as res "TRAIN best acc:       " %5.3f best_acc
di as res "==============================="











*************************************************************
* Random Forest — Consumer & Lend-only Customers ONLY
* DV: roll_forward
* TRAIN: bootstrap (clustered by __rowid)
* TEST: out-of-bag (not drawn)
* RF Hyperparams: ntrees=1000 maxdepth=10 mtry=5
*************************************************************

clear all
set more off

* 1) Load the dataset
local HOME : env HOME
local box  "`HOME'/Library/CloudStorage/Box-Box"
local outdir "`box'/Amex_2025_Class/Joseph"

use "`outdir'/5per_MLA_Cleaned_Rolled_Joseph.dta", clear

* 2) Keep ONLY Consumer Lend-only segment
keep if d_consumer == 1 & d_chrg == 0 & d_chrg_lend == 0
count
di as txt "Rows in Consumer-LEND-ONLY segment: " r(N)
if (r(N) == 0) {
    di as err "No rows in this segment — stopping."
    exit
}

* Confirm DV exists
capture confirm variable roll_forward
if _rc {
    di as err "DV roll_forward not found in this dataset!"
    exit
}

* Ensure stable ID (must exist BEFORE we make temp copies)
capture confirm variable __rowid
if _rc gen long __rowid = _n

* Snapshot this filtered segment (with __rowid) for later merges
tempfile seg_all
save `seg_all', replace

*************************************************************
* 3) Build TRAIN bootstrap sample (from the segment snapshot)
*************************************************************
use `seg_all', clear
set seed 42
capture drop selid
bsample, cluster(__rowid) idcluster(selid)
tempfile train_b
save `train_b', replace

*************************************************************
* 4) Build OOB sample = rows NOT drawn into TRAIN
*************************************************************
use `train_b', clear
keep __rowid
duplicates drop
tempfile in_ids
save `in_ids', replace

use `seg_all', clear                   // use the segment snapshot (has __rowid)
merge 1:1 __rowid using `in_ids'
keep if _merge == 1                    // _merge==1 are the OOB rows
drop _merge
tempfile oob_b
save `oob_b', replace

*************************************************************
* 5) Prepare labels (from the same segment snapshot)
*************************************************************
use `seg_all', clear
keep __rowid roll_forward
tempfile yseg
save `yseg', replace

*************************************************************
* 6) Predictor list (exclude DV, IDs, segment dummies)
*************************************************************
use `seg_all', clear    // build X on the same column set
ds
local all `r(varlist)'
local X : list all - roll_forward
foreach v in id account_id date_var __rowid selid cv5 d_consumer d_chrg d_chrg_lend {
    capture confirm variable `v'
    if !_rc local X : list X - `v'
}
global Xvars `X'
display as text "Predictors: $Xvars"

*************************************************************
* 7) Start H2O & load TRAIN/OOB frames
*************************************************************
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

*************************************************************
* 8) Train Random Forest
*************************************************************
_h2oframe change train_b
h2oml rfbinclass roll_forward $Xvars, ///
    ntrees(1000) maxdepth(10) predsampvalue(5) ///
    h2orseed(42)

* TRAIN predictions — find best threshold
_h2oframe change train_b
capture drop phat_tr
h2omlpredict phat_tr, pr
_h2oframe get train_b, clear
keep __rowid phat_tr
tempfile train_preds
save `train_preds', replace

use `yseg', clear
merge 1:m __rowid using `train_preds'
keep if _merge == 3
drop _merge

* numeric ground truth + sweep thresholds
capture confirm numeric variable roll_forward
if _rc destring roll_forward, replace

gen double phat1_tr = 1 - phat_tr

scalar best_acc = -1
scalar best_t = 0

forvalues i = 0/100 {
    local t = `i'/100
    gen byte __yhat = (phat1_tr >= `t')
    gen byte __ok   = (__yhat == roll_forward)
    quietly summarize __ok
    if (r(mean) > best_acc) {
        scalar best_acc = r(mean)
        scalar best_t = `t'
    }
    drop __yhat __ok
}

*************************************************************
* 9) OOB predictions + metrics
*************************************************************
_h2oframe change oob_b
capture drop phat_oob
h2omlpredict phat_oob, pr
_h2oframe get oob_b, clear
keep __rowid phat_oob
tempfile oob_preds
save `oob_preds', replace

use `yseg', clear
merge 1:1 __rowid using `oob_preds'
keep if _merge == 3
drop _merge

capture confirm numeric variable roll_forward
if _rc destring roll_forward, replace

gen double phat1 = 1 - phat_oob

* AUC (threshold-free)
capture noisily roctab roll_forward phat1, summary
local auc = .
if !_rc local auc = r(area)

* Accuracy @ .50
gen byte yhat50 = (phat1 >= 0.50)
gen byte ok50   = (yhat50 == roll_forward)
quietly summarize ok50
local acc50 = r(mean)
drop yhat50 ok50

*************************************************************
* ✅ RESULTS — PRINT TO SCREEN
*************************************************************
di as res "==============================="
di as res "RF SEGMENT: Consumer + LEND-ONLY"
di as res "-------------------------------"
di as res "OOB AUC:              " %5.3f `auc'
di as res "OOB ACC @ .50:        " %5.3f `acc50'
di as res "TRAIN best threshold: " %5.2f best_t
di as res "TRAIN best acc:       " %5.3f best_acc
di as res "==============================="












*************************************************************
* Random Forest — Consumers & Charge+Lend ONLY
* DV: roll_forward
* TRAIN: bootstrap (clustered by __rowid)
* TEST: out-of-bag (not drawn)
* RF Hyperparams: ntrees=1000 maxdepth=10 mtry=5
*************************************************************

clear all
set more off

* 1) Load the dataset
local HOME : env HOME
local box  "`HOME'/Library/CloudStorage/Box-Box"
local outdir "`box'/Amex_2025_Class/Joseph"

use "`outdir'/5per_MLA_Cleaned_Rolled_Joseph.dta", clear

* 2) Keep ONLY Consumers, Charge+Lend segment
keep if d_consumer == 1 & d_chrg_lend == 1
count
di as txt "Rows in Consumer — Charge+Lend segment: " r(N)
if (r(N) == 0) {
    di as err "No rows in this segment — stopping."
    exit
}

* Confirm DV exists
capture confirm variable roll_forward
if _rc {
    di as err "DV roll_forward not found in this dataset!"
    exit
}

* Ensure stable ID (must exist BEFORE we make temp copies)
capture confirm variable __rowid
if _rc gen long __rowid = _n

* Snapshot this filtered segment (with __rowid) for later merges
tempfile seg_all
save `seg_all', replace

*************************************************************
* 3) Build TRAIN bootstrap sample (from the segment snapshot)
*************************************************************
use `seg_all', clear
set seed 42
capture drop selid
bsample, cluster(__rowid) idcluster(selid)
tempfile train_b
save `train_b', replace

*************************************************************
* 4) Build OOB sample = rows NOT drawn into TRAIN
*************************************************************
use `train_b', clear
keep __rowid
duplicates drop
tempfile in_ids
save `in_ids', replace

use `seg_all', clear                   // use the segment snapshot (has __rowid)
merge 1:1 __rowid using `in_ids'
keep if _merge == 1                    // _merge==1 are the OOB rows
drop _merge
tempfile oob_b
save `oob_b', replace

*************************************************************
* 5) Prepare labels (from the same segment snapshot)
*************************************************************
use `seg_all', clear
keep __rowid roll_forward
tempfile yseg
save `yseg', replace

*************************************************************
* 6) Predictor list (exclude DV, IDs, segment dummies)
*************************************************************
use `seg_all', clear    // build X on the same column set
ds
local all `r(varlist)'
local X : list all - roll_forward
foreach v in id account_id date_var __rowid selid cv5 d_consumer d_chrg d_chrg_lend {
    capture confirm variable `v'
    if !_rc local X : list X - `v'
}
global Xvars `X'
display as text "Predictors: $Xvars"

*************************************************************
* 7) Start H2O & load TRAIN/OOB frames
*************************************************************
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

*************************************************************
* 8) Train Random Forest
*************************************************************
_h2oframe change train_b
h2oml rfbinclass roll_forward $Xvars, ///
    ntrees(1000) maxdepth(10) predsampvalue(5) ///
    h2orseed(42)

* TRAIN predictions — find best threshold
_h2oframe change train_b
capture drop phat_tr
h2omlpredict phat_tr, pr
_h2oframe get train_b, clear
keep __rowid phat_tr
tempfile train_preds
save `train_preds', replace

use `yseg', clear
merge 1:m __rowid using `train_preds'
keep if _merge == 3
drop _merge

* numeric ground truth + sweep thresholds
capture confirm numeric variable roll_forward
if _rc destring roll_forward, replace

gen double phat1_tr = 1 - phat_tr

scalar best_acc = -1
scalar best_t = 0

forvalues i = 0/100 {
    local t = `i'/100
    gen byte __yhat = (phat1_tr >= `t')
    gen byte __ok   = (__yhat == roll_forward)
    quietly summarize __ok
    if (r(mean) > best_acc) {
        scalar best_acc = r(mean)
        scalar best_t = `t'
    }
    drop __yhat __ok
}

*************************************************************
* 9) OOB predictions + metrics
*************************************************************
_h2oframe change oob_b
capture drop phat_oob
h2omlpredict phat_oob, pr
_h2oframe get oob_b, clear
keep __rowid phat_oob
tempfile oob_preds
save `oob_preds', replace

use `yseg', clear
merge 1:1 __rowid using `oob_preds'
keep if _merge == 3
drop _merge

capture confirm numeric variable roll_forward
if _rc destring roll_forward, replace

gen double phat1 = 1 - phat_oob

* AUC (threshold-free)
capture noisily roctab roll_forward phat1, summary
local auc = .
if !_rc local auc = r(area)

* Accuracy @ .50
gen byte yhat50 = (phat1 >= 0.50)
gen byte ok50   = (yhat50 == roll_forward)
quietly summarize ok50
local acc50 = r(mean)
drop yhat50 ok50

*************************************************************
* ✅ RESULTS — PRINT TO SCREEN
*************************************************************
di as res "======================================"
di as res "RF SEGMENT: Consumers — Charge+Lend"
di as res "--------------------------------------"
di as res "OOB AUC:              " %5.3f `auc'
di as res "OOB ACC @ .50:        " %5.3f `acc50'
di as res "TRAIN best threshold: " %5.2f best_t
di as res "TRAIN best acc:       " %5.3f best_acc
di as res "======================================"











*************************************************************
* Random Forest — Small Business (non-consumer) & Charge ONLY
* DV: roll_forward
* TRAIN: bootstrap (clustered by __rowid)
* TEST: out-of-bag (not drawn)
* RF Hyperparams: ntrees=1000 maxdepth=10 mtry=5
*************************************************************

clear all
set more off

* 1) Load the dataset
local HOME : env HOME
local box  "`HOME'/Library/CloudStorage/Box-Box"
local outdir "`box'/Amex_2025_Class/Joseph"

use "`outdir'/5per_MLA_Cleaned_Rolled_Joseph.dta", clear

* 2) Keep ONLY Smallbiz & Charge segment
keep if d_consumer == 0 & d_chrg == 1
count
di as txt "Rows in Smallbiz — Charge segment: " r(N)
if (r(N) == 0) {
    di as err "No rows in this segment — stopping."
    exit
}

* Confirm DV exists
capture confirm variable roll_forward
if _rc {
    di as err "DV roll_forward not found in this dataset!"
    exit
}

* Ensure stable ID (must exist BEFORE we make temp copies)
capture confirm variable __rowid
if _rc gen long __rowid = _n

* Snapshot this filtered segment (with __rowid) for later merges
tempfile seg_all
save `seg_all', replace

*************************************************************
* 3) Build TRAIN bootstrap sample (from the segment snapshot)
*************************************************************
use `seg_all', clear
set seed 42
capture drop selid
bsample, cluster(__rowid) idcluster(selid)
tempfile train_b
save `train_b', replace

*************************************************************
* 4) Build OOB sample = rows NOT drawn into TRAIN
*************************************************************
use `train_b', clear
keep __rowid
duplicates drop
tempfile in_ids
save `in_ids', replace

use `seg_all', clear                   // use the segment snapshot (has __rowid)
merge 1:1 __rowid using `in_ids'
keep if _merge == 1                    // _merge==1 are the OOB rows
drop _merge
tempfile oob_b
save `oob_b', replace

*************************************************************
* 5) Prepare labels (from the same segment snapshot)
*************************************************************
use `seg_all', clear
keep __rowid roll_forward
tempfile yseg
save `yseg', replace

*************************************************************
* 6) Predictor list (exclude DV, IDs, segment dummies)
*************************************************************
use `seg_all', clear    // build X on the same column set
ds
local all `r(varlist)'
local X : list all - roll_forward
foreach v in id account_id date_var __rowid selid cv5 d_consumer d_chrg d_chrg_lend {
    capture confirm variable `v'
    if !_rc local X : list X - `v'
}
global Xvars `X'
display as text "Predictors: $Xvars"

*************************************************************
* 7) Start H2O & load TRAIN/OOB frames
*************************************************************
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

*************************************************************
* 8) Train Random Forest
*************************************************************
_h2oframe change train_b
h2oml rfbinclass roll_forward $Xvars, ///
    ntrees(1000) maxdepth(10) predsampvalue(5) ///
    h2orseed(42)

* TRAIN predictions — find best threshold
_h2oframe change train_b
capture drop phat_tr
h2omlpredict phat_tr, pr
_h2oframe get train_b, clear
keep __rowid phat_tr
tempfile train_preds
save `train_preds', replace

use `yseg', clear
merge 1:m __rowid using `train_preds'
keep if _merge == 3
drop _merge

* numeric ground truth + sweep thresholds
capture confirm numeric variable roll_forward
if _rc destring roll_forward, replace

gen double phat1_tr = 1 - phat_tr

scalar best_acc = -1
scalar best_t = 0

forvalues i = 0/100 {
    local t = `i'/100
    gen byte __yhat = (phat1_tr >= `t')
    gen byte __ok   = (__yhat == roll_forward)
    quietly summarize __ok
    if (r(mean) > best_acc) {
        scalar best_acc = r(mean)
        scalar best_t = `t'
    }
    drop __yhat __ok
}

*************************************************************
* 9) OOB predictions + metrics
*************************************************************
_h2oframe change oob_b
capture drop phat_oob
h2omlpredict phat_oob, pr
_h2oframe get oob_b, clear
keep __rowid phat_oob
tempfile oob_preds
save `oob_preds', replace

use `yseg', clear
merge 1:1 __rowid using `oob_preds'
keep if _merge == 3
drop _merge

capture confirm numeric variable roll_forward
if _rc destring roll_forward, replace

gen double phat1 = 1 - phat_oob

* AUC (threshold-free)
capture noisily roctab roll_forward phat1, summary
local auc = .
if !_rc local auc = r(area)

* Accuracy @ .50
gen byte yhat50 = (phat1 >= 0.50)
gen byte ok50   = (yhat50 == roll_forward)
quietly summarize ok50
local acc50 = r(mean)
drop yhat50 ok50

*************************************************************
* ✅ RESULTS — PRINT TO SCREEN
*************************************************************
di as res "======================================"
di as res "RF SEGMENT: Small Business — Charge"
di as res "--------------------------------------"
di as res "OOB AUC:              " %5.3f `auc'
di as res "OOB ACC @ .50:        " %5.3f `acc50'
di as res "TRAIN best threshold: " %5.2f best_t
di as res "TRAIN best acc:       " %5.3f best_acc
di as res "======================================"










*************************************************************
* Random Forest — Small Business (non-consumer) & Lend-only
* DV: roll_forward
* TRAIN: bootstrap (clustered by __rowid)
* TEST: out-of-bag (not drawn)
* RF Hyperparams: ntrees=1000 maxdepth=10 mtry=5
*************************************************************

clear all
set more off

* 1) Load the dataset
local HOME : env HOME
local box  "`HOME'/Library/CloudStorage/Box-Box"
local outdir "`box'/Amex_2025_Class/Joseph"

use "`outdir'/5per_MLA_Cleaned_Rolled_Joseph.dta", clear

* 2) Keep ONLY Smallbiz Lend-only segment
keep if d_consumer == 0 & d_chrg == 0 & d_chrg_lend == 0
count
di as txt "Rows in Smallbiz — LEND-ONLY segment: " r(N)
if (r(N) == 0) {
    di as err "No rows in this segment — stopping."
    exit
}

* Confirm DV exists
capture confirm variable roll_forward
if _rc {
    di as err "DV roll_forward not found in this dataset!"
    exit
}

* Ensure stable ID (must exist BEFORE we make temp copies)
capture confirm variable __rowid
if _rc gen long __rowid = _n

* Snapshot this filtered segment (with __rowid) for later merges
tempfile seg_all
save `seg_all', replace

*************************************************************
* 3) Build TRAIN bootstrap sample (from the segment snapshot)
*************************************************************
use `seg_all', clear
set seed 42
capture drop selid
bsample, cluster(__rowid) idcluster(selid)
tempfile train_b
save `train_b', replace

*************************************************************
* 4) Build OOB sample = rows NOT drawn into TRAIN
*************************************************************
use `train_b', clear
keep __rowid
duplicates drop
tempfile in_ids
save `in_ids', replace

use `seg_all', clear                   // use the segment snapshot (has __rowid)
merge 1:1 __rowid using `in_ids'
keep if _merge == 1                    // _merge==1 are the OOB rows
drop _merge
tempfile oob_b
save `oob_b', replace

*************************************************************
* 5) Prepare labels (from the same segment snapshot)
*************************************************************
use `seg_all', clear
keep __rowid roll_forward
tempfile yseg
save `yseg', replace

*************************************************************
* 6) Predictor list (exclude DV, IDs, segment dummies)
*************************************************************
use `seg_all', clear    // build X on the same column set
ds
local all `r(varlist)'
local X : list all - roll_forward
foreach v in id account_id date_var __rowid selid cv5 d_consumer d_chrg d_chrg_lend {
    capture confirm variable `v'
    if !_rc local X : list X - `v'
}
global Xvars `X'
display as text "Predictors: $Xvars"

*************************************************************
* 7) Start H2O & load TRAIN/OOB frames
*************************************************************
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

*************************************************************
* 8) Train Random Forest
*************************************************************
_h2oframe change train_b
h2oml rfbinclass roll_forward $Xvars, ///
    ntrees(1000) maxdepth(10) predsampvalue(5) ///
    h2orseed(42)

* TRAIN predictions — find best threshold
_h2oframe change train_b
capture drop phat_tr
h2omlpredict phat_tr, pr
_h2oframe get train_b, clear
keep __rowid phat_tr
tempfile train_preds
save `train_preds', replace

use `yseg', clear
merge 1:m __rowid using `train_preds'
keep if _merge == 3
drop _merge

* numeric ground truth + sweep thresholds
capture confirm numeric variable roll_forward
if _rc destring roll_forward, replace

gen double phat1_tr = 1 - phat_tr

scalar best_acc = -1
scalar best_t = 0

forvalues i = 0/100 {
    local t = `i'/100
    gen byte __yhat = (phat1_tr >= `t')
    gen byte __ok   = (__yhat == roll_forward)
    quietly summarize __ok
    if (r(mean) > best_acc) {
        scalar best_acc = r(mean)
        scalar best_t = `t'
    }
    drop __yhat __ok
}

*************************************************************
* 9) OOB predictions + metrics
*************************************************************
_h2oframe change oob_b
capture drop phat_oob
h2omlpredict phat_oob, pr
_h2oframe get oob_b, clear
keep __rowid phat_oob
tempfile oob_preds
save `oob_preds', replace

use `yseg', clear
merge 1:1 __rowid using `oob_preds'
keep if _merge == 3
drop _merge

capture confirm numeric variable roll_forward
if _rc destring roll_forward, replace

gen double phat1 = 1 - phat_oob

* AUC (threshold-free)
capture noisily roctab roll_forward phat1, summary
local auc = .
if !_rc local auc = r(area)

* Accuracy @ .50
gen byte yhat50 = (phat1 >= 0.50)
gen byte ok50   = (yhat50 == roll_forward)
quietly summarize ok50
local acc50 = r(mean)
drop yhat50 ok50

*************************************************************
* ✅ RESULTS — PRINT TO SCREEN
*************************************************************
di as res "======================================"
di as res "RF SEGMENT: Small Business — Lend-only"
di as res "--------------------------------------"
di as res "OOB AUC:              " %5.3f `auc'
di as res "OOB ACC @ .50:        " %5.3f `acc50'
di as res "TRAIN best threshold: " %5.2f best_t
di as res "TRAIN best acc:       " %5.3f best_acc
di as res "======================================"








*************************************************************
* Random Forest — Small Business (non-consumer) & Charge+Lend
* DV: roll_forward
* TRAIN: bootstrap (clustered by __rowid)
* TEST: out-of-bag (not drawn)
* RF Hyperparams: ntrees=1000 maxdepth=10 mtry=5
*************************************************************

clear all
set more off

* 1) Load the dataset
local HOME : env HOME
local box  "`HOME'/Library/CloudStorage/Box-Box"
local outdir "`box'/Amex_2025_Class/Joseph"

use "`outdir'/5per_MLA_Cleaned_Rolled_Joseph.dta", clear

* 2) Keep ONLY Smallbiz Charge+Lend segment
keep if d_consumer == 0 & d_chrg_lend == 1
count
di as txt "Rows in Smallbiz — Charge+Lend segment: " r(N)
if (r(N) == 0) {
    di as err "No rows in this segment — stopping."
    exit
}

* Confirm DV exists
capture confirm variable roll_forward
if _rc {
    di as err "DV roll_forward not found in this dataset!"
    exit
}

* Ensure stable ID (must exist BEFORE temp copies)
capture confirm variable __rowid
if _rc gen long __rowid = _n

* Snapshot this filtered segment (with __rowid) for later merges
tempfile seg_all
save `seg_all', replace

*************************************************************
* 3) Build TRAIN bootstrap sample (from the segment snapshot)
*************************************************************
use `seg_all', clear
set seed 42
capture drop selid
bsample, cluster(__rowid) idcluster(selid)
tempfile train_b
save `train_b', replace

*************************************************************
* 4) Build OOB sample = rows NOT drawn into TRAIN
*************************************************************
use `train_b', clear
keep __rowid
duplicates drop
tempfile in_ids
save `in_ids', replace

use `seg_all', clear                   // use the segment snapshot (has __rowid)
merge 1:1 __rowid using `in_ids'
keep if _merge == 1                    // _merge==1 are the OOB rows
drop _merge
tempfile oob_b
save `oob_b', replace

*************************************************************
* 5) Prepare labels (from the same segment snapshot)
*************************************************************
use `seg_all', clear
keep __rowid roll_forward
tempfile yseg
save `yseg', replace

*************************************************************
* 6) Predictor list (exclude DV, IDs, segment dummies)
*************************************************************
use `seg_all', clear    // build X on the same column set
ds
local all `r(varlist)'
local X : list all - roll_forward
foreach v in id account_id date_var __rowid selid cv5 d_consumer d_chrg d_chrg_lend {
    capture confirm variable `v'
    if !_rc local X : list X - `v'
}
global Xvars `X'
display as text "Predictors: $Xvars"

*************************************************************
* 7) Start H2O & load TRAIN/OOB frames
*************************************************************
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

*************************************************************
* 8) Train Random Forest
*************************************************************
_h2oframe change train_b
h2oml rfbinclass roll_forward $Xvars, ///
    ntrees(1000) maxdepth(10) predsampvalue(5) ///
    h2orseed(42)

* TRAIN predictions — find best threshold
_h2oframe change train_b
capture drop phat_tr
h2omlpredict phat_tr, pr
_h2oframe get train_b, clear
keep __rowid phat_tr
tempfile train_preds
save `train_preds', replace

use `yseg', clear
merge 1:m __rowid using `train_preds'
keep if _merge == 3
drop _merge

* numeric ground truth + sweep thresholds
capture confirm numeric variable roll_forward
if _rc destring roll_forward, replace

gen double phat1_tr = 1 - phat_tr

scalar best_acc = -1
scalar best_t = 0

forvalues i = 0/100 {
    local t = `i'/100
    gen byte __yhat = (phat1_tr >= `t')
    gen byte __ok   = (__yhat == roll_forward)
    quietly summarize __ok
    if (r(mean) > best_acc) {
        scalar best_acc = r(mean)
        scalar best_t = `t'
    }
    drop __yhat __ok
}

*************************************************************
* 9) OOB predictions + metrics
*************************************************************
_h2oframe change oob_b
capture drop phat_oob
h2omlpredict phat_oob, pr
_h2oframe get oob_b, clear
keep __rowid phat_oob
tempfile oob_preds
save `oob_preds', replace

use `yseg', clear
merge 1:1 __rowid using `oob_preds'
keep if _merge == 3
drop _merge

capture confirm numeric variable roll_forward
if _rc destring roll_forward, replace

gen double phat1 = 1 - phat_oob

* AUC (threshold-free)
capture noisily roctab roll_forward phat1, summary
local auc = .
if !_rc local auc = r(area)

* Accuracy @ .50
gen byte yhat50 = (phat1 >= 0.50)
gen byte ok50   = (yhat50 == roll_forward)
quietly summarize ok50
local acc50 = r(mean)
drop yhat50 ok50

*************************************************************
* ✅ RESULTS — PRINT TO SCREEN
*************************************************************
di as res "==========================================="
di as res "RF SEGMENT: Small Business — Charge+Lend"
di as res "-------------------------------------------"
di as res "OOB AUC:              " %5.3f `auc'
di as res "OOB ACC @ .50:        " %5.3f `acc50'
di as res "TRAIN best threshold: " %5.2f best_t
di as res "TRAIN best acc:       " %5.3f best_acc
di as res "==========================================="









*************************************************************
* Random Forest — All Consumers (any charge/lend status)
* DV: roll_forward
* TRAIN: bootstrap (clustered by __rowid)
* TEST: out-of-bag (not drawn)
* RF Hyperparams: ntrees=1000 maxdepth=10 mtry=5
*************************************************************

clear all
set more off

* 1) Load the dataset
local HOME : env HOME
local box  "`HOME'/Library/CloudStorage/Box-Box"
local outdir "`box'/Amex_2025_Class/Joseph"

use "`outdir'/5per_MLA_Cleaned_Rolled_Joseph.dta", clear

* 2) Keep ONLY All Consumers (regardless of charge/lend)
keep if d_consumer == 1
count
di as txt "Rows in ALL CONSUMERS segment: " r(N)
if (r(N) == 0) {
    di as err "No rows in this segment — stopping."
    exit
}

* Confirm DV exists
capture confirm variable roll_forward
if _rc {
    di as err "DV roll_forward not found in this dataset!"
    exit
}

* Ensure stable ID (must exist BEFORE we make temp copies)
capture confirm variable __rowid
if _rc gen long __rowid = _n

* Snapshot this filtered segment (with __rowid) for later merges
tempfile seg_all
save `seg_all', replace

*************************************************************
* 3) Build TRAIN bootstrap sample (from the segment snapshot)
*************************************************************
use `seg_all', clear
set seed 42
capture drop selid
bsample, cluster(__rowid) idcluster(selid)
tempfile train_b
save `train_b', replace

*************************************************************
* 4) Build OOB sample = rows NOT drawn into TRAIN
*************************************************************
use `train_b', clear
keep __rowid
duplicates drop
tempfile in_ids
save `in_ids', replace

use `seg_all', clear                   // use the segment snapshot (has __rowid)
merge 1:1 __rowid using `in_ids'
keep if _merge == 1                    // _merge==1 are the OOB rows
drop _merge
tempfile oob_b
save `oob_b', replace

*************************************************************
* 5) Prepare labels (from the same segment snapshot)
*************************************************************
use `seg_all', clear
keep __rowid roll_forward
tempfile yseg
save `yseg', replace

*************************************************************
* 6) Predictor list (exclude DV, IDs, segment dummies)
*************************************************************
use `seg_all', clear    // build X on the same column set
ds
local all `r(varlist)'
local X : list all - roll_forward
foreach v in id account_id date_var __rowid selid cv5 d_consumer d_chrg d_chrg_lend {
    capture confirm variable `v'
    if !_rc local X : list X - `v'
}
global Xvars `X'
display as text "Predictors: $Xvars"

*************************************************************
* 7) Start H2O & load TRAIN/OOB frames
*************************************************************
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

*************************************************************
* 8) Train Random Forest
*************************************************************
_h2oframe change train_b
h2oml rfbinclass roll_forward $Xvars, ///
    ntrees(1000) maxdepth(10) predsampvalue(5) ///
    h2orseed(42)

* TRAIN predictions — find best threshold
_h2oframe change train_b
capture drop phat_tr
h2omlpredict phat_tr, pr
_h2oframe get train_b, clear
keep __rowid phat_tr
tempfile train_preds
save `train_preds', replace

use `yseg', clear
merge 1:m __rowid using `train_preds'
keep if _merge == 3
drop _merge

* numeric ground truth + sweep thresholds
capture confirm numeric variable roll_forward
if _rc destring roll_forward, replace

gen double phat1_tr = 1 - phat_tr

scalar best_acc = -1
scalar best_t = 0

forvalues i = 0/100 {
    local t = `i'/100
    gen byte __yhat = (phat1_tr >= `t')
    gen byte __ok   = (__yhat == roll_forward)
    quietly summarize __ok
    if (r(mean) > best_acc) {
        scalar best_acc = r(mean)
        scalar best_t = `t'
    }
    drop __yhat __ok
}

*************************************************************
* 9) OOB predictions + metrics
*************************************************************
_h2oframe change oob_b
capture drop phat_oob
h2omlpredict phat_oob, pr
_h2oframe get oob_b, clear
keep __rowid phat_oob
tempfile oob_preds
save `oob_preds', replace

use `yseg', clear
merge 1:1 __rowid using `oob_preds'
keep if _merge == 3
drop _merge

capture confirm numeric variable roll_forward
if _rc destring roll_forward, replace

gen double phat1 = 1 - phat_oob

* AUC (threshold-free)
capture noisily roctab roll_forward phat1, summary
local auc = .
if !_rc local auc = r(area)

* Accuracy @ .50
gen byte yhat50 = (phat1 >= 0.50)
gen byte ok50   = (yhat50 == roll_forward)
quietly summarize ok50
local acc50 = r(mean)
drop yhat50 ok50

*************************************************************
* ✅ RESULTS — PRINT TO SCREEN
*************************************************************
di as res "==============================="
di as res "RF SEGMENT: All Consumers"
di as res "-------------------------------"
di as res "OOB AUC:              " %5.3f `auc'
di as res "OOB ACC @ .50:        " %5.3f `acc50'
di as res "TRAIN best threshold: " %5.2f best_t
di as res "TRAIN best acc:       " %5.3f best_acc
di as res "==============================="









*************************************************************
* Random Forest — All Small Business (any charge/lend status)
* DV: roll_forward
* TRAIN: bootstrap (clustered by __rowid)
* TEST: out-of-bag (not drawn)
* RF Hyperparams: ntrees=1000 maxdepth=10 mtry=5
*************************************************************

clear all
set more off

* 1) Load the dataset
local HOME : env HOME
local box  "`HOME'/Library/CloudStorage/Box-Box"
local outdir "`box'/Amex_2025_Class/Joseph"

use "`outdir'/5per_MLA_Cleaned_Rolled_Joseph.dta", clear

* 2) Keep ONLY All Small Business (regardless of charge/lend)
keep if d_consumer == 0
count
di as txt "Rows in ALL SMALL BUSINESS segment: " r(N)
if (r(N) == 0) {
    di as err "No rows in this segment — stopping."
    exit
}

* Confirm DV exists
capture confirm variable roll_forward
if _rc {
    di as err "DV roll_forward not found in this dataset!"
    exit
}

* Ensure stable ID (must exist BEFORE we make temp copies)
capture confirm variable __rowid
if _rc gen long __rowid = _n

* Snapshot this filtered segment (with __rowid) for later merges
tempfile seg_all
save `seg_all', replace

*************************************************************
* 3) Build TRAIN bootstrap sample (from the segment snapshot)
*************************************************************
use `seg_all', clear
set seed 42
capture drop selid
bsample, cluster(__rowid) idcluster(selid)
tempfile train_b
save `train_b', replace

*************************************************************
* 4) Build OOB sample = rows NOT drawn into TRAIN
*************************************************************
use `train_b', clear
keep __rowid
duplicates drop
tempfile in_ids
save `in_ids', replace

use `seg_all', clear                   // use the segment snapshot (has __rowid)
merge 1:1 __rowid using `in_ids'
keep if _merge == 1                    // _merge==1 are the OOB rows
drop _merge
tempfile oob_b
save `oob_b', replace

*************************************************************
* 5) Prepare labels (from the same segment snapshot)
*************************************************************
use `seg_all', clear
keep __rowid roll_forward
tempfile yseg
save `yseg', replace

*************************************************************
* 6) Predictor list (exclude DV, IDs, segment dummies)
*************************************************************
use `seg_all', clear    // build X on the same column set
ds
local all `r(varlist)'
local X : list all - roll_forward
foreach v in id account_id date_var __rowid selid cv5 d_consumer d_chrg d_chrg_lend {
    capture confirm variable `v'
    if !_rc local X : list X - `v'
}
global Xvars `X'
display as text "Predictors: $Xvars"

*************************************************************
* 7) Start H2O & load TRAIN/OOB frames
*************************************************************
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

*************************************************************
* 8) Train Random Forest
*************************************************************
_h2oframe change train_b
h2oml rfbinclass roll_forward $Xvars, ///
    ntrees(1000) maxdepth(10) predsampvalue(5) ///
    h2orseed(42)

* TRAIN predictions — find best threshold
_h2oframe change train_b
capture drop phat_tr
h2omlpredict phat_tr, pr
_h2oframe get train_b, clear
keep __rowid phat_tr
tempfile train_preds
save `train_preds', replace

use `yseg', clear
merge 1:m __rowid using `train_preds'
keep if _merge == 3
drop _merge

* numeric ground truth + sweep thresholds
capture confirm numeric variable roll_forward
if _rc destring roll_forward, replace

gen double phat1_tr = 1 - phat_tr

scalar best_acc = -1
scalar best_t = 0

forvalues i = 0/100 {
    local t = `i'/100
    gen byte __yhat = (phat1_tr >= `t')
    gen byte __ok   = (__yhat == roll_forward)
    quietly summarize __ok
    if (r(mean) > best_acc) {
        scalar best_acc = r(mean)
        scalar best_t = `t'
    }
    drop __yhat __ok
}

*************************************************************
* 9) OOB predictions + metrics
*************************************************************
_h2oframe change oob_b
capture drop phat_oob
h2omlpredict phat_oob, pr
_h2oframe get oob_b, clear
keep __rowid phat_oob
tempfile oob_preds
save `oob_preds', replace

use `yseg', clear
merge 1:1 __rowid using `oob_preds'
keep if _merge == 3
drop _merge

capture confirm numeric variable roll_forward
if _rc destring roll_forward, replace

gen double phat1 = 1 - phat_oob

* AUC (threshold-free)
capture noisily roctab roll_forward phat1, summary
local auc = .
if !_rc local auc = r(area)

* Accuracy @ .50
gen byte yhat50 = (phat1 >= 0.50)
gen byte ok50   = (yhat50 == roll_forward)
quietly summarize ok50
local acc50 = r(mean)
drop yhat50 ok50

*************************************************************
* ✅ RESULTS — PRINT TO SCREEN
*************************************************************
di as res "==============================="
di as res "RF SEGMENT: All Small Business"
di as res "-------------------------------"
di as res "OOB AUC:              " %5.3f `auc'
di as res "OOB ACC @ .50:        " %5.3f `acc50'
di as res "TRAIN best threshold: " %5.2f best_t
di as res "TRAIN best acc:       " %5.3f best_acc
di as res "==============================="










*************************************************************
* Random Forest — ALL CUSTOMERS (any consumer/smb, any product)
* DV: roll_forward
* TRAIN: bootstrap (clustered by __rowid)
* TEST: out-of-bag (not drawn)
* RF Hyperparams: ntrees=1000 maxdepth=10 mtry=5
*************************************************************

clear all
set more off

* 1) Load the dataset
local HOME : env HOME
local box  "`HOME'/Library/CloudStorage/Box-Box"
local outdir "`box'/Amex_2025_Class/Joseph"

use "`outdir'/5per_MLA_Cleaned_Rolled_Joseph.dta", clear

* (No segment filter — use ALL rows)
count
di as txt "Rows in ALL CUSTOMERS: " r(N)
if (r(N) == 0) {
    di as err "Dataset is empty — stopping."
    exit
}

* Confirm DV exists
capture confirm variable roll_forward
if _rc {
    di as err "DV roll_forward not found in this dataset!"
    exit
}

* Ensure stable ID (must exist BEFORE temp copies)
capture confirm variable __rowid
if _rc gen long __rowid = _n

* Snapshot full data (with __rowid) for merges
tempfile seg_all
save `seg_all', replace


*************************************************************
* 2) Build TRAIN bootstrap sample (from full snapshot)
*************************************************************
use `seg_all', clear
set seed 42
capture drop selid
bsample, cluster(__rowid) idcluster(selid)
tempfile train_b
save `train_b', replace


*************************************************************
* 3) Build OOB sample = rows NOT drawn into TRAIN
*************************************************************
use `train_b', clear
keep __rowid
duplicates drop
tempfile in_ids
save `in_ids', replace

use `seg_all', clear                   // full snapshot (has __rowid)
merge 1:1 __rowid using `in_ids'
keep if _merge == 1                    // _merge==1 are the OOB rows
drop _merge
tempfile oob_b
save `oob_b', replace


*************************************************************
* 4) Prepare labels (from the same snapshot)
*************************************************************
use `seg_all', clear
keep __rowid roll_forward
tempfile yseg
save `yseg', replace


*************************************************************
* 5) Predictor list (exclude DV, IDs, segment dummies)
*************************************************************
use `seg_all', clear    // build X on full column set
ds
local all `r(varlist)'
local X : list all - roll_forward
foreach v in id account_id date_var __rowid selid cv5 d_consumer d_chrg d_chrg_lend {
    capture confirm variable `v'
    if !_rc local X : list X - `v'
}
global Xvars `X'
display as text "Predictors: $Xvars"


*************************************************************
* 6) Start H2O & load TRAIN/OOB frames
*************************************************************
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


*************************************************************
* 7) Train Random Forest
*************************************************************
_h2oframe change train_b
h2oml rfbinclass roll_forward $Xvars, ///
    ntrees(1000) maxdepth(10) predsampvalue(5) ///
    h2orseed(42)

* TRAIN predictions — find best threshold
_h2oframe change train_b
capture drop phat_tr
h2omlpredict phat_tr, pr
_h2oframe get train_b, clear
keep __rowid phat_tr
tempfile train_preds
save `train_preds', replace

use `yseg', clear
merge 1:m __rowid using `train_preds'
keep if _merge == 3
drop _merge

* numeric ground truth + sweep thresholds
capture confirm numeric variable roll_forward
if _rc destring roll_forward, replace

gen double phat1_tr = 1 - phat_tr

scalar best_acc = -1
scalar best_t = 0

forvalues i = 0/100 {
    local t = `i'/100
    gen byte __yhat = (phat1_tr >= `t')
    gen byte __ok   = (__yhat == roll_forward)
    quietly summarize __ok
    if (r(mean) > best_acc) {
        scalar best_acc = r(mean)
        scalar best_t = `t'
    }
    drop __yhat __ok
}


*************************************************************
* 8) OOB predictions + metrics
*************************************************************
_h2oframe change oob_b
capture drop phat_oob
h2omlpredict phat_oob, pr
_h2oframe get oob_b, clear
keep __rowid phat_oob
tempfile oob_preds
save `oob_preds', replace

use `yseg', clear
merge 1:1 __rowid using `oob_preds'
keep if _merge == 3
drop _merge

capture confirm numeric variable roll_forward
if _rc destring roll_forward, replace

gen double phat1 = 1 - phat_oob

* AUC (threshold-free)
capture noisily roctab roll_forward phat1, summary
local auc = .
if !_rc local auc = r(area)

* Accuracy @ .50
gen byte yhat50 = (phat1 >= 0.50)
gen byte ok50   = (yhat50 == roll_forward)
quietly summarize ok50
local acc50 = r(mean)
drop yhat50 ok50


*************************************************************
* ✅ RESULTS — PRINT TO SCREEN
*************************************************************
di as res "==============================="
di as res "RF SEGMENT: ALL CUSTOMERS"
di as res "-------------------------------"
di as res "OOB AUC:              " %5.3f `auc'
di as res "OOB ACC @ .50:        " %5.3f `acc50'
di as res "TRAIN best threshold: " %5.2f best_t
di as res "TRAIN best acc:       " %5.3f best_acc
di as res "==============================="
