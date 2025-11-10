*** Joseph Lanser | AREC 559
*** Descriptive Statistics



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
drop __000000
drop d_port_200 d_port_250 d_port_600 d_port_610 d_port_615 d_port_COM d_port_CPD 
drop d_port_FOR d_port_MCS d_port_PIF d_port_PSD d_port_REP d_port_other 
drop d_tsr_zero d_tsr_nines d_cdss_zero d_cdss_nines
rename probc_score probc
drop if probc > 1
drop if probc < 0



* Main vars descr stats
* --- Compact summary table ---
tabstat fico tsr cdss probc, statistics(mean sd min p25 median p75 max n) columns(statistics)


* Log Base Model
logit roll_forward fico tsr cdss probc
margins, dydx(fico tsr cdss probc)
lroc



* Log Full Model
logit roll_forward fico tsr cdss probc num_products bal_due bal_over_expr tenure cs_other cs_low_balance cs_currents cs_seg_a cs_high_balance cs_cfs_team cs_arct_team d_chrg_lend d_chrg tsr_sq cdss_sq
margins, dydx(fico tsr cdss probc num_products bal_due bal_over_expr tenure cs_other cs_low_balance cs_currents cs_seg_a cs_high_balance cs_cfs_team cs_arct_team d_chrg_lend d_chrg tsr_sq cdss_sq)
lroc





* --- Binned averages of roll_forward vs each predictor ---
local vars fico tsr cdss probc
local K = 20   // number of bins

foreach v of local vars {
    preserve
        keep roll_forward `v'
        drop if missing(roll_forward, `v')

        * create quantile bins
        xtile xbin = `v', n(`K')

        * compute bin means
        collapse (mean) mean_rf=roll_forward mean_x=`v', by(xbin)

        * sort for plotting
        sort mean_x

        * plot with fixed y-axis range 0–0.5
        twoway (connected mean_rf mean_x, ///
            msize(small) msymbol(o) lwidth(medthick)) ///
            , ytitle("Average roll_forward") ///
              xtitle("`v'") ///
              yscale(range(0 .5)) ylabel(0(.1).5) ///
              title("Average roll_forward vs `v'") ///
              name(g_`v', replace)
    restore
}
















version 18.5
clear all
set more off
set seed 42

// =========================================================================
// =============== RUN 2: Consumer (FINAL_CONS.dta) ====================
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
drop d_port_250 d_port_CPD d_port_MCS d_port_PIF d_port_other 
drop d_tsr_zero d_tsr_nines d_cdss_zero d_cdss_nines
rename probc_score probc
drop if probc > 1
drop if probc < 0



* Main vars descr stats
* --- Compact summary table ---
tabstat fico tsr cdss probc, statistics(mean sd min p25 median p75 max n) columns(statistics)





* Log Base Model
logit roll_forward fico tsr cdss probc
margins, dydx(fico tsr cdss probc)
lroc



* Log Full Model
logit roll_forward fico tsr cdss probc num_products bal_due bal_over_expr tenure cs_other cs_low_balance cs_currents cs_seg_a cs_high_balance cs_cfs_team cs_arct_team d_chrg_lend d_chrg tsr_sq cdss_sq
margins, dydx(fico tsr cdss probc num_products bal_due bal_over_expr tenure cs_other cs_low_balance cs_currents cs_seg_a cs_high_balance cs_cfs_team cs_arct_team d_chrg_lend d_chrg tsr_sq cdss_sq)
lroc






* --- Binned averages of roll_forward vs each predictor ---
local vars fico tsr cdss probc
local K = 20   // number of bins

foreach v of local vars {
    preserve
        keep roll_forward `v'
        drop if missing(roll_forward, `v')

        * create quantile bins
        xtile xbin = `v', n(`K')

        * compute bin means
        collapse (mean) mean_rf=roll_forward mean_x=`v', by(xbin)

        * sort for plotting
        sort mean_x

        * plot with fixed y-axis range 0–0.5
        twoway (connected mean_rf mean_x, ///
            msize(small) msymbol(o) lwidth(medthick)) ///
            , ytitle("Average roll_forward") ///
              xtitle("`v'") ///
              yscale(range(0 .5)) ylabel(0(.1).5) ///
              title("Average roll_forward vs `v'") ///
              name(g_`v', replace)
    restore
}

