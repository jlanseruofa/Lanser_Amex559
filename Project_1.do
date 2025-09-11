*** Joseph's Project 1 Stata Code (preserve/restore safe) ***
*** For 2025 AREC 559 Amex Class ***
*** Each section preserves and restores the originally loaded data ***




clear all


*** Step 1: Load in .dta 1 percent data sample to be used ***
local HOME : env HOME
local box  "`HOME'/Library/CloudStorage/Box-Box"
local proj "Amex_2025_Class/Joseph"

use "`box'/`proj'/amex_1_pct.dta", clear
describe
count




********************************************************************************
*** NOTE: We do NOT permanently mvdecode or mutate variables in this script.  ***
*** Where needed, we translate -9999 to missing inside preserve blocks only.  ***
********************************************************************************





*** 1a. Number of Unique Triplicates (non-missing) ****************************
preserve
    tempvar trip_norm tag
    capture confirm string variable triplicate
    if !_rc {
        gen strL `trip_norm' = lower(strtrim(triplicate))
    }
    else {
        gen `trip_norm' = triplicate
    }
    bysort `trip_norm': gen byte `tag' = (_n==1) if !missing(`trip_norm')
    quietly count if `tag'
    di as result "Unique triplicate values (non-missing): " r(N)
restore





*** 1b. Earliest and latest case OPEN/CLOSED dates ****************************
*** EN = case opened, RI = case closed; act_dt is assumed "YYYY-MM-DD"
preserve
    tempvar act_date
    gen double `act_date' = daily(act_dt, "YMD")
    format `act_date' %td

    quietly summarize `act_date' if act_type_cd=="EN", meanonly
    di as text   "Earliest case OPEN date: "  ///
       as result %td r(min)
    di as text   "Latest  case OPEN date: "  ///
       as result %td r(max)

    quietly summarize `act_date' if act_type_cd=="RI", meanonly
    di as text   "Earliest case CLOSED date: " ///
       as result %td r(min)
    di as text   "Latest  case CLOSED date: "  ///
       as result %td r(max)
restore





*** 1c. Time elapsed per case (earliest→latest; plus EN→RI) *******************
preserve
    * Translate -9999 sentinels to missing only for this analysis
    capture noisily mvdecode _all, mv(-9999)

    * Build a unified datetime (act_dt_tc) from act_dt + act_tm
    tempvar dt_td dt_str tm_norm act_tc
    capture confirm numeric variable act_dt
    if _rc {
        gen double `dt_td' = daily(act_dt, "YMD")
        format `dt_td' %td
    }
    else {
        gen double `dt_td' = act_dt
        format `dt_td' %td
    }
    gen str10 `dt_str' = string(`dt_td', "%tdCCYY-NN-DD")

    capture confirm numeric variable act_tm
    if _rc {
        gen str8 `tm_norm' = trim(act_tm)
        replace `tm_norm' = `tm_norm' + ":00" if regexm(`tm_norm', "^[0-2]?[0-9]:[0-5][0-9]$")
        replace `tm_norm' = substr(`tm_norm',1,2)+":"+substr(`tm_norm',3,2)+":"+substr(`tm_norm',5,2) ///
            if regexm(`tm_norm', "^[0-2][0-9][0-5][0-9][0-5][0-9]$")
        gen double `act_tc' = clock(`dt_str' + " " + `tm_norm', "YMDhms")
    }
    else {
        gen double `act_tc' = `dt_td'*24*60*60*1000 + cond(act_tm < 86400, act_tm*1000, act_tm)
    }
    format `act_tc' %tc

    * Earliest/latest per triplicate and elapsed durations
    tempvar start_tc end_tc el_ms el_hr el_min el_day
    bysort triplicate: egen double `start_tc' = min(`act_tc')
    bysort triplicate: egen double `end_tc'   = max(`act_tc')

    gen double `el_ms'  = `end_tc' - `start_tc'
    gen double `el_hr'  = `el_ms'/3600000
    gen double `el_min' = `el_ms'/60000
    gen double `el_day' = `el_ms'/(24*3600000)
    format `el_hr' %9.2f
    format `el_min' %9.0f
    format `el_day' %9.3f

    * EN→RI elapsed (optional)
    tempvar EN_tc RI_tc EN_start RI_end enri_hr enri_day
    gen double `EN_tc' = `act_tc' if act_type_cd=="EN"
    gen double `RI_tc' = `act_tc' if act_type_cd=="RI"
    bysort triplicate: egen double `EN_start' = min(`EN_tc')
    bysort triplicate: egen double `RI_end'   = max(`RI_tc')
    gen double `enri_hr'  = (`RI_end' - `EN_start')/3600000
    gen double `enri_day' = (`RI_end' - `EN_start')/(24*3600000)
    format `enri_hr' %9.2f
    format `enri_day' %9.3f

    * Examples / quick outputs
    quietly count if `el_hr' < 24
    di as text "Cases lasting < 24 hours: " as result r(N)

    tempvar has_RI
    bysort triplicate: egen byte `has_RI' = max(act_type_cd=="RI")
    quietly count if `has_RI'==0
    di as text "Cases that never closed (no RI observed): " as result r(N)

    * Histograms (view-only; nothing persists)
    histogram `el_hr', percent title("Elapsed Hours per Case")
    histogram `el_hr' if inrange(`el_hr',0,36), percent ///
        title("Elapsed Hours per Case (0–36)")
restore






*** 1d. DPB thresholds (≥30, ≥60) and balances at first crossing **************
preserve
    * Case-level ever30 / ever60
    tempvar ever30 ever60 tag
    bysort triplicate: egen byte `ever30' = max(age_day_ct >= 30)
    bysort triplicate: egen byte `ever60' = max(age_day_ct >= 60)
    egen byte `tag' = tag(triplicate)

    quietly count if `tag' & `ever30'
    di as text "Number of cases beyond 30 DPB: " as result r(N)
    quietly count if `tag' & `ever60'
    di as text "Number of cases beyond 60 DPB: " as result r(N)

    * Total balance per record
    tempvar balance
    egen double `balance' = rowtotal(tot_due_chrg_am tot_due_lend_am)

    * Build datetime once more (as temp)
    tempvar dt_td dt_str tm_norm act_tc
    capture confirm numeric variable act_dt
    if _rc {
        gen double `dt_td' = daily(act_dt, "YMD")
        format `dt_td' %td
    }
    else {
        gen double `dt_td' = act_dt
        format `dt_td' %td
    }
    gen str10 `dt_str' = string(`dt_td', "%tdCCYY-NN-DD")

    capture confirm numeric variable act_tm
    if _rc {
        gen str8 `tm_norm' = trim(act_tm)
        replace `tm_norm' = `tm_norm' + ":00" if regexm(`tm_norm', "^[0-2]?[0-9]:[0-5][0-9]$")
        replace `tm_norm' = substr(`tm_norm',1,2)+":"+substr(`tm_norm',3,2)+":"+substr(`tm_norm',5,2) ///
            if regexm(`tm_norm', "^[0-2][0-9][0-5][0-9][0-5][0-9]$")
        gen double `act_tc' = clock(`dt_str' + " " + `tm_norm', "YMDhms")
    }
    else {
        gen double `act_tc' = `dt_td'*24*60*60*1000 + cond(act_tm < 86400, act_tm*1000, act_tm)
    }
    format `act_tc' %tc
    sort triplicate `act_tc'

    * First time crossing 30 / 60
    tempvar hit30 hit60 b30tmp b60tmp bal_at_30 bal_at_60
    by triplicate: gen `hit30' = (age_day_ct>=30) & ( _n==1 | age_day_ct[_n-1] < 30 )
    by triplicate: gen `hit60' = (age_day_ct>=60) & ( _n==1 | age_day_ct[_n-1] < 60 )

    by triplicate: gen double `b30tmp' = `balance' if `hit30'
    by triplicate: gen double `b60tmp' = `balance' if `hit60'
    bysort triplicate: egen double `bal_at_30' = max(`b30tmp')
    bysort triplicate: egen double `bal_at_60' = max(`b60tmp')

    * Case-level table (non-zero only)
    quietly summarize `bal_at_30' if `bal_at_30'>0, detail
    di as text "bal_at_30 (non-zero) - N=" %9.0f r(N) ///
       "  mean=" %9.2f r(mean) "  p50=" %9.2f r(p50)

    quietly summarize `bal_at_60' if `bal_at_60'>0, detail
    di as text "bal_at_60 (non-zero) - N=" %9.0f r(N) ///
       "  mean=" %9.2f r(mean) "  p50=" %9.2f r(p50)

    * Quick hist overlay (view-only)
    twoway ///
      (histogram `bal_at_30' if inrange(`bal_at_30', 0, 3000) & `bal_at_30'>0, ///
           percent start(0) width(100)) ///
      (histogram `bal_at_60' if inrange(`bal_at_60', 0, 3000) & `bal_at_60'>0, ///
           percent start(0) width(100)), ///
      legend(order(1 "30 DPB" 2 "60 DPB")) ///
      title("Balance Distribution at 30 vs 60 DPB (0–3,000)") ///
      xtitle("Total Balance at Threshold") ytitle("Percent of Cases") ///
      xscale(range(0 3000)) xlabel(0(500)3000)
restore






*** 1e. Small business vs Consumer; Lend vs Charge; case-level stats **********
*** Panel A: Summary stats for bal_at_30 / bal_at_60 by product type *********
preserve
    * Recompute case-level balances at first crossing (self-contained)
    tempvar balance dt_td dt_str tm_norm act_tc hit30 hit60 b30tmp b60tmp bal30 bal60
    egen double `balance' = rowtotal(tot_due_chrg_am tot_due_lend_am)

    capture confirm numeric variable act_dt
    if _rc {
        gen double `dt_td' = daily(act_dt, "YMD")
        format `dt_td' %td
    }
    else {
        gen double `dt_td' = act_dt
        format `dt_td' %td
    }
    gen str10 `dt_str' = string(`dt_td', "%tdCCYY-NN-DD")

    capture confirm numeric variable act_tm
    if _rc {
        gen str8 `tm_norm' = trim(act_tm)
        replace `tm_norm' = `tm_norm' + ":00" if regexm(`tm_norm', "^[0-2]?[0-9]:[0-5][0-9]$")
        replace `tm_norm' = substr(`tm_norm',1,2)+":"+substr(`tm_norm',3,2)+":"+substr(`tm_norm',5,2) ///
            if regexm(`tm_norm', "^[0-2][0-9][0-5][0-9][0-5][0-9]$")
        gen double `act_tc' = clock(`dt_str' + " " + `tm_norm', "YMDhms")
    }
    else {
        gen double `act_tc' = `dt_td'*24*60*60*1000 + cond(act_tm < 86400, act_tm*1000, act_tm)
    }
    format `act_tc' %tc
    sort triplicate `act_tc'

    by triplicate: gen `hit30' = (age_day_ct>=30) & ( _n==1 | age_day_ct[_n-1] < 30 )
    by triplicate: gen `hit60' = (age_day_ct>=60) & ( _n==1 | age_day_ct[_n-1] < 60 )

    by triplicate: gen double `b30tmp' = `balance' if `hit30'
    by triplicate: gen double `b60tmp' = `balance' if `hit60'
    bysort triplicate: egen double `bal30' = max(`b30tmp')
    bysort triplicate: egen double `bal60' = max(`b60tmp')

    * Case-level product type across entire case
    tempvar ch_row le_row any_ch any_le ptype bal30_nz bal60_nz case_tag
    gen byte `ch_row' = tot_due_chrg_am  > 0
    gen byte `le_row' = tot_due_lend_am > 0
    bysort triplicate: egen byte `any_ch' = max(`ch_row')
    bysort triplicate: egen byte `any_le' = max(`le_row')

    gen str6 `ptype' = cond(`any_ch' & `any_le', "Both", ///
                       cond(`any_ch', "Charge", cond(`any_le', "Lend", "None")))
    keep if inlist(`ptype', "Charge","Lend","Both")

    gen double `bal30_nz' = cond(`bal30'>0, `bal30', .)
    gen double `bal60_nz' = cond(`bal60'>0, `bal60', .)

    egen byte `case_tag' = tag(triplicate)
    keep if `case_tag'

    tabstat `bal30_nz' `bal60_nz', by(`ptype') ///
        stats(n mean sd p25 p50 p75 min max) columns(statistics) format(%12.2fc)
restore


*** Panel B: "Rollover" counts by segment × product type (DPB ≥ 30/60) *******
preserve
    tempvar ch le any_ch any_le ptype segment ever30 ever60 tag
    gen byte `ch' = tot_due_chrg_am  > 0
    gen byte `le' = tot_due_lend_am > 0
    bysort triplicate: egen byte `any_ch' = max(`ch')
    bysort triplicate: egen byte `any_le' = max(`le')

    gen str12 `ptype' = cond(`any_ch' & `any_le', "Charge+Lend", ///
                        cond(`any_ch', "Charge", cond(`any_le', "Lend", "None")))

    gen str14 `segment' = cond(case_grp_cd=="CUST","Consumer", ///
                          cond(case_grp_cd=="COMP","Small Business","Other"))

    bysort triplicate: egen byte `ever30' = max(age_day_ct >= 30)
    bysort triplicate: egen byte `ever60' = max(age_day_ct >= 60)

    egen byte `tag' = tag(triplicate)
    keep if `tag' & `segment'!="Other" & `ptype'!="None"

    di as text "Counts of cases with DPB ≥ 30"
    table `ptype' `segment', statistic(sum `ever30') nformat(%12.0gc)

    di as text "Counts of cases with DPB ≥ 60"
    table `ptype' `segment', statistic(sum `ever60') nformat(%12.0gc)
restore
