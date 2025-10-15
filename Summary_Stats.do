*---------------------------------------------*
* Summary stats: mean, median, range, std dev *
*---------------------------------------------*

* List of variables
local vars age sex years_lived_inpr employment_status job_type financial_decisionmaker ///
    household_size total_household_income postal_code degree_of_education too_hot_tempf ///
    work_location transportation_to_work air_conditioned_transportation commute_time ///
    health_self_asses health_concern_when_hot likely_heat_related_issues ///
    family_heat_issues_likely community_heat_issues_likely trust_index ///
    heat_related_symptoms use_public_ac slept_in_hot_temp keep_cool_methods ///
    AC_hours_per_week decreased_ac_use health_index had_covid environmental_concern_index

* Create a summary table with key statistics
foreach v of local vars {
    display "--------------------------------------------------"
    display "Variable: `v'"
    quietly summarize `v', detail

    display "Mean = " %9.3f r(mean)
    display "Median = " %9.3f r(p50)
    display "Range = " %9.3f (r(max) - r(min))
    display "Standard Deviation = " %9.3f r(sd)
    display "--------------------------------------------------"
    display ""
}

* Optional: Save the summary stats to a dataset
preserve
tempfile summary_stats
postfile stats str32 variable mean median range sd using `summary_stats', replace
foreach v of local vars {
    quietly summarize `v', detail
    post stats ("`v'") (r(mean)) (r(p50)) (r(max) - r(min)) (r(sd))
}
postclose stats
use `summary_stats', clear
list, clean
restore
