*** Joseph Lanser | AREC 559
*** looks at Roll Forward Rate by decile of CDSS



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

drop fico tsr num_products d_train bal_due bal_over_expr tenure cs_other cs_low_balance cs_currents cs_seg_a cs_high_balance cs_cfs_team cs_arct_team d_chrg_lend d_chrg d_port_200 d_port_250 d_port_600 d_port_610 d_port_615 d_port_COM d_port_CPD d_port_FOR d_port_MCS d_port_PIF d_port_PSD d_port_REP d_port_other d_tsr_zero d_tsr_nines d_cdss_zero d_cdss_nines tsr_sq cdss_sq


preserve
    keep if !missing(cdss, roll_forward)
    xtile cdss_dec = cdss, nq(10)
    collapse (mean) rf_mean=roll_forward, by(cdss_dec)

    twoway connected rf_mean cdss_dec, ///
        xlabel(1(1)10, valuelabel angle(45)) ///
        yscale(range(0 1)) ylabel(0(.1)1) ///
        ytitle("Proportion roll_forward = 1") ///
        xtitle("CDSS decile") ///
        title("roll_forward by CDSS decile")
restore







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


preserve
    keep if !missing(cdss, roll_forward)
    xtile cdss_dec = cdss, nq(10)
    collapse (mean) rf_mean=roll_forward, by(cdss_dec)

    twoway connected rf_mean cdss_dec, ///
        xlabel(1(1)10, valuelabel angle(45)) ///
        yscale(range(0 1)) ylabel(0(.1)1) ///
        ytitle("Proportion roll_forward = 1") ///
        xtitle("CDSS decile") ///
        title("roll_forward by CDSS decile")
restore
















*** Joseph Lanser | AREC 559
*** looks at Roll Forward Rate by decile of TSR



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



preserve
    keep if !missing(tsr, roll_forward)
    xtile tsr_dec = tsr, nq(10)
    collapse (mean) rf_mean=roll_forward, by(tsr_dec)

    twoway connected rf_mean tsr_dec, ///
        xlabel(1(1)10, valuelabel angle(45)) ///
        yscale(range(0 1)) ylabel(0(.1)1) ///
        ytitle("Proportion roll_forward = 1") ///
        xtitle("TSR decile") ///
        title("roll_forward by TSR decile")
restore







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



preserve
    keep if !missing(tsr, roll_forward)
    xtile tsr_dec = tsr, nq(10)
    collapse (mean) rf_mean=roll_forward, by(tsr_dec)

    twoway connected rf_mean tsr_dec, ///
        xlabel(1(1)10, valuelabel angle(45)) ///
        yscale(range(0 1)) ylabel(0(.1)1) ///
        ytitle("Proportion roll_forward = 1") ///
        xtitle("TSR decile") ///
        title("roll_forward by TSR decile")
restore
