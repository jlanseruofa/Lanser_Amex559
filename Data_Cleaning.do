*** Joseph Lanser Data Cleaning for 1 percent data file ***
*** This file will create new variables needed, clear out uneeded variables, ***
*** filter out unwanted cases, and roll up data to only that of which at case open ***
*** Then this file will roll up based on the EN act code (case open only data) ***



clear all


*** Step 1: Load in .dta 1 percent data sample to be used ***
* --------- settings (same base as your working raw path) ---------
local HOME : env HOME
local box  "`HOME'/Library/CloudStorage/Box-Box"

* Swap Raw Data -> Random Samples
local proj_raw  "Amex_2025_Class/Raw Data"
local proj_rand : subinstr local proj_raw "Raw Data" "Random Samples", all

* --------- import the 1% sample CSV ---------
import delimited using "`box'/`proj_rand'/amex_1_pct.csv", varnames(1) clear

* (optional) save a .dta copy for fast reloads
compress
save "`box'/`proj_rand'/amex_1_pct.dta", replace

describe
count




*** Step 2: Delete all uneeded variables (they will still be saved on the 1 percent data file) ***

* Drop unwanted vars
drop pseudo_key
drop case_seq_no
drop case_setup_type
drop act_seq_no
drop ctc_plce_cd
drop ctc_prty_cd
drop rule_no
drop portfo_w_lvl_cd
drop portfo_sta_lvl_cd
drop act_info_cd1 act_info_cd2 act_info_cd3
drop sprt_no sprt_keep_day_ct sprt_duns_am
drop cust_chrg_lend_expsr_lvl_am cust_chrg_card_loc_expsr_lvl_am
drop payment_amount
drop lift_dt
drop letter_code
drop strategy1_cd strategy2_cd strategy3_cd strategy4_cd
drop product_types pseudo_key_file1 pseudo_key_new pseudo_key_file2 pseudo_key_file3 pseudo_key_file4


*** Step 3: Create new variables needed for analysis

* CUST/COMP Binary Creation
* Generate customer binary: 1 if CUST, 0 if COMP
gen cust_bi = .
replace cust_bi = 1 if case_grp_cd == "CUST"
replace cust_bi = 0 if case_grp_cd == "COMP"

* Generate small business binary: 1 if COMP, 0 if CUST
gen smbus_bi = .
replace smbus_bi = 1 if case_grp_cd == "COMP"
replace smbus_bi = 0 if case_grp_cd == "CUST"


* Total Balance Due Variable, Binary Charge/Lend Dummies *
gen tot_bal_due = tot_due_chrg_am + tot_due_lend_am

* Charge dummy: 1 if nonzero, 0 if zero
gen charge_dum = (tot_due_chrg_am != 0) if !missing(tot_due_chrg_am)

* Lend dummy: 1 if nonzero, 0 if zero
gen lend_dum = (tot_due_lend_am != 0) if !missing(tot_due_lend_am)



* Total Balance Due / Total Case Exposure Variable *
gen tot_bal_over_exp = tot_bal_due / total_case_exposure


* Code FICO scores to missing if the customer is COMP, since it is not relevant in that case *
* replace fico = . if case_grp_cd == "COMP"




*** Step 4: Continue to filter data and create needed vars ***
****************************************************
* STEP. Sort data by triplicate and action date
****************************************************
sort triplicate act_dt act_tm

****************************************************
* STEP. Drop triplicates where EN is not the first act
****************************************************
bys triplicate (act_dt act_tm): gen first_act = act_type_cd[1]
drop if first_act != "EN"
drop first_act

****************************************************
* STEP. Case duration: open = EN, close = RI or SI
****************************************************
* Make sure act_dt is numeric %td (convert if still string)
capture confirm numeric variable act_dt
if _rc {
    gen double act_dt_num = date(act_dt, "YMD")
    format act_dt_num %td
}
else {
    gen double act_dt_num = act_dt
}

* Earliest EN date (case open)
bys triplicate (act_dt_num): egen open_dt = min(cond(act_type_cd=="EN", act_dt_num, .))

* Earliest closing date (RI or SI) after EN
bys triplicate (act_dt_num): egen close_dt = min(cond(inlist(act_type_cd,"RI","SI"), act_dt_num, .))

* Duration in days
gen case_duration = close_dt - open_dt

****************************************************
* STEP. Flags for past 30 and 60 days (from all rows)
****************************************************
bys triplicate: egen past_30_bi = max(age_day_ct > 30)
bys triplicate: egen past_60_bi = max(age_day_ct >= 60)

****************************************************
* STEP. Clean FICO values
****************************************************
replace fico = . if fico < 350 | fico > 850





* STEP. Create tenure based on earliest anniv date *
* Make sure the date variables are Stata dates (numeric daily dates).
* If anniv_chrg_dt and anniv_lend_dt are strings like "YYYY-MM-DD", convert them:
gen double chrg_date = daily(anniv_chrg_dt, "YMD")
gen double lend_date = daily(anniv_lend_dt, "YMD")
format chrg_date lend_date %td

* Step 2: Pick the earliest date
egen double start_date = rowmin(chrg_date lend_date)
format start_date %td

* Step 3: Calculate tenure in years
gen tenure = (today() - start_date) / 365.25




* STEP. Create credit segment dummies *
gen cs_other        = (credit_segment == "Other")
gen cs_low_balance  = (credit_segment == "Low Balance")
gen cs_currents     = (credit_segment == "Currents")
gen cs_seg_a        = (credit_segment == "Seg A")
gen cs_high_balance = (credit_segment == "High Balance")
gen cs_cfs_team     = (credit_segment == "CFS Team")
gen cs_arct_team    = (credit_segment == "ARCT Team")






* STEP. Create dummies for TSR and CDSS Scores *
* TSR score exact bins
gen tsr_0    = (tsr_score == 0)
gen tsr_999  = (tsr_score == .999)

* CDSS score exact bins
gen cdss_0   = (cdss_score == 0)
gen cdss_999 = (cdss_score == .999)


* TSR bins (excluding 0 and .999)
forvalues i = 1/9 {
    local lo = (`i'-1)/10
    local hi = `i'/10
    gen tsr_bin`i' = (tsr_score > `lo' & tsr_score <= `hi' & tsr_score != 0 & tsr_score != .999)
}

* CDSS bins (excluding 0 and .999)
forvalues i = 1/9 {
    local lo = (`i'-1)/10
    local hi = `i'/10
    gen cdss_bin`i' = (cdss_score > `lo' & cdss_score <= `hi' & cdss_score != 0 & cdss_score != .999)
}



* Final pre roll up step: Remove variables no longer needed after new var creation *
drop case_grp_cd
drop anniv_chrg_dt anniv_lend_dt
drop tsr_score cdss_score
drop credit_segment
drop open_dt close_dt
drop chrg_date lend_date start_date





*** Step 5: Roll Up data based on EN case open action code ***
****************************************************
* STEP. Keep only EN rows (case open info per triplicate)
****************************************************
keep if act_type_cd == "EN"

* If multiple EN per triplicate, keep the first only
bys triplicate (act_dt_num): keep if _n == 1

****************************************************
* STEP. Filter on age_day_ct at case open
*   - Keep only if between 27 and 33 (inclusive)
****************************************************
keep if inrange(age_day_ct, 27, 33)

****************************************************
* Final dataset: 1 row per triplicate
* with open info, duration, past_30, past_60, cleaned fico
****************************************************

* Drop act_type variable now since EN is implied *
drop act_type_cd




* Save the cleaned .dta file to my Joseph folder in box *
* --------- paths (same base as before) ---------
local HOME : env HOME
local box  "`HOME'/Library/CloudStorage/Box-Box"

* Target folder inside Amex_2025_Class
local outdir "`box'/Amex_2025_Class/Joseph"

* Create the folder if it doesn't exist (quietly)
cap mkdir "`box'/Amex_2025_Class"
cap mkdir "`outdir'"

* --------- save cleaned rolled dataset ---------
compress
save "`outdir'/Cleaned_Rolled_Joseph.dta", replace


