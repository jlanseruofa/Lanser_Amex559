*------------------------------------------------------------
* Project: PR Heat Survey
* Created on: Oct 2025
* Created by: Joseph Lanser and Anna Josephson
* Edited on: 23 Oct 2025
* Edited by: JL
* Stata v.18.5
*
* Does:
*   - Encodes/aligns contributors so higher = more heat exposure
*   - Builds equal-weight (z-mean) and PCA-weight (PC1) indices
*   - Chooses final exposure_index by rule:
*       use PCA if PC1 explains >= 50% variance; else equal-weight
*   - Aligns PCA sign to match equal-weight direction

*   - Ultimately ends up choosing equal weight index
*------------------------------------------------------------


clear all
set more off

*------------------------------------------------------------
* 0) Open Indexed PR Heat Survey Data
*------------------------------------------------------------
use "$data/prheatsurvey_clean_indexed.dta", clear

*------------------------------------------------------------
* 1) Clean/encode inputs so that higher = more exposure
*    (Set "didn't answer" / non-substantive codes to missing)
*------------------------------------------------------------

* work_location: 1=inside (low), 2=outside (high), 3=mix (mid)
capture drop workloc_exposure
gen float workloc_exposure = .
replace workloc_exposure = 0   if work_location == 1
replace workloc_exposure = 1   if work_location == 2
replace workloc_exposure = 0.5 if work_location == 3
label var workloc_exposure "Exposure: work location (0=inside, 1=outside)"

* air_conditioned_transportation: 1=yes (low), 2=no (high), 3=no answer -> .
capture drop actrans_exposure
gen float actrans_exposure = .
replace actrans_exposure = 0 if air_conditioned_transportation == 1
replace actrans_exposure = 1 if air_conditioned_transportation == 2
* 3 stays missing
label var actrans_exposure "Exposure: AC in transport (0=yes AC, 1=no AC)"

* slept_in_hot_temp: 1=never (low) ... 5=always (high) -> rescale 0..1
capture drop slept_hot_exposure
gen double slept_hot_exposure = .
replace slept_hot_exposure = (slept_in_hot_temp - 1)/4 if inrange(slept_in_hot_temp,1,5)
label var slept_hot_exposure "Exposure: slept in hot temps (0..1)"

* transportation_to_work:
* 1 own car (low), 2 someone else's car (low), 3 public (mid),
* 4 bike (high), 5 walk (highest), 6 other (mid by assumption)
capture drop transmode_exposure
gen double transmode_exposure = .
replace transmode_exposure = 0   if inlist(transportation_to_work,1,2)          // cars
replace transmode_exposure = 0.6 if inlist(transportation_to_work,3,6)          // public/other
replace transmode_exposure = 0.9 if transportation_to_work == 4                  // bike
replace transmode_exposure = 1   if transportation_to_work == 5                  // walk
label var transmode_exposure "Exposure: commute mode (higher=more exposed)"

* use_public_ac: 1=low use (high exposure) ... 5=heavy use (low exposure)
* invert to make higher = more exposure, and rescale 0..1
capture drop publicac_exposure
gen double publicac_exposure = .
replace publicac_exposure = (5 - use_public_ac)/4 if inrange(use_public_ac,1,5)
label var publicac_exposure "Exposure: (1-use_public_ac) rescaled (0..1)"

* heat_related_symptoms: count, higher = worse/more exposure-related issues
capture drop symptoms_exposure
gen double symptoms_exposure = heat_related_symptoms
label var symptoms_exposure "Exposure: heat-related symptoms (count)"

*------------------------------------------------------------
* 2) Standardize all exposure contributors (z-scores)
*------------------------------------------------------------
local parts workloc_exposure actrans_exposure slept_hot_exposure ///
            transmode_exposure publicac_exposure symptoms_exposure

foreach v of local parts {
    capture drop z_`v'
    egen double z_`v' = std(`v')
    label var z_`v' "z: `: var label `v''"
}

*------------------------------------------------------------
* 3) Equal-weight index (mean of z-scores across available parts)
*------------------------------------------------------------
capture drop exposure_index_equal
egen double exposure_index_equal = rowmean( ///
    z_workloc_exposure z_actrans_exposure z_slept_hot_exposure ///
    z_transmode_exposure z_publicac_exposure z_symptoms_exposure )
label var exposure_index_equal "Exposure index (equal-weighted z-mean)"

*------------------------------------------------------------
* 4) PCA on standardized parts (complete cases only)
*------------------------------------------------------------
tempvar pcasample
gen byte `pcasample' = !missing( ///
    z_workloc_exposure, z_actrans_exposure, z_slept_hot_exposure, ///
    z_transmode_exposure, z_publicac_exposure, z_symptoms_exposure )

pca z_workloc_exposure z_actrans_exposure z_slept_hot_exposure ///
    z_transmode_exposure z_publicac_exposure z_symptoms_exposure ///
    if `pcasample', components(6)

di as txt "----- PCA loadings (all components) -----"
estat loadings

di as txt "----- PCA eigenvalues / proportion -----"
estat summarize

* Save PC1 score (standardized by default)
capture drop exposure_index_pca
predict double exposure_index_pca if e(sample), score
label var exposure_index_pca "Exposure index (PCA first component score)"

* Align PCA sign to match equal-weight direction (optional but recommended)
corr exposure_index_equal exposure_index_pca if e(sample)
replace exposure_index_pca = -exposure_index_pca if r(rho) < 0

*------------------------------------------------------------
* 5) Decision rule using correct PC1 variance share
*   NOTE: e(Ev) is a 1 x k vector; use e(trace) for denominator
*------------------------------------------------------------
tempname ev
matrix `ev' = e(Ev)
scalar _pc1prop = el(`ev',1,1) / e(trace)
di as txt "Proportion of variance explained by PC1: " %5.3f _pc1prop

*------------------------------------------------------------
* 6) Final exposure_index assignment
*------------------------------------------------------------
capture drop exposure_index
gen double exposure_index = .
replace exposure_index = exposure_index_pca   if _pc1prop >= 0.50
replace exposure_index = exposure_index_equal if _pc1prop <  0.50
label var exposure_index "Exposure index (rule: PCA if PC1 >=50% variance else equal-weight)"

* Optional standardized version (for interpretability)
capture drop exposure_index_z
egen double exposure_index_z = std(exposure_index)
label var exposure_index_z "Exposure index (z-standardized)"

*------------------------------------------------------------
* 7) Quick comparisons & sanity checks
*------------------------------------------------------------
di as txt "----- Correlations between candidate indices (PCA sample) -----"
corr exposure_index_equal exposure_index_pca if `pcasample'

di as txt "----- Summary of final exposure_index -----"
summ exposure_index

* Optional: Scree plot
* screeplot, yline(1)




*drop un needed variables
drop workloc_exposure actrans_exposure slept_hot_exposure transmode_exposure publicac_exposure symptoms_exposure z_workloc_exposure z_actrans_exposure z_slept_hot_exposure z_transmode_exposure z_publicac_exposure z_symptoms_exposure exposure_index_equal exposure_index_pca
drop exposure_index_z


* Step 5: save final clean file
save "$data/prheatsurvey_w_exposureindex.dta", replace
