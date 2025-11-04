version 18.5
clear all
set more off
set seed 42

* ---------- helper: safely drop variables if they exist ----------
capture program drop _safe_drop
program define _safe_drop
    gettoken list 0 : 0
    local todrop
    foreach v of local list {
        capture confirm variable `v'
        if !_rc local todrop `todrop' `v'
    }
    if "`todrop'" != "" drop `todrop'
end

* ---------- train ONE RF on (d_train==1 train, 0 valid) ----------
capture program drop run_one_rf
program define run_one_rf, rclass
    args data_path nt md mt

    di as txt "============================================================"
    di as txt "Data: `data_path'"
    di as txt "RF: ntrees=`nt' | maxdepth=`md' | mtry=`mt'"
    di as txt "============================================================"

    use "`data_path'", clear

    * drop unwanted predictors (keep DV!)
    _safe_drop bal_due bal_over_expr tenure cs_other cs_low_balance cs_currents ///
        cs_seg_a cs_high_balance cs_cfs_team cs_arct_team d_chrg_lend d_chrg num_products

    * sanity checks
    capture confirm variable roll_forward
    if _rc exit 198
    capture confirm variable d_train
    if _rc exit 198
    capture confirm numeric variable roll_forward
    if _rc destring roll_forward, replace
    capture confirm variable __rowid
    if _rc gen long __rowid = _n

    * feature set
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
    if `k'==0 exit 459
    global Xvars `X'

    * splits
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

    * H2O
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

    * train RF
    _h2oframe change train_h2o
    h2oml rfbinclass roll_forward $Xvars, ///
        ntrees(`nt') maxdepth(`md') predsampvalue(`mt') h2orseed(42)

    * predict on valid
    _h2oframe change valid_h2o
    capture noisily h2omlpredict phat_v, pr
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

    * ensure prob for class 1
    tempvar p1a p1b
    gen double `p1a' = phat_v
    gen double `p1b' = 1 - phat_v
    capture noisily roctab roll_forward `p1a', summary
    local auc_a = cond(_rc,.,r(area))
    capture noisily roctab roll_forward `p1b', summary
    local auc_b = cond(_rc,.,r(area))
    local use_flip = (`auc_b' > `auc_a')
    gen double phat1 = cond(`use_flip', `p1b', `p1a')
    local V_AUC = max(`auc_a', `auc_b')

    * metrics @ 0.50
    tempvar yhat50 ok50
    gen byte `yhat50' = (phat1 >= 0.50)
    gen byte `ok50'   = (`yhat50' == roll_forward)
    quietly summarize `ok50'
    local V_ACC50 = r(mean)

    * best-F1 sweep
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

    * return
    return scalar AUC       = `V_AUC'
    return scalar ACC50     = `V_ACC50'
    return scalar BESTF1    = best_f1
    return scalar BESTTHR   = best_t
end

* ---------- paths & calls (RF) ----------
local HOME : env HOME
local box  "`HOME'/Library/CloudStorage/Box-Box"
local outdir "`box'/Amex_2025_Class/Joseph"

* Small Business RF
run_one_rf "`outdir'/FINAL_SB.dta"   250 5 8
* Consumers RF
run_one_rf "`outdir'/FINAL_CONS.dta" 500 5 8
