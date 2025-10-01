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


*** Calc Roll Fordward Rate ***
summarize past_60_bi past_30_bi
tab past_60_bi





*** Base Model : Roll over = FICO, CDSS, and TSR ***
logit past_60_bi tot_bal_due charge_dum tot_bal_over_exp case_duration tenure charge_lend_bi charge_bi

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

