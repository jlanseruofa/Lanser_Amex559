** Joseph Lanser Pulling Amex Data Test **


* --------- settings ---------
local HOME : env HOME
local box  "`HOME'/Library/CloudStorage/Box-Box"
local proj "Amex_2025_Class/Raw Data"

* The list of file suffixes to import (26..29)
local nums 26 27 28 29

* --------- convert CSVs to .dta (with a source tag) ---------
foreach n of local nums {
    local csv "`box'/`proj'/arec_project`n'.csv"
    local dta "`box'/`proj'/arec_project`n'.dta"

    capture confirm file "`csv'"
    if _rc {
        di as error "Missing CSV: `csv'"
        continue
    }

    import delimited using "`csv'", varnames(1) clear
    gen strL source_file = "arec_project`n'.csv"

    * save per-file .dta for faster reloads
    save "`dta'", replace
    di as txt "Saved: `dta'"
}

* --------- build a single combined dataset ---------
* Use the first .dta, append the rest
local first 1
tempfile combined

foreach n of local nums {
    local dta "`box'/`proj'/arec_project`n'.dta"
    capture confirm file "`dta'"
    if _rc {
        di as error "Skipping (no .dta found): `dta'"
        continue
    }

    if `first' {
        use "`dta'", clear
        save "`combined'", replace
        local first 0
    }
    else {
        use "`combined'", clear
        append using "`dta'"
        save "`combined'", replace
    }
}

* Load the combined dataset and save it permanently
use "`combined'", clear
compress
save "`box'/`proj'/arec_project_26_29_combined.dta", replace

di as result "Done. Combined file: `box'/`proj'/arec_project_26_29_combined.dta"
