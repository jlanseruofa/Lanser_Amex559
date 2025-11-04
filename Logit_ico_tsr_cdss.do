*** Joseph Lanser | AREC 559
*** Logistic model with RF-like evaluation on forced split (d_train)
*** Reports: AUC, Acc@0.50, Best F1 + threshold, Acc@BestF1, Prec/Rec/Spec, PPR vs Base, Confusion, phat stats

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


// ------------------------------
// Fit logistic model on training
// ------------------------------
di as txt "Fitting logistic regression on training fold (d_train==1)..."
quietly logit roll_forward ///
    fico tsr cdss

// -------------------------------------
// Predict probabilities on validation
// -------------------------------------
capture drop phat
predict phat if d_train==0, pr

// Safety: ensure validation sample exists
count if d_train==0
if r(N)==0 {
    di as err "No validation observations with d_train==0. Exiting."
    exit 498
}

// -------------------------------------
// 1) AUC (OOB) on validation
// -------------------------------------
// Note: roctab draws a graph by default in modern Stata.
quietly roctab roll_forward phat if d_train==0
scalar auc_oob = r(area)

// -------------------------------------
// 2) Accuracy at 0.50 on validation
// -------------------------------------
capture drop yhat05
gen byte yhat05 = phat>=0.50 if d_train==0

tempname M05
tab yhat05 roll_forward if d_train==0, matcell(`M05') // rows: yhat=0,1 ; cols: y=0,1
scalar Nval = r(N)
scalar tn05 = cond(rowsof(`M05')>=1 & colsof(`M05')>=1, `M05'[1,1], 0)
scalar fn05 = cond(rowsof(`M05')>=1 & colsof(`M05')>=2, `M05'[1,2], 0)
scalar fp05 = cond(rowsof(`M05')>=2 & colsof(`M05')>=1, `M05'[2,1], 0)
scalar tp05 = cond(rowsof(`M05')>=2 & colsof(`M05')>=2, `M05'[2,2], 0)

scalar acc05 = (tn05+tp05)/Nval
scalar prec05 = cond((tp05+fp05)>0, tp05/(tp05+fp05), .)
scalar rec05  = cond((tp05+fn05)>0, tp05/(tp05+fn05), .)
scalar spec05 = cond((tn05+fp05)>0, tn05/(tn05+fp05), .)
scalar ppr05  = (tp05+fp05)/Nval

// -------------------------------------
// 3) Best F1 threshold search (0.00..1.00)
// -------------------------------------
tempname postH
tempfile f1grid
postfile `postH' float(thresh f1 acc prec rec spec tp fp fn tn ppr) using "`f1grid'", replace

forvalues s = 0/100 {
    local t = `s'/100
    capture drop _yhat
    gen byte _yhat = phat>=`t' if d_train==0

    tempname M
    quietly tab _yhat roll_forward if d_train==0, matcell(`M')

    // Extract cells robustly even if some cells are absent
    scalar tn_ = cond(rowsof(`M')>=1 & colsof(`M')>=1, `M'[1,1], 0)
    scalar fn_ = cond(rowsof(`M')>=1 & colsof(`M')>=2, `M'[1,2], 0)
    scalar fp_ = cond(rowsof(`M')>=2 & colsof(`M')>=1, `M'[2,1], 0)
    scalar tp_ = cond(rowsof(`M')>=2 & colsof(`M')>=2, `M'[2,2], 0)
    scalar Ncalc = tn_ + fn_ + fp_ + tp_

    scalar prec_ = cond((tp_+fp_)>0, tp_/(tp_+fp_), .)
    scalar rec_  = cond((tp_+fn_)>0, tp_/(tp_+fn_), .)
    scalar spec_ = cond((tn_+fp_)>0, tn_/(tn_+fp_), .)
    scalar acc_  = cond(Ncalc>0, (tn_+tp_)/Ncalc, .)
    scalar f1_   = cond(prec_<. & rec_<. & (prec_+rec_)>0, 2*prec_*rec_/(prec_+rec_), .)
    scalar ppr_  = cond(Ncalc>0, (tp_+fp_)/Ncalc, .)

    post `postH' (`t') (f1_) (acc_) (prec_) (rec_) (spec_) (tp_) (fp_) (fn_) (tn_) (ppr_)
}
postclose `postH'

preserve
use "`f1grid'", clear
gsort -f1 // best first
keep in 1
scalar t_best    = thresh[1]
scalar f1_best   = f1[1]
scalar acc_best  = acc[1]
scalar prec_best = prec[1]
scalar rec_best  = rec[1]
scalar spec_best = spec[1]
scalar tp_best   = tp[1]
scalar fp_best   = fp[1]
scalar fn_best   = fn[1]
scalar tn_best   = tn[1]
scalar ppr_best  = ppr[1]
restore

// -------------------------------------
// 4) Base rate, phat stats, and "all true/false" flags
// -------------------------------------
summ roll_forward if d_train==0, meanonly
scalar base_rate = r(mean)

summ phat if d_train==0, detail
scalar phat_min  = r(min)
scalar phat_p25  = r(p25)
scalar phat_med  = r(p50)
scalar phat_p75  = r(p75)
scalar phat_max  = r(max)
scalar phat_mean = r(mean)
scalar phat_sd   = r(sd)

// "All false / all true" diagnostics at 0.50
scalar all_false_05 = (ppr05==0)
scalar all_true_05  = (ppr05==1)

// -------------------------------------
// 5) Pretty print results
// -------------------------------------
di as txt "------------------ VALIDATION (d_train==0) ------------------"
di as res "AUC (OOB): " %6.4f auc_oob
di as res "Base rate (mean of y): " %6.4f base_rate
di as txt " "
di as txt "== Accuracy @ 0.50 =="
di as res "Accuracy: " %6.4f acc05 "   Precision: " %6.4f prec05 "   Recall: " %6.4f rec05 "   Specificity: " %6.4f spec05
di as res "PPR (share predicted positives): " %6.4f ppr05
di as txt "Confusion (rows=yhat, cols=y): [ (0,0)=TN  (0,1)=FN ; (1,0)=FP  (1,1)=TP ]"
mat list `M05', format(%9.0g)
if all_false_05 di as err "Note: At threshold 0.50, model predicts ALL negatives."
if all_true_05  di as err "Note: At threshold 0.50, model predicts ALL positives."
di as txt " "
di as txt "== Best F1 Threshold Search (0.00..1.00) =="
di as res "Best F1: " %6.4f f1_best " at threshold = " %5.2f t_best
di as res "Acc@BestF1: " %6.4f acc_best "   Precision: " %6.4f prec_best "   Recall: " %6.4f rec_best "   Specificity: " %6.4f spec_best
di as res "PPR@BestF1: " %6.4f ppr_best
di as txt "Confusion@BestF1 (TP,FP,FN,TN): " %9.0g tp_best "  " %9.0g fp_best "  " %9.0g fn_best "  " %9.0g tn_best
di as txt " "
di as txt "== phat (validation) summary =="
di as res "min: " %6.4f phat_min "   p25: " %6.4f phat_p25 "   median: " %6.4f phat_med "   p75: " %6.4f phat_p75 "   max: " %6.4f phat_max
di as res "mean: " %6.4f phat_mean "   sd: " %6.4f phat_sd
di as txt "--------------------------------------------------------------"










version 18.5
clear all
set more off
set seed 42

// =========================================================================
// =============== RUN 2: CONSUMER (FINAL_CONS.dta) ====================
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

// ------------------------------
// Fit logistic model on training
// ------------------------------
di as txt "Fitting logistic regression on training fold (d_train==1)..."
quietly logit roll_forward ///
    fico tsr cdss

// -------------------------------------
// Predict probabilities on validation
// -------------------------------------
capture drop phat
predict phat if d_train==0, pr

// Safety: ensure validation sample exists
count if d_train==0
if r(N)==0 {
    di as err "No validation observations with d_train==0. Exiting."
    exit 498
}

// -------------------------------------
// 1) AUC (OOB) on validation
// -------------------------------------
// Note: roctab draws a graph by default in modern Stata.
quietly roctab roll_forward phat if d_train==0
scalar auc_oob = r(area)

// -------------------------------------
// 2) Accuracy at 0.50 on validation
// -------------------------------------
capture drop yhat05
gen byte yhat05 = phat>=0.50 if d_train==0

tempname M05
tab yhat05 roll_forward if d_train==0, matcell(`M05') // rows: yhat=0,1 ; cols: y=0,1
scalar Nval = r(N)
scalar tn05 = cond(rowsof(`M05')>=1 & colsof(`M05')>=1, `M05'[1,1], 0)
scalar fn05 = cond(rowsof(`M05')>=1 & colsof(`M05')>=2, `M05'[1,2], 0)
scalar fp05 = cond(rowsof(`M05')>=2 & colsof(`M05')>=1, `M05'[2,1], 0)
scalar tp05 = cond(rowsof(`M05')>=2 & colsof(`M05')>=2, `M05'[2,2], 0)

scalar acc05 = (tn05+tp05)/Nval
scalar prec05 = cond((tp05+fp05)>0, tp05/(tp05+fp05), .)
scalar rec05  = cond((tp05+fn05)>0, tp05/(tp05+fn05), .)
scalar spec05 = cond((tn05+fp05)>0, tn05/(tn05+fp05), .)
scalar ppr05  = (tp05+fp05)/Nval

// -------------------------------------
// 3) Best F1 threshold search (0.00..1.00)
// -------------------------------------
tempname postH
tempfile f1grid
postfile `postH' float(thresh f1 acc prec rec spec tp fp fn tn ppr) using "`f1grid'", replace

forvalues s = 0/100 {
    local t = `s'/100
    capture drop _yhat
    gen byte _yhat = phat>=`t' if d_train==0

    tempname M
    quietly tab _yhat roll_forward if d_train==0, matcell(`M')

    // Extract cells robustly even if some cells are absent
    scalar tn_ = cond(rowsof(`M')>=1 & colsof(`M')>=1, `M'[1,1], 0)
    scalar fn_ = cond(rowsof(`M')>=1 & colsof(`M')>=2, `M'[1,2], 0)
    scalar fp_ = cond(rowsof(`M')>=2 & colsof(`M')>=1, `M'[2,1], 0)
    scalar tp_ = cond(rowsof(`M')>=2 & colsof(`M')>=2, `M'[2,2], 0)
    scalar Ncalc = tn_ + fn_ + fp_ + tp_

    scalar prec_ = cond((tp_+fp_)>0, tp_/(tp_+fp_), .)
    scalar rec_  = cond((tp_+fn_)>0, tp_/(tp_+fn_), .)
    scalar spec_ = cond((tn_+fp_)>0, tn_/(tn_+fp_), .)
    scalar acc_  = cond(Ncalc>0, (tn_+tp_)/Ncalc, .)
    scalar f1_   = cond(prec_<. & rec_<. & (prec_+rec_)>0, 2*prec_*rec_/(prec_+rec_), .)
    scalar ppr_  = cond(Ncalc>0, (tp_+fp_)/Ncalc, .)

    post `postH' (`t') (f1_) (acc_) (prec_) (rec_) (spec_) (tp_) (fp_) (fn_) (tn_) (ppr_)
}
postclose `postH'

preserve
use "`f1grid'", clear
gsort -f1 // best first
keep in 1
scalar t_best    = thresh[1]
scalar f1_best   = f1[1]
scalar acc_best  = acc[1]
scalar prec_best = prec[1]
scalar rec_best  = rec[1]
scalar spec_best = spec[1]
scalar tp_best   = tp[1]
scalar fp_best   = fp[1]
scalar fn_best   = fn[1]
scalar tn_best   = tn[1]
scalar ppr_best  = ppr[1]
restore

// -------------------------------------
// 4) Base rate, phat stats, and "all true/false" flags
// -------------------------------------
summ roll_forward if d_train==0, meanonly
scalar base_rate = r(mean)

summ phat if d_train==0, detail
scalar phat_min  = r(min)
scalar phat_p25  = r(p25)
scalar phat_med  = r(p50)
scalar phat_p75  = r(p75)
scalar phat_max  = r(max)
scalar phat_mean = r(mean)
scalar phat_sd   = r(sd)

// "All false / all true" diagnostics at 0.50
scalar all_false_05 = (ppr05==0)
scalar all_true_05  = (ppr05==1)

// -------------------------------------
// 5) Pretty print results
// -------------------------------------
di as txt "------------------ VALIDATION (d_train==0) ------------------"
di as res "AUC (OOB): " %6.4f auc_oob
di as res "Base rate (mean of y): " %6.4f base_rate
di as txt " "
di as txt "== Accuracy @ 0.50 =="
di as res "Accuracy: " %6.4f acc05 "   Precision: " %6.4f prec05 "   Recall: " %6.4f rec05 "   Specificity: " %6.4f spec05
di as res "PPR (share predicted positives): " %6.4f ppr05
di as txt "Confusion (rows=yhat, cols=y): [ (0,0)=TN  (0,1)=FN ; (1,0)=FP  (1,1)=TP ]"
mat list `M05', format(%9.0g)
if all_false_05 di as err "Note: At threshold 0.50, model predicts ALL negatives."
if all_true_05  di as err "Note: At threshold 0.50, model predicts ALL positives."
di as txt " "
di as txt "== Best F1 Threshold Search (0.00..1.00) =="
di as res "Best F1: " %6.4f f1_best " at threshold = " %5.2f t_best
di as res "Acc@BestF1: " %6.4f acc_best "   Precision: " %6.4f prec_best "   Recall: " %6.4f rec_best "   Specificity: " %6.4f spec_best
di as res "PPR@BestF1: " %6.4f ppr_best
di as txt "Confusion@BestF1 (TP,FP,FN,TN): " %9.0g tp_best "  " %9.0g fp_best "  " %9.0g fn_best "  " %9.0g tn_best
di as txt " "
di as txt "== phat (validation) summary =="
di as res "min: " %6.4f phat_min "   p25: " %6.4f phat_p25 "   median: " %6.4f phat_med "   p75: " %6.4f phat_p75 "   max: " %6.4f phat_max
di as res "mean: " %6.4f phat_mean "   sd: " %6.4f phat_sd
di as txt "--------------------------------------------------------------"










*** MARGINAL EFFECTS (using delta-method) ***
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

// ------------------------ Logit on training set ---------------------------
logit roll_forward ///
    fico tsr cdss num_products bal_due bal_over_expr tenure ///
    cs_other cs_low_balance cs_currents cs_seg_a cs_high_balance ///
    cs_cfs_team cs_arct_team d_chrg_lend d_chrg ///
    if d_train == 1

// ---------------- Marginal effects (delta method) -------------------------
// Average marginal effects (AME) across the training sample
margins, dydx(*) vce(delta)






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

// ------------------------ Logit on training set ---------------------------
logit roll_forward ///
    fico tsr cdss num_products bal_due bal_over_expr tenure ///
    cs_other cs_low_balance cs_currents cs_seg_a cs_high_balance ///
    cs_cfs_team cs_arct_team d_chrg_lend d_chrg ///
    if d_train == 1

// ---------------- Marginal effects (delta method) -------------------------
// Average marginal effects (AME) across the training sample
margins, dydx(*) vce(delta)
