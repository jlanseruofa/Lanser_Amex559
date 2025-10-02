*** Joseph Lanser ***
*** Doing some prelim analysis on my 1 percent rolled up and cleaned dataset ***


* Open cleaned dataset from box *

clear all

* --------- settings (same base as your working raw path) ---------
local HOME : env HOME
local box  "`HOME'/Library/CloudStorage/Box-Box"

* Target folder inside Amex_2025_Class
local outdir "`box'/Amex_2025_Class/Joseph"

* --------- load the cleaned rolled dataset ---------
use "`outdir'/Cleaned_Rolled_Joseph.dta", clear

* Quick checks
describe
summarize
count
drop __000000


*** Calc Roll Fordward Rate ***
summarize past_60_bi past_30_bi
tab past_60_bi





*** Base Model : Roll over = FICO, CDSS, and TSR ***
logit past_60_bi fico_verypoor fico_poor fico_good fico_verygood fico_excellent cdss_score tsr_score

margins, dydx(*)






*** Advanced Model : Roll Over = FICO, CDSS, TSR, Total balance due, customer vs small business binary, ***
*** charge vs lend binary, case duration, tenure, credit segments ***
logit past_60_bi ///
    fico tsr_0 tsr_1 cdss_0 cdss_1 ///
    tsr_bin1 tsr_bin2 tsr_bin3 tsr_bin4 tsr_bin5 tsr_bin6 tsr_bin7 tsr_bin8 tsr_bin9 ///
    cdss_bin1 cdss_bin2 cdss_bin3 cdss_bin4 cdss_bin5 cdss_bin6 cdss_bin7 cdss_bin8 cdss_bin9 ///
    cust_bi tot_bal_due charge_dum tot_bal_over_exp case_duration tenure ///
    cs_other cs_low_balance cs_currents cs_seg_a cs_high_balance cs_cfs_team cs_arct_team

	margins, dydx(*)
	
	
	
* Check predictive power *	
preserve

* 1. Predict probabilities
predict phat, pr

* 2. Turn probabilities into 0/1 predictions
gen yhat = (phat >= 0.5)

* 3. Quick look at prediction vs. actual
tabulate past_60_bi yhat, row col

* 4. Classification stats (accuracy, sensitivity, specificity)
estat classification

* 5. Optional: correlation between predicted probability & actual
correlate past_60_bi phat

restore








*** Running separate models for charge, lend, charge+lend, consumer, small business. ***
*** 6 total models ***

****************************************************
* Logistic regressions by customer segment
* cust_bi = 1 consumer, 0 small business
* charge_dum = 1 charge, 0 lend
* charge_lend_bi = 1 charge+lend
****************************************************

****************************************************
* Logistic regressions by customer segment
* past_60_bi = dependent variable
* Predictors: fico tsr_score cdss_score num_products tot_bal_due tot_bal_over_exp tenure
* cust_bi = 1 consumer, 0 small business
* charge_dum = 1 charge, 0 lend
* charge_lend_bi = 1 charge+lend
****************************************************

*--- 1. Consumer Charge
logit past_60_bi fico tsr_score cdss_score num_products tot_bal_due tot_bal_over_exp tenure ///
    if cust_bi==1 & charge_dum==1 & charge_lend_bi==0
margins, dydx(*) post

*--- 2. Consumer Lend
logit past_60_bi fico tsr_score cdss_score num_products tot_bal_due tot_bal_over_exp tenure ///
    if cust_bi==1 & charge_dum==0 & charge_lend_bi==0
margins, dydx(*) post

*--- 3. Consumer Charge + Lend
logit past_60_bi fico tsr_score cdss_score num_products tot_bal_due tot_bal_over_exp tenure ///
    if cust_bi==1 & charge_lend_bi==1
margins, dydx(*) post

*--- 4. Small Business Charge
logit past_60_bi fico tsr_score cdss_score num_products tot_bal_due tot_bal_over_exp tenure ///
    if cust_bi==0 & charge_dum==1 & charge_lend_bi==0
margins, dydx(*) post

*--- 5. Small Business Lend
logit past_60_bi fico tsr_score cdss_score num_products tot_bal_due tot_bal_over_exp tenure ///
    if cust_bi==0 & charge_dum==0 & charge_lend_bi==0
margins, dydx(*) post

*--- 6. Small Business Charge + Lend
logit past_60_bi fico tsr_score cdss_score num_products tot_bal_due tot_bal_over_exp tenure ///
    if cust_bi==0 & charge_lend_bi==1
margins, dydx(*) post





* AI idea ***
****************************************************
* Build and test a pooled logistic model vs. separate segments
* DV: past_60_bi
* Predictors: fico tsr_score cdss_score num_products tot_bal_due tot_bal_over_exp tenure
* Segments: 
*   1 = Consumer Charge
*   2 = Consumer Lend
*   3 = Consumer Charge+Lend
*   4 = Small Business Charge
*   5 = Small Business Lend
*   6 = Small Business Charge+Lend
****************************************************

*--- Create one segment variable
gen seg = .
replace seg = 1 if cust_bi==1 & charge_dum==1 & charge_lend_bi==0
replace seg = 2 if cust_bi==1 & charge_dum==0 & charge_lend_bi==0
replace seg = 3 if cust_bi==1 & charge_lend_bi==1
replace seg = 4 if cust_bi==0 & charge_dum==1 & charge_lend_bi==0
replace seg = 5 if cust_bi==0 & charge_dum==0 & charge_lend_bi==0
replace seg = 6 if cust_bi==0 & charge_lend_bi==1

label define seglbl 1 "C-Charge" 2 "C-Lend" 3 "C-Both" 4 "SB-Charge" 5 "SB-Lend" 6 "SB-Both"
label values seg seglbl

****************************************************
*--- Fit pooled model with full interactions
****************************************************
logit past_60_bi i.seg##c.(fico tsr_score cdss_score num_products tot_bal_due tot_bal_over_exp tenure)

****************************************************
*--- Global test: do slopes differ across segments?
****************************************************
testparm i.seg#c.(fico tsr_score cdss_score num_products tot_bal_due tot_bal_over_exp tenure)

****************************************************
*--- Variable-by-variable slope difference tests
****************************************************
testparm i.seg#c.fico
testparm i.seg#c.tsr_score
testparm i.seg#c.cdss_score
testparm i.seg#c.num_products
testparm i.seg#c.tot_bal_due
testparm i.seg#c.tot_bal_over_exp
testparm i.seg#c.tenure

****************************************************
*--- Margins: AMEs of each predictor by segment
****************************************************
margins, dydx(fico tsr_score cdss_score num_products tot_bal_due tot_bal_over_exp tenure) over(seg)

****************************************************
*--- (Optional) Export margins to Excel
****************************************************
* Uncomment next lines if you have outreg2 installed
* margins, dydx(fico tsr_score cdss_score num_products tot_bal_due tot_bal_over_exp tenure) over(seg) post
* outreg2 using "pooled_margins_by_segment.xlsx", replace excel

****************************************************
*--- (Optional) Compare information criteria (AIC/BIC)
****************************************************
estat ic





*** Looking a roll forward rate by month, signficance test ***

****************************************************
* Monthly mean of past_60_bi using act_dt (YYYY-MM-DD)
****************************************************

preserve

*--- 1. Extract month from act_dt (YYYY-MM-DD) ---
gen str2 month = substr(act_dt, 6, 2)

*--- 2. View mean past_60_bi by month ---
table month, statistic(mean past_60_bi) nformat(%9.3f)

****************************************************
* 3. Significance test between months
****************************************************
tabulate month past_60_bi, chi2


restore
****************************************************





*** roll over and tenure comparison ***
****************************************************
* Compare tenure & tenure_squared to past_60_bi
****************************************************

preserve

*--- 1. Summary stats of tenure by rollover ---
tabstat tenure tenure_squared, by(past_60_bi) stats(mean sd n)

*--- 2. Test mean differences ---
ttest tenure, by(past_60_bi)
ttest tenure_squared, by(past_60_bi)

*--- 3. Logistic regression: rollover ~ tenure + tenure^2 ---
logit past_60_bi tenure tenure_squared

*--- 4. Marginal effects / predicted probabilities ---
margins, at(tenure=(0(12)120))  // predicted at 0,12,24,...,120 months
marginsplot, ytitle("Pr(past_60_bi=1)") xtitle("Tenure (months)")

restore
****************************************************







*** Threshold for predictions test ***
****************************************************
* Logistic model & threshold sweep (keeps data)
****************************************************



* Open cleaned dataset from box *

clear all

* --------- settings (same base as your working raw path) ---------
local HOME : env HOME
local box  "`HOME'/Library/CloudStorage/Box-Box"

* Target folder inside Amex_2025_Class
local outdir "`box'/Amex_2025_Class/Joseph"

* --------- load the cleaned rolled dataset ---------
use "`outdir'/Cleaned_Rolled_Joseph.dta", clear
drop __000000

****************************************************
* Logistic model for past_60_bi & threshold analysis
****************************************************

*--- 1. Fit the logistic model
logit past_60_bi ///
    tsr_score cdss_score tot_bal_due tot_bal_over_exp ///
    cust_bi cs_other cs_low_balance cs_currents cs_seg_a ///
    cs_high_balance cs_cfs_team cs_arct_team ///
    charge_lend_bi charge_bi multiple_products ///
    fico_verypoor fico_poor fico_good fico_verygood fico_excellent ///
    tenure_squared tenure

*--- 2. Predict probabilities
predict phat, pr

*--- 3. Accuracy at 0.5 cutoff
gen yhat50 = (phat >= 0.5)
tab past_60_bi yhat50, row col
display "Accuracy (50% cutoff) = " 100*sum(yhat50==past_60_bi)/_N "%"

*--- 4. Sweep thresholds (0.05 to 0.95) and collect accuracy, sens, spec
tempname M
matrix `M' = J(19,4,.)
local row = 1
forvalues t = 5(5)95 {
    local c = `t'/100
    gen ytmp = (phat >= `c')

    quietly count if ytmp==past_60_bi
    local acc = r(N)/_N

    quietly count if ytmp==1 & past_60_bi==1
    local TP = r(N)
    quietly count if past_60_bi==1
    local P = r(N)

    quietly count if ytmp==0 & past_60_bi==0
    local TN = r(N)
    quietly count if past_60_bi==0
    local N = r(N)

    local sens = cond(`P'>0, `TP'/`P',.)
    local spec = cond(`N'>0, `TN'/`N',.)

    matrix `M'[`row',1] = `c'
    matrix `M'[`row',2] = `acc'
    matrix `M'[`row',3] = `sens'
    matrix `M'[`row',4] = `spec'
    local ++row

    drop ytmp
}
matrix colnames `M' = threshold accuracy sensitivity specificity
matlist `M', format(%6.3f)

*--- 5. ROC curve & AUC
lroc
estat classification
****************************************************




* best % accuracy *
****************************************************
* Find cutoff that maximizes classification accuracy
****************************************************

* assumes you have already run:
*   logit past_60_bi ... 
*   predict phat, pr

tempname results
matrix `results' = J(99,2,.)
local row = 1

forvalues i = 1/99 {
    local c = `i'/100
    gen ytmp = (phat >= `c')
    quietly count if ytmp==past_60_bi
    local acc = r(N)/_N
    matrix `results'[`row',1] = `c'
    matrix `results'[`row',2] = `acc'
    local ++row
    drop ytmp
}

matrix colnames `results' = cutoff accuracy
matlist `results', format(%6.3f)

* --- find max accuracy and its cutoff ---
mata:
st_matrix("best", select(st_matrix("`results'"), (st_matrix("`results'")[.,2] :== max(st_matrix("`results'")[.,2]))))
end

display "Best cutoff = " best[1,1]
display "Max accuracy = " 100*best[1,2] "%"

