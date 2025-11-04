*==============================*
* GBM final runs + report text
*==============================*
version 18.5
clear all
set more off
set seed 42

* One clean H2O session
cap h2o shutdown, force
h2o init

* -------- helper: train ONE model and print report lines --------
capture program drop run_gbm_report
program define run_gbm_report, rclass
    // args: data_path ntrees maxdepth lrate samprate predsamprate minobsleaf
    args data_path nt md lr sr psr minr

    use "`data_path'", clear
	* drop unwanted predictors (keep DV!)
    drop bal_due bal_over_expr tenure cs_other cs_low_balance cs_currents ///
        cs_seg_a cs_high_balance cs_cfs_team cs_arct_team d_chrg_lend d_chrg num_products
    confirm variable roll_forward
    confirm variable d_train
    capture confirm numeric variable roll_forward
    if _rc destring roll_forward, replace
    assert inlist(roll_forward,0,1)
    capture confirm variable __rowid
    if _rc gen long __rowid = _n

    * predictors (drop dv + non-features)
    local dep roll_forward
    local dropvars d_train __rowid id account_id date_var cv5 d_consumer d_chrg d_chrg_lend
    ds
    local all `r(varlist)'
    local X : list all - `dep'
    foreach v of local dropvars {
        capture confirm variable `v'
        if !_rc local X : list X - `v'
    }
    global Xvars `X'

    * materialize splits
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

    * push frames once
    quietly _h2oframe dir
    capture quietly _h2oframe remove train_h2o
    capture quietly _h2oframe remove valid_h2o

    use `train_d', clear
    _h2oframe put, into(train_h2o) replace
    use `valid_d', clear
    _h2oframe put, into(valid_h2o) replace

    _h2oframe change train_h2o
    _h2oframe factor roll_forward, replace
    _h2oframe change valid_h2o
    _h2oframe factor roll_forward, replace

    * ---- train final GBM with validation frame ----
    _h2oframe change train_h2o
    h2oml gbbinclass roll_forward $Xvars, ///
        validframe(valid_h2o) ///
        ntrees(`nt') maxdepth(`md') lrate(`lr') ///
        samprate(`sr') predsamprate(`psr') ///
        minobsleaf(`minr') h2orseed(42) ///
        scoreevery(50)

    * ---- predict on validation ----
    _h2oframe change valid_h2o
    capture noisily h2omlpredict phat_v, pr

    * ---- bring preds back & merge with truth ----
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

    * ---- robust AUC (flip if needed) ----
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

    * ---- accuracy @ 0.50 ----
    tempvar yhat50 ok50
    gen byte `yhat50' = (phat1 >= 0.50)
    gen byte `ok50'   = (`yhat50' == roll_forward)
    quietly summarize `ok50'
    local V_ACC50 = r(mean)

    * ---- sweep thresholds for BEST F1 ----
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

    * ---- metrics at BEST-F1 threshold ----
    tempvar yhat_best ok_best
    gen byte `yhat_best' = (phat1 >= best_t)
    gen byte `ok_best'   = (`yhat_best' == roll_forward)
    quietly summarize `ok_best'
    local V_ACCBEST = r(mean)

    quietly tab `yhat_best' roll_forward, matcell(C)
    scalar TN = C[1,1]
    scalar FN = C[1,2]
    scalar FP = C[2,1]
    scalar TP = C[2,2]
    scalar N  = TN + FP + FN + TP

    scalar PREC = cond(TP+FP>0, TP/(TP+FP), .)
    scalar REC  = cond(TP+FN>0, TP/(TP+FN), .)
    scalar PRED_POS_RATE = cond(N>0, (TP+FP)/N, .)

    * ---- print in your requested style ----
    di as res "AUC = " %6.4f `V_AUC'
    di as res "Acc @0.5 = " %6.4f `V_ACC50'
    di as res "Best F1 @ " %4.2f best_t
    di as res "Acc @ Best F1 = " %6.4f `V_ACCBEST'
    di as res "With a " %4.2f best_t " cutoff we flag ~" ///
        %4.0f (100*PRED_POS_RATE) "% of accounts and capture ~" ///
        %4.0f (100*REC) "% of the positives"

    * return (optional)
    return scalar AUC     = `V_AUC'
    return scalar ACC50   = `V_ACC50'
    return scalar BESTT   = best_t
    return scalar ACCBEST = `V_ACCBEST'
    return scalar FLAGRT  = PRED_POS_RATE
    return scalar RECALL  = REC
end

* -------- paths --------
local HOME : env HOME
local box  "`HOME'/Library/CloudStorage/Box-Box"
local outdir "`box'/Amex_2025_Class/Joseph"
local dpath_sb   "`outdir'/FINAL_SB.dta"
local dpath_cons "`outdir'/FINAL_CONS.dta"

* --------- FINAL RUNS (optimal params from refined grid) ---------
di as txt "================ SB (final) ================"
run_gbm_report "`dpath_sb'"   1000 1 0.10   0.8 0.6 50

di as txt "================ CONS (final) =============="
run_gbm_report "`dpath_cons'" 1000 5 0.01   0.6 1.0 20
