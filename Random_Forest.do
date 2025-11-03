*** Joseph Lanser | AREC 559
*** Single-model Random Forests chosen by BEST VALIDATION AUC from Grid Search
*** Params: ntrees=250, maxdepth=5, mtry=8

version 18.5
clear all
set more off
set seed 42

// -----------------------------------------------------------------------------
// Helper: train ONE RF on a dataset with forced split (d_train==1 train, 0 valid)
// -----------------------------------------------------------------------------
capture program drop run_one_rf
program define run_one_rf, rclass
    // args: data_path ntrees maxdepth mtry
    args data_path nt md mt

    di as txt "============================================================"
    di as txt "Data: `data_path'"
    di as txt "RF params (AUC-picked): ntrees=`nt' | maxdepth=`md' | mtry=`mt'"
    di as txt "============================================================"

    use "`data_path'", clear

    * --- sanity checks (no braces)
    capture confirm variable roll_forward
    if _rc di as err "DV roll_forward not found — stopping."
    if _rc exit 198

    capture confirm variable d_train
    if _rc di as err "Split flag d_train not found — stopping."
    if _rc exit 198

    capture confirm numeric variable roll_forward
    if _rc destring roll_forward, replace
    assert inlist(roll_forward,0,1)

    capture confirm variable __rowid
    if _rc gen long __rowid = _n

    * --- predictors: drop DV + non-features
    local dep roll_forward
    local dropvars d_train __rowid id account_id date_var cv5 d_consumer d_chrg d_chrg_lend
    ds
    local all `r(varlist)'
    local X : list all - `dep'
    foreach v of local dropvars {
        capture confirm variable `v'
        if !_rc local X : list X - `v'
    }

    local k : word count `X'
    if `k'==0 di as err "No predictors after exclusions — stopping."
    if `k'==0 exit 459
    global Xvars `X'

    * --- materialize splits
    tempfile train_d valid_d yvalid_only
    preserve
        keep if d_train==1
        save `train_d', replace
    restore
    preserve
        keep if d_train==0
        save `valid_d', replace
    restore

    use `valid_d', clear
    keep __rowid roll_forward
    save `yvalid_only', replace

    * --- H2O init
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

    * --- train single RF
    _h2oframe change train_h2o
    h2oml rfbinclass roll_forward $Xvars, ///
        ntrees(`nt') maxdepth(`md') predsampvalue(`mt') h2orseed(42)

    * --- predict on validation
    _h2oframe change valid_h2o
    capture noisily h2omlpredict phat_v, pr

    * --- bring preds back, merge with labels
    _h2oframe get valid_h2o, clear
    keep __rowid phat_v
    tempfile valid_preds
    save `valid_preds', replace

    use `yvalid_only', clear
    merge 1:1 __rowid using `valid_preds'
    keep if _merge==3
    drop _merge

    capture confirm numeric variable roll_forward
    if _rc destring roll_forward, replace

    * --- robust AUC flip (ensure prob for class 1)
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
    local V_AUC = max(`auc_a', `auc_b')

    * --- accuracy @ 0.50 (reference)
    tempvar yhat50 ok50
    gen byte `yhat50' = (phat1 >= 0.50)
    gen byte `ok50'   = (`yhat50' == roll_forward)
    quietly summarize `ok50'
    local V_ACC50 = r(mean)

    * --- best F1 + threshold sweep (0..1 by .01)
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

        if (F1 > best_f1) scalar best_t  = `t'
        if (F1 > best_f1) scalar best_f1 = F1

        drop `yhat' `p' `tp' `fp' `fn'
    }

    * --- metrics at BEST-F1 threshold
    tempvar yhat_best ok_best
    gen byte `yhat_best' = (phat1 >= best_t)
    gen byte `ok_best'   = (`yhat_best' == roll_forward)
    quietly summarize `ok_best'
    local V_ACCBEST = r(mean)

    * confusion matrix + precision/recall/specificity at best_t
    quietly tab `yhat_best' roll_forward, matcell(C)
    scalar TN = C[1,1]
    scalar FN = C[1,2]
    scalar FP = C[2,1]
    scalar TP = C[2,2]
    scalar N  = TN + FP + FN + TP

    scalar PREC = cond(TP+FP>0, TP/(TP+FP), .)
    scalar REC  = cond(TP+FN>0, TP/(TP+FN), .)
    scalar SPEC = cond(TN+FP>0, TN/(TN+FP), .)
    scalar PRED_POS_RATE = cond(N>0, (TP+FP)/N, .)
    scalar BASE_POS_RATE = cond(N>0, (TP+FN)/N, .)

    * probability distribution quick stats
    quietly summarize phat1
    local MEANPHAT = r(mean)
    _pctile phat1, p(1 5 10 25 50 75 90 95 99)
    local p01 = r(r1)
    local p05 = r(r2)
    local p10 = r(r3)
    local p25 = r(r4)
    local p50 = r(r5)
    local p75 = r(r6)
    local p90 = r(r7)
    local p95 = r(r8)
    local p99 = r(r9)

    di as res "------------------------------------------------------------"
    di as res "Validation AUC                  : " %6.4f `V_AUC'
    di as res "Accuracy @ 0.50                : " %6.4f `V_ACC50'
    di as res "Best F1 / Threshold             : " %6.4f best_f1 "  /  " %4.2f best_t
    di as res "Accuracy @ Best-F1 Threshold    : " %6.4f `V_ACCBEST'
    di as res "Precision / Recall / Specificity: " %6.4f PREC "  /  " %6.4f REC "  /  " %6.4f SPEC
    di as res "Predicted-Positive Rate (best)  : " %6.4f PRED_POS_RATE "   vs Base Positive Rate: " %6.4f BASE_POS_RATE
    di as res "Flip used? (1=yes)              : " `use_flip'
    di as res "------------------------------------------------------------"
    di as txt "Confusion matrix at Best-F1 threshold (rows=Pred, cols=Actual):"
    matrix list C
    di as txt "TP: " %10.0f TP "  FP: " %10.0f FP "  FN: " %10.0f FN "  TN: " %10.0f TN
    di as txt "phat1 mean: " %6.4f `MEANPHAT' " | p01 " %5.3f `p01' " p05 " %5.3f `p05' " p10 " %5.3f `p10' ///
        " p25 " %5.3f `p25' " p50 " %5.3f `p50' " p75 " %5.3f `p75' " p90 " %5.3f `p90' " p95 " %5.3f `p95' " p99 " %5.3f `p99'

    * return scalars for programmatic access
    return scalar AUC       = `V_AUC'
    return scalar ACC50     = `V_ACC50'
    return scalar BESTF1    = best_f1
    return scalar BESTTHR   = best_t
    return scalar ACCBEST   = `V_ACCBEST'
    return scalar PREC      = PREC
    return scalar REC       = REC
    return scalar SPEC      = SPEC
    return scalar PPOSRATE  = PRED_POS_RATE
    return scalar BASERATE  = BASE_POS_RATE
    return scalar MEANPHAT  = `MEANPHAT'
    return scalar P99       = `p99'
    return scalar P95       = `p95'
    return scalar P90       = `p90'
    return scalar P75       = `p75'
    return scalar P50       = `p50'
    return scalar P25       = `p25'
    return scalar P10       = `p10'
    return scalar P05       = `p05'
    return scalar P01       = `p01'
end

// -----------------------------------------------------------------------------
// Paths
// -----------------------------------------------------------------------------
local HOME : env HOME
local box  "`HOME'/Library/CloudStorage/Box-Box"
local outdir "`box'/Amex_2025_Class/Joseph"

// -----------------------------------------------------------------------------
// 1) SMALL BUSINESS
// -----------------------------------------------------------------------------
run_one_rf "`outdir'/FINAL_SB.dta" 250 5 8

// -----------------------------------------------------------------------------
// 2) CONSUMERS
// -----------------------------------------------------------------------------
run_one_rf "`outdir'/FINAL_CONS.dta" 250 5 8
