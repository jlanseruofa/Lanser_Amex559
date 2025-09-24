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





* Prelim Log Model Setup *

* Logit Regression *
logit past_60_bi fico tsr_0 tsr_999 cdss_0 cdss_999 ///
    tsr_bin1 tsr_bin2 tsr_bin3 tsr_bin4 tsr_bin5 tsr_bin6 tsr_bin7 tsr_bin8 tsr_bin9 ///
    cdss_bin1 cdss_bin2 cdss_bin3 cdss_bin4 cdss_bin5 cdss_bin6 cdss_bin7 cdss_bin8 cdss_bin9 ///
    tenure tot_past_due_chrg_am tot_past_due_lend_am tot_bal_over_exp num_products ///
    cust_bi smbus_bi charge_dum lend_dum ///
    cs_other cs_low_balance cs_currents cs_seg_a cs_high_balance cs_cfs_team cs_arct_team
	
predict phat, pr


	
* Odds ratios (easier interpretation) *
logistic past_60_bi fico tsr_0 tsr_999 cdss_0 cdss_999 ///
    tsr_bin1 tsr_bin2 tsr_bin3 tsr_bin4 tsr_bin5 tsr_bin6 tsr_bin7 tsr_bin8 tsr_bin9 ///
    cdss_bin1 cdss_bin2 cdss_bin3 cdss_bin4 cdss_bin5 cdss_bin6 cdss_bin7 cdss_bin8 cdss_bin9 ///
    tenure tot_past_due_chrg_am tot_past_due_lend_am tot_bal_over_exp num_products ///
    cust_bi smbus_bi charge_dum lend_dum ///
    cs_other cs_low_balance cs_currents cs_seg_a cs_high_balance cs_cfs_team cs_arct_team
	
predict phat, pr

	
* Phat minus P *
gen resid = past_60_bi - phat
summarize resid
corr past_60_bi phat

*Visaul
twoway (scatter past_60_bi phat, jitter(3)) (lfit past_60_bi phat)



