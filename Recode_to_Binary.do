*------------------------------------------------------------
* Project: PR Heat Survey
* Created on: Oct 2025
* Created by: Joseph Lanser and Anna Josephson
* Edited on: 23 Oct 2025
* Edited by: JL
* Stata v.18.5
*
* Does:
*   - Make necessary dummies, recoding vars as needed
*   - Drops varibales we will never use
*------------------------------------------------------------


clear all
use "$data/prheatsurvey_w_exposureindex.dta", clear



* Drop un needed variables
drop id
drop municipality_value
drop define_too_hot
drop left_yearslived_blank
drop other_job_type
drop household_size_blank
drop other_degree_of_education
drop too_hot_tempc
drop too_hot_temp_blank
drop time_in_workplace
drop work_location
drop dress_code
drop transportation_multi_answer transportation_multi_answer2 transportation_multi_answer3 transportation_multi_answer4 transportation_multi_answer5 transportation_other
drop commute_time
drop main_heat_concern
drop doctor_nurse_trust university_researchers_trust religious_leaders_trust climate_scientists_trust politicians_trust
drop left_heat_related_blank
drop keepcoolmethods_multi_answer keepcoolmethods_multi_answer2 keepcoolmethods_multi_answer3 other_keep_cool_methods
drop left_achours_blank
drop decreased_ac_use
drop insomnia diabetes cardiovascular_condition respiratory_condition kidney_condition migraines cancer immunosuppressive_disease high_blood_pressure asthma obesity multiple_sclerosis chron_obst_pulm_dis chronic_bronchitis mental_health hadcovid
drop covid_effects_b covid_effects_c covid_effects_d
drop climate_change hot_temps heat_waves hurricanes air_pollution saharan_dust_events sea_level_rise_coastal_hazards hydrological_flood_risks blackouts earthquakes unemployment
label variable harm_huricanes_bi "Damage from hurricanes Irma or Maria?"
drop hurricane_irma_or_maria
drop date time duration callresult telephonenumber password
drop lived_in_pr
drop covid_effects_a
drop friend_family_had_covid
drop coolingspace_bi
drop warmsleep_bi
drop gender_bi
drop financial_constraint
drop __000000
drop income_clean
drop education_clean





* Recode to Dummies Whenver Possible*

replace municipality_of_residence = 0 if municipality_of_residence == 2
rename municipality_of_residence d_metro_res

replace less_than_21 = 0 if missing(less_than_21)
rename less_than_21 d_under_21

replace sex = 0 if sex == 2
replace sex = . if sex != 0 & sex != 1
rename sex d_female

replace employment_status = 0 if employment_status != 1 & !missing(employment_status)
rename employment_status d_employed

replace financial_decisionmaker = 0 if inlist(financial_decisionmaker, 2, 3)
replace financial_decisionmaker = . if !inlist(financial_decisionmaker, 0, 1)
rename financial_decisionmaker d_female_financial_lead

replace degree_of_education = 0 if inlist(degree_of_education, 1, 2)
replace degree_of_education = 1 if degree_of_education >= 3 & !missing(degree_of_education)
rename degree_of_education d_college_degree

gen d_ac_trans = .
replace d_ac_trans = 1 if inlist(transportation_to_work, 1, 2) & air_conditioned_transportation == 1
replace d_ac_trans = 0 if inlist(transportation_to_work, 1, 2) & air_conditioned_transportation != 1 & !missing(air_conditioned_transportation)
drop transportation_to_work air_conditioned_transportation

replace keep_cool_methods = 0 if keep_cool_methods == 1
replace keep_cool_methods = 1 if keep_cool_methods >= 2 & !missing(keep_cool_methods)
rename keep_cool_methods d_non_ac_cool_methods

replace fincances_reduced_ac_use = 0 if fincances_reduced_ac_use != 1 & !missing(fincances_reduced_ac_use)
rename fincances_reduced_ac_use d_finances_constr_ac_use

replace unable_to_pay_electric_bill = 0 if unable_to_pay_electric_bill != 1 & !missing(unable_to_pay_electric_bill)
rename unable_to_pay_electric_bill d_missed_elec_bill

replace alt_energy_during_blackouts = 1 if inlist(alt_energy_during_blackouts, 1, 2)
replace alt_energy_during_blackouts = 0 if !inlist(alt_energy_during_blackouts, 1, 2) & !missing(alt_energy_during_blackouts)
rename alt_energy_during_blackouts d_alt_energy_source

replace health_insurance_plan = 1 if inlist(health_insurance_plan, 1, 2, 3)
replace health_insurance_plan = 0 if inlist(health_insurance_plan, 4, 5)
rename health_insurance_plan d_health_insurance

replace had_covid = 0 if had_covid == 2
replace had_covid = . if had_covid == 3
rename had_covid d_had_covid

rename harm_huricanes_bi d_hurricane_damage

replace sealevel_rise_coastal_hazards = 0 if sealevel_rise_coastal_hazards == 1
replace sealevel_rise_coastal_hazards = 1 if sealevel_rise_coastal_hazards > 1 & !missing(sealevel_rise_coastal_hazards)
rename sealevel_rise_coastal_hazards d_sealevel_rise_damage

replace hydrological_flooding_risks = 0 if hydrological_flooding_risks == 1
replace hydrological_flooding_risks = 1 if hydrological_flooding_risks > 1 & !missing(hydrological_flooding_risks)
rename hydrological_flooding_risks d_flood_damage

replace earthquakes_p40 = 0 if earthquakes_p40 == 1
replace earthquakes_p40 = 1 if earthquakes_p40 > 1 & !missing(earthquakes_p40)
rename earthquakes_p40 d_earthquake_damage

replace tropicalstorm_laura_or_isaias = 0 if tropicalstorm_laura_or_isaias == 1
replace tropicalstorm_laura_or_isaias = 1 if tropicalstorm_laura_or_isaias > 1 & !missing(tropicalstorm_laura_or_isaias)
rename tropicalstorm_laura_or_isaias d_tropical_storm_damage




* Fix labels and names as needed *
label variable d_metro_res ""
label variable d_female ""
label variable d_employed ""
label variable d_female_financial_lead ""
label variable d_college_degree ""
label variable d_non_ac_cool_methods ""
label variable d_finances_constr_ac_use ""
label variable d_missed_elec_bill ""
label variable d_alt_energy_source ""
label variable d_health_insurance ""
label variable d_had_covid ""
label variable d_hurricane_damage ""
label variable d_sealevel_rise_damage ""
label variable d_flood_damage ""
label variable d_earthquake_damage ""
label variable d_tropical_storm_damage ""
rename heatsymptoms_bi d_heat_symptoms
label variable d_heat_symptoms ""
rename ac_binary_28a d_ac_use
label variable d_ac_use ""
rename AC_hours_per_week ac_hours_per_week
label variable exposure_index ""




* Save Cleaned and ready to roll dataset *
save "$data/prheatsurvey_clean_oct25.dta", replace
