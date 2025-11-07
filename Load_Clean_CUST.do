* Load in SMALL BUSINESS Dataset *
clear all
* Set your Box path
local HOME : env HOME
local box  "`HOME'/Library/CloudStorage/Box-Box"
local outdir "`box'/Amex_2025_Class/Joseph"

* Import the COMP dataset
import delimited "`outdir'/amex_CUST_combined_10_pct.csv", clear varnames(1)





* Ensure global chronological order: triplicate then DESC act_seq_no
gsort triplicate -act_seq_no

* Helper for bysort: ascending on negative = descending on original
tempvar seqdesc
gen double `seqdesc' = -act_seq_no



*** Step 2: Delete all uneeded variables (they will still be saved on the 1 percent data file) ***

* Drop unwanted vars
drop pseudo_key
drop case_seq_no
drop case_setup_type
drop ctc_plce_cd
drop ctc_prty_cd
drop rule_no
drop portfo_sta_lvl_cd
drop act_info_cd1 act_info_cd2 act_info_cd3
drop sprt_no sprt_keep_day_ct sprt_duns_am
drop cust_chrg_lend_expsr_lvl_am cust_chrg_card_loc_expsr_lvl_am
drop payment_amount
drop lift_dt
drop letter_code
drop strategy1_cd strategy2_cd strategy3_cd strategy4_cd
drop product_types pseudo_key_file1 pseudo_key_new pseudo_key_file2 pseudo_key_file3 pseudo_key_file4



* Case Open Month Dummies *
*--- Ensure act_dt is a proper Stata date variable ---
*gen double act_date = date(act_dt, "YMD")
*format act_date %td

*--- Extract month number (1 = January, 12 = December) ---
*gen byte month_num = month(act_date)

*--- Loop through all 12 months and generate dummies ---
*forvalues m = 1/12 {
 *   local mon : word `m' of jan feb mar apr may jun jul aug sep oct nov dec
  *  gen byte case_start_`mon' = (act_type_cd == "EN" & month_num == `m')
*}

*--- (Optional) Verify results ---
*tab month_num if act_type_cd == "EN"
*list act_type_cd act_dt case_start_* if act_type_cd == "EN" in 1/10
*drop case_start_sep
*drop case_start_oct
*drop case_start_nov
*drop case_start_dec



*** Step 3: Create new variables needed for analysis

* CUST/COMP Binary Creation
* Generate customer binary: 1 if CUST, 0 if COMP
gen cust_bi = .
replace cust_bi = 1 if case_grp_cd == "CUST"
replace cust_bi = 0 if case_grp_cd == "COMP"

* Generate small business binary: 1 if COMP, 0 if CUST
* gen smbus_bi = .
* replace smbus_bi = 1 if case_grp_cd == "COMP"
* replace smbus_bi = 0 if case_grp_cd == "CUST"

* Total Balance Due Variable, Binary Charge/Lend Dummies *
gen tot_bal_due = tot_due_chrg_am + tot_due_lend_am

* Charge dummy: 1 if nonzero, 0 if zero
* gen charge_dum = (tot_due_chrg_am != 0) if !missing(tot_due_chrg_am)

* Lend dummy: 1 if nonzero, 0 if zero
* gen lend_dum = (tot_due_lend_am != 0) if !missing(tot_due_lend_am)

* Total Balance Due / Total Case Exposure Variable *
gen tot_bal_over_exp = tot_bal_due / total_case_exposure

* Code FICO scores to missing if the customer is COMP, since it is not relevant in that case *
* replace fico = . if case_grp_cd == "COMP"



*** Step 4: Continue to filter data and create needed vars ***
****************************************************
* STEP. Keep dataset ordered by triplicate and DESC act_seq_no
****************************************************
gsort triplicate -act_seq_no

****************************************************
* STEP. Drop triplicates where EN is not the first act (in DESC seq order)
****************************************************
bys triplicate (`seqdesc'): gen first_act = act_type_cd[1]
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

* Earliest EN date (case open) and earliest RI/SI closing date
by triplicate: egen open_dt  = min(cond(act_type_cd=="EN", act_dt_num, .))
by triplicate: egen close_dt = min(cond(inlist(act_type_cd,"RI","SI"), act_dt_num, .))

* Duration in days
gen case_duration = close_dt - open_dt

****************************************************
* STEP. Compute max age_day_ct per triplicate, trim out <31,
*       and create past 30/60 binary indicators
****************************************************
preserve
collapse (max) max_age_day_ct=age_day_ct, by(triplicate)
tempfile maxages
save `maxages'
restore

merge m:1 triplicate using `maxages', nogen

* Trim out triplicates that never reached 31+
drop if max_age_day_ct < 31

* Binary indicators
* gen past_30_bi = (max_age_day_ct > 30)
gen past_60_bi = (max_age_day_ct >= 60)


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
* gen tsr_0    = (tsr_score == 0)
* gen tsr_999  = (tsr_score == .999)

* CDSS score exact bins
* gen cdss_0   = (cdss_score == 0)
* gen cdss_999 = (cdss_score == .999)

* TSR bins (excluding 0 and .999)
*forvalues i = 1/9 {
 *   local lo = (`i'-1)/10
  *  local hi = `i'/10
   * gen tsr_bin`i' = (tsr_score > `lo' & tsr_score <= `hi' & tsr_score != 0 & tsr_score != 1)
* }

* CDSS bins (excluding 0 and .999)
* forvalues i = 1/9 {
  *  local lo = (`i'-1)/10
   *  local hi = `i'/10
    * gen cdss_bin`i' = (cdss_score > `lo' & cdss_score <= `hi' & cdss_score != 0 & cdss_score != 1)
*}



*** Charge and Lend Dummies ***
* Sort so each triplicate is grouped
sort triplicate

* Step 1: Flag if there is any nonmissing charge or lend date for each triplicate
bys triplicate: egen has_charge = max(!missing(anniv_chrg_dt))
bys triplicate: egen has_lend   = max(!missing(anniv_lend_dt))

* Step 2: Create the two dummies
gen charge_lend_bi = (has_charge==1 & has_lend==1)
gen charge_bi      = (has_charge==1 & has_lend==0)

* Step 3: If charge_lend_bi == 1, force charge_bi to 0
replace charge_bi = 0 if charge_lend_bi == 1

* (Optional) Drop helper vars
drop has_charge has_lend







* Final pre roll up step: Remove variables no longer needed after new var creation *
drop case_grp_cd
drop anniv_chrg_dt anniv_lend_dt
drop credit_segment
drop open_dt close_dt
drop chrg_date lend_date



*** Step 5: Roll Up data based on EN case open action code ***
****************************************************
* Keep order before filtering
gsort triplicate -act_seq_no

* STEP. Keep only EN rows (case open info per triplicate)
keep if act_type_cd == "EN"

* If multiple EN per triplicate, keep the first only (DESC seq means highest seq kept)
bys triplicate (`seqdesc'): keep if _n == 1

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
drop act_seq_no


* Code Balance and Eposure variables to be /1000 *
replace tot_due_chrg_am       = tot_due_chrg_am       / 1000
replace tot_due_lend_am       = tot_due_lend_am       / 1000
replace tot_expr_chrg         = tot_expr_chrg         / 1000
replace tot_expr_lend         = tot_expr_lend         / 1000
replace total_case_exposure   = total_case_exposure   / 1000
replace tot_past_due_chrg_am  = tot_past_due_chrg_am  / 1000
replace tot_past_due_lend_am  = tot_past_due_lend_am  / 1000
replace tot_bal_due  = tot_past_due_lend_am  / 1000


label variable tot_due_chrg_am "Scaled /1000"
label variable tot_due_lend_am "Scaled /1000"
label variable tot_expr_chrg "Scaled /1000"
label variable tot_expr_lend "Scaled /1000"
label variable total_case_exposure "Scaled /1000"
label variable tot_past_due_chrg_am "Scaled /1000"
label variable tot_past_due_lend_am "Scaled /1000"
label variable tot_bal_due "Scaled /1000"

* Final Var Drop *
drop act_tm
* drop smbus_bi
* drop lend_dum
drop act_dt_num
drop max_age_day_ct
drop start_date



*** Dummy for 2+ Num of Products ***
* Create a dummy for multiple products
*gen multiple_products = .
*replace multiple_products = 1 if num_products >= 2
*replace multiple_products = 0 if num_products == 1
*drop num_products




*** FICO dummy for categories ***
*--- Create FICO category dummies ---
* gen fico_verypoor = (fico >= 300 & fico <= 579)
*gen fico_poor     = (fico >= 580 & fico <= 669)
* gen fico_good     = (fico >= 670 & fico <= 739)
* gen fico_verygood = (fico >= 740 & fico <= 799)
* gen fico_excellent= (fico >= 800 & fico <= 850)


* tenure squared variable *
gen tenure_squared = tenure^2





****************************************************
* STEP. Drop triplicates with missing FICO after roll up
****************************************************
drop if missing(fico)





* Drop vars not wanted for Machine Learning? *
drop triplicate
*drop act_dt
*drop age_day_ct
*drop tot_past_due_chrg_am
*drop tot_past_due_lend_am
*drop tot_due_chrg_am
*drop tot_due_lend_am
*drop tot_expr_chrg
*drop tot_expr_lend
*drop total_case_exposure
*drop probc_score
*drop act_date
*drop month_num
drop case_duration
drop tenure_squared


****************************************************
* Change names/definitions for congruency *
****************************************************

rename tsr_score tsr
rename cdss_score cdss
rename tot_bal_due bal_due
label variable tsr "Continuous TSR Score"
label variable fico "Continuous FICO Score"
label variable cdss "Continuous CDSS Score"
label variable bal_due "(Total Past Due Charge + Total Past Due Lend)/1000     *scaled by 1000*"
rename tot_bal_over_exp bal_over_expr
label variable bal_over_expr "Total Balance Due / Total Case Exposure"
rename past_60_bi roll_forward
label variable roll_forward "Dummy for Case Roll Forward"
label variable tenure "Min Anniv Date *Years*"
rename charge_bi d_chrg
label variable d_chrg "Dummy for Charge Customers"
rename charge_lend_bi d_chrg_lend
label variable d_chrg_lend "Dummy for Charge&Lend Customers (Both)"
rename cust_bi d_consumer
label variable d_consumer "Dummy for Consumer Customers"
label variable num_products "Count variable (Max # Products Value in full case)"
label variable cs_other "Dummy for Credit Segment: Other"
label variable cs_low_balance "Dummy for Credit Segment: Low Balance"
label variable cs_currents "Dummy for Credit Segment: Currents"
label variable cs_seg_a "Dummy for Credit Segment: Seg A"
label variable cs_high_balance "Dummy for Credit Segment: High Balance"
label variable cs_cfs_team "Dummy for Credit Segment: CFS Team"
label variable cs_arct_team "Dummy for Credit Segment: ARCT Team"
* drop probc_score
drop act_dt age_day_ct
drop tot_due_chrg_am tot_due_lend_am tot_expr_chrg tot_expr_lend total_case_exposure tot_past_due_chrg_am tot_past_due_lend_am 
drop past_due_roll



rename cons_train d_train
label variable d_train "Dummy for MLA: Train = 1, Test = 0"
drop if d_consumer != 1
drop d_consumer
replace d_train = 0 if d_train == 2
drop if missing(d_train)









// create individual dummies
foreach v in 250 CPD MCS PIF {
    gen d_port_`v' = (portfo_w_lvl_cd == "`v'")
}

// create the "other" dummy
gen d_port_other = 1
foreach v in 250 CPD MCS PIF {
    replace d_port_other = 0 if portfo_w_lvl_cd == "`v'"
}

drop portfo_w_lvl_cd



foreach var in tsr cdss {
    gen d_`var'_zero  = (`var' == 0)
    gen d_`var'_nines = (`var' == .999)
}


foreach var in tsr cdss {
    gen `var'_sq = `var'^2
}




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
save "`outdir'/FINAL_CONS.dta", replace
