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
logit past_60_bi fico tsr_0 tsr_1 cdss_0 cdss_1 ///
    tsr_bin1 tsr_bin2 tsr_bin3 tsr_bin4 tsr_bin5 tsr_bin6 tsr_bin7 tsr_bin8 tsr_bin9 ///
    cdss_bin1 cdss_bin2 cdss_bin3 cdss_bin4 cdss_bin5 cdss_bin6 cdss_bin7 cdss_bin8 cdss_bin9

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
