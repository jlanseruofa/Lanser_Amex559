*** Joseph's Project 1 Stata Code ***
*** For 2025 AREC 559 Amex Class ***
*** In this code, I will work through the 1st class project questions in order ***



clear all
*** Step 1: Load in .dta 1 percent data sample to be used ***

* Base Box path
local HOME : env HOME
local box  "`HOME'/Library/CloudStorage/Box-Box"

* Point to your Joseph folder instead of Random Samples
local proj "Amex_2025_Class/Joseph"

* Load the saved .dta
use "`box'/`proj'/amex_1_pct.dta", clear

describe
count


*** Code for missing values: -9999 means missing
mvdecode _all, mv(-9999)




*** 1a. Number of Unique Triplicates ***
* If triplicate is a string, normalize a bit (optional but helps)
capture confirm string variable triplicate
if !_rc {
    replace triplicate = lower(strtrim(triplicate))
}

* Count unique non-missing values (robust, no limits)
bysort triplicate: gen byte __tag = (_n==1) if !missing(triplicate)
quietly count if __tag
di as result "Unique triplicate values (non-missing): " r(N)
drop __tag




*** 1b. Earliest and latest case open and case closed Dates ***
*** EN means case opened, RI means case closed. Look at that using the act_dt date variable ***
* Convert act_dt from string to Stata daily date
gen double act_date = date(act_dt, "YMD")
format act_date %td

* Earliest case opened (EN)
summarize act_date if act_type_cd=="EN", meanonly
di as result "Earliest case OPEN date: " %td r(min)
di as result "Latest  case OPEN date: " %td r(max)

* Earliest case closed (RI)
summarize act_date if act_type_cd=="RI", meanonly
di as result "Earliest case CLOSED date: " %td r(min)
di as result "Latest  case CLOSED date: " %td r(max)




*** 1c. Time elapsed per case ***
*** Coded by looking at each unique triplicate, and searching for the earliest and latest cooresponding date ***
*** That time elapsed calue is then put into a new column in order to make a historgram ***

* --- 0) (Optional) convert -9999 to missing first ---
* If your file used -9999 as a numeric sentinel:
capture noisily mvdecode _all, mv(-9999)

* --- 1) Make a proper datetime from act_dt + act_tm ---
* Convert act_dt to Stata daily date if needed
capture confirm numeric variable act_dt
if _rc {                             // act_dt is string "YYYY-MM-DD"
    gen double act_dt_td = daily(act_dt, "YMD")
    format act_dt_td %td
}
else {                               // act_dt already numeric daily date
    gen double act_dt_td = act_dt
    format act_dt_td %td
}

* Build a string date for concatenation when act_dt was numeric
gen str10 act_dt_str = string(act_dt_td, "%tdCCYY-NN-DD")

* Normalize act_tm to HH:MM:SS (covering HH:MM:SS, HH:MM, HHMMSS)
capture confirm numeric variable act_tm
if _rc {
    * act_tm is a string
    gen str8 tm_norm = trim(act_tm)
    replace tm_norm = tm_norm + ":00" if regexm(tm_norm, "^[0-2]?[0-9]:[0-5][0-9]$")         // HH:MM -> HH:MM:00
    replace tm_norm = substr(tm_norm,1,2)+":"+substr(tm_norm,3,2)+":"+substr(tm_norm,5,2) ///
        if regexm(tm_norm, "^[0-2][0-9][0-5][0-9][0-5][0-9]$")                                // HHMMSS -> HH:MM:SS

    * Combine date + time (prefer original date string if it exists, else act_dt_str)
    capture confirm string variable act_dt
    if _rc {
        gen str25 dt_full = act_dt_str + " " + tm_norm
    }
    else {
        gen str25 dt_full = act_dt + " " + tm_norm
    }

    gen double act_dt_tc = clock(dt_full, "YMDhms")
    format act_dt_tc %tc
}
else {
    * act_tm is numeric (assume seconds since midnight; edit if it's millis)
    * total ms = daily_date(ms) + seconds*1000
    gen double act_dt_tc = act_dt_td*24*60*60*1000 + act_tm*1000
    format act_dt_tc %tc
}

* --- 2) Earliest and latest per triplicate; elapsed in hours/minutes/days ---
bysort triplicate: egen double start_tc = min(act_dt_tc)
bysort triplicate: egen double end_tc   = max(act_dt_tc)

gen double elapsed_ms    = end_tc - start_tc
gen double elapsed_hours = elapsed_ms/3600000
gen double elapsed_min   = elapsed_ms/60000
gen double elapsed_days  = elapsed_ms/(24*3600000)

format elapsed_hours %9.2f
format elapsed_min   %9.0f
format elapsed_days  %9.3f
label var elapsed_hours "Hours between earliest and latest record per triplicate"
label var elapsed_min   "Minutes between earliest and latest record per triplicate"
label var elapsed_days  "Days between earliest and latest record per triplicate"

* --- 3) (Optional) "Open → Close" only: EN start to RI end per triplicate ---
gen double dt_EN_tc = act_dt_tc if act_type_cd == "EN"
gen double dt_RI_tc = act_dt_tc if act_type_cd == "RI"

bysort triplicate: egen double start_EN_tc = min(dt_EN_tc)
bysort triplicate: egen double end_RI_tc   = max(dt_RI_tc)

gen double elapsed_EN_RI_hours = (end_RI_tc - start_EN_tc)/3600000
gen double elapsed_EN_RI_days  = (end_RI_tc - start_EN_tc)/(24*3600000)
format elapsed_EN_RI_hours %9.2f
format elapsed_EN_RI_days  %9.3f
label var elapsed_EN_RI_hours "Hours from first EN to last RI per triplicate"
label var elapsed_EN_RI_days  "Days from first EN to last RI per triplicate"

* --- 4) (Optional) one-row-per-case summary you can export/list ---
preserve
keep triplicate start_tc end_tc elapsed_hours elapsed_days start_EN_tc end_RI_tc ///
     elapsed_EN_RI_hours elapsed_EN_RI_days
bys triplicate: keep if _n == 1
order triplicate start_tc end_tc elapsed_hours elapsed_days start_EN_tc end_RI_tc ///
      elapsed_EN_RI_hours elapsed_EN_RI_days
sort triplicate
list in 1/10, noobs
restore


* Graphs *
histogram elapsed_hours, percent

histogram elapsed_hours if inrange(elapsed_hours,0,36), percent



* Count cases less than 1 day in total length *
* Number of cases lasting < 24 hours
count if elapsed_hours < 24


* Count cases that never closed *
* Collapse to triplicate level and count RI
bys triplicate: egen has_RI = max(act_type_cd == "RI")

* Count triplicates with no RI
count if has_RI == 0






*** 1d. ***
* Count cases that go 30 DPB and 60 DPB *
* Flag thresholds per case
bys triplicate: egen byte ever30 = max(age_day_ct >= 30)
bys triplicate: egen byte ever60 = max(age_day_ct >= 60)

* Tag one row per case
egen byte case_tag = tag(triplicate)

* Counts
count if case_tag & ever30
display as text "Number of cases beyond 30 DPB: " as result r(N)

count if case_tag & ever60
display as text "Number of cases beyond 60 DPB: " as result r(N)



* Descriptive statistics of ballances at 30 and 60 DPB Thresholds *

* 1. Create total balance at each record
egen double balance = rowtotal(tot_due_chrg_am tot_due_lend_am)

* 2. Sort by case and time so we can find first crossing
sort triplicate act_dt_tc   // act_dt_tc = datetime variable you built earlier

* 3. Mark first time each case crosses 30 DPB
by triplicate: gen hit30 = (age_day_ct >= 30) & ( _n==1 | age_day_ct[_n-1] < 30 )

* 4. Mark first time each case crosses 60 DPB
by triplicate: gen hit60 = (age_day_ct >= 60) & ( _n==1 | age_day_ct[_n-1] < 60 )

* 5. Capture balances at those first crossings
by triplicate: gen bal_at_30_tmp = balance if hit30
by triplicate: gen bal_at_60_tmp = balance if hit60
by triplicate: egen bal_at_30 = max(bal_at_30_tmp)
by triplicate: egen bal_at_60 = max(bal_at_60_tmp)

* 6. Descriptive stats (case-level)
preserve
bys triplicate: keep if _n==1

summarize bal_at_30 if !missing(bal_at_30), detail
summarize bal_at_60 if !missing(bal_at_60), detail
restore


* get medians
quietly summarize bal_at_30 if !missing(bal_at_30), detail
local med30 = r(p50)

quietly summarize bal_at_60 if !missing(bal_at_60), detail
local med60 = r(p50)


* one row per case
bys triplicate: keep if _n==1

twoway ///
  (histogram bal_at_30 if inrange(bal_at_30, 0, 3000), percent color(blue%40) ///
      start(0) width(100)) ///
  (histogram bal_at_60 if inrange(bal_at_60, 0, 3000), percent color(red%40)  ///
      start(0) width(100)), ///
  legend(order(1 "30 DPB" 2 "60 DPB")) ///
  title("Balance Distribution at 30 vs 60 DPB (0–3,000)") ///
  xtitle("Total Balance at Threshold") ytitle("Percent of Cases") ///
  xscale(range(0 3000)) xlabel(0(500)3000)



  
  
*** 1e. Small business vs Consumer ***
*** Lend vs Charge ***

preserve
    tempvar total_balance
    egen double `total_balance' = rowtotal(tot_due_chrg_am tot_due_lend_am)

    gen str14 __segment = cond(case_grp_cd=="CUST","Consumer", ///
                          cond(case_grp_cd=="COMP","Small Business","Other"))

    gen str6 __ptype = cond(tot_due_chrg_am>0  & tot_due_lend_am==0,"Charge", ///
                       cond(tot_due_chrg_am==0  & tot_due_lend_am>0,"Lend",   ///
                       cond(tot_due_chrg_am>0  & tot_due_lend_am>0,"Both","None")))

    table __ptype __segment, ///
        statistic(sum `total_balance') ///
        nformat(%12.0gc)

restore


* Summary stats for each category *

preserve
    // 1) Total balance per row (temporary)
    tempvar total_balance
    egen double `total_balance' = rowtotal(tot_due_chrg_am tot_due_lend_am)

    // 2) Build a 6-category grouping (temporary)
    gen str24 __group = ""
    // Small Business (COMP)
    replace __group = "SB: Charge"         if case_grp_cd=="COMP" & tot_due_chrg_am>0 & tot_due_lend_am==0
    replace __group = "SB: Lend"           if case_grp_cd=="COMP" & tot_due_chrg_am==0 & tot_due_lend_am>0
    replace __group = "SB: Charge+Lend"    if case_grp_cd=="COMP" & tot_due_chrg_am>0  & tot_due_lend_am>0
    // Consumer (CUST)
    replace __group = "Consumer: Charge"      if case_grp_cd=="CUST" & tot_due_chrg_am>0 & tot_due_lend_am==0
    replace __group = "Consumer: Lend"        if case_grp_cd=="CUST" & tot_due_chrg_am==0 & tot_due_lend_am>0
    replace __group = "Consumer: Charge+Lend" if case_grp_cd=="CUST" & tot_due_chrg_am>0  & tot_due_lend_am>0

    // Keep only the six requested categories
    keep if inlist(__group, "SB: Charge","SB: Lend","SB: Charge+Lend", ///
                           "Consumer: Charge","Consumer: Lend","Consumer: Charge+Lend")

    // 3) Descriptive stats per category
    // (mean, median, p25, p50, p75, min, max, variance)
    tabstat `total_balance', by(__group) ///
        stats(mean median p25 p50 p75 min max variance) ///
        columns(statistics) format(%12.2fc)

restore





* Rollover by category *

preserve
    // --- Case-level classification ---
    gen byte __ch = tot_due_chrg_am > 0
    gen byte __le = tot_due_lend_am > 0

    bys triplicate: egen byte __any_ch = max(__ch)
    bys triplicate: egen byte __any_le = max(__le)

    gen str12 __ptype = cond(__any_ch & __any_le, "Charge+Lend", ///
                       cond(__any_ch, "Charge", ///
                       cond(__any_le, "Lend", "None")))

    gen str14 __segment = cond(case_grp_cd=="CUST","Consumer", ///
                          cond(case_grp_cd=="COMP","Small Business","Other"))

    bys triplicate: egen byte __ever30 = max(age_day_ct >= 30)
    bys triplicate: egen byte __ever60 = max(age_day_ct >= 60)

    egen byte __tag = tag(triplicate)
    keep if __tag & __segment!="Other" & __ptype!="None"

    // --- Counts of cases with DPB ≥ 30 ---
    display as text "Counts of cases with DPB ≥ 30"
    table __ptype __segment, ///
        statistic(sum __ever30) ///
        nformat(%12.0gc)

    // --- Counts of cases with DPB ≥ 60 ---
    display as text "Counts of cases with DPB ≥ 60"
    table __ptype __segment, ///
        statistic(sum __ever60) ///
        nformat(%12.0gc)
restore
