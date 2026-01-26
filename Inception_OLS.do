*------------------------------------------------------------
* Project: PR Heat Survey
* Created on: Jan 14 2026
* Created by: Joseph Lanser and Anna Josephson
* Edited on: 26 Jan 2026
* Edited by: JL
* Stata v.18.5
*
* Does:
*   - Runs Models 1 and 2 in an OLS Fashion 
*   -(See 1/12 Satheesh Meeting Doc for details)
*------------------------------------------------------------


clear all
use "$data/prheatsurvey_clean_oct25.dta", clear



* Clean missing data to represent reality
* Note: removed d_finances_constr_ac_use from all models due to high missingness and correlation with variables such as Income, Employment Status Etc.

* For AC Hour variables, missings are people who don't have AC at home, should be 0 not missing *
foreach var in weekday_ac_hours_per_day weekend_ac_hours_per_day ac_hours_per_week {
    replace `var' = 0 if missing(`var')
}

* For Work location and job type vars, missings are unemployed people, should be 0 not missing *
foreach var in job_type work_location {
    replace `var' = 0 if missing(`var')
}



* Defining Variable Buckets… 

* Bucket O: Outcomes
*Exposure Index (heat exposure / experienced heat burden)

*Bucket C: Coping Strategies  (Choices, not traits)
* -Average AC Hours per Week
* -Dummy AC Use
* -Dummy AC Transportation

*Bucket EC: Enablers and Constraints
* -Household income
* -Work location
* -Electricity cost concern
* -Dummy missed electricity bill
* -Dummy alt energy source

*Bucket P: Preferences/Beliefs
* -Health index
* -Environmental concern index
* -Perceived Risk Index
* -Trust Index

*Bucket D: Demographic Controls
* -Age
* -Gender
* -Dummy college degree
* -Household size
* -Job type
* -Metro Dummy



* Model 1: What Drives Heat Exposure?
* Goal: Identify which coping strategies matter most, 
* and take most important strategy into y var for Model 2
* Exposure index = Bucket C, Bucket D
* Clustered by Postal Code to avoid Autocorrelation
* Sample size varies across specifications due to item nonresponse

regress exposure_index ///
    ac_hours_per_week use_public_ac ///
    d_ac_trans ///
    age d_female d_college_degree household_size ///
    d_metro, vce(cluster postal_code)

	
	
* Reults: use of public AC and having AC Transportation have the strongest and most significant effect on exposure *





* Model 2: What drives AC Home Use, AC Transportation, and Use of Public AC?
* Goal: Explain why the strongest coping strategies happens or not.
* AC Home Use, AC Public Use, or AC Transportation = Bucket EC, Bucket P, Bucket D


* y = ac hours per week
regress ac_hours_per_week ///
    total_household_income ///
    work_location ///
    d_missed_elec_bill ///
    d_alt_energy_source ///
    health_index ///
    trust_index ///
    environmental_concern_index ///
    perceived_risk_index ///
    age d_female d_college_degree household_size ///
    i.job_type d_metro, vce(cluster postal_code)

	
* y = AC Transportation
regress d_ac_trans ///
    total_household_income ///
    work_location ///
    d_missed_elec_bill ///
    d_alt_energy_source ///
    health_index ///
    trust_index ///
    environmental_concern_index ///
    perceived_risk_index ///
    age d_female d_college_degree household_size ///
    i.job_type d_metro, vce(cluster postal_code)

	
* y = Use of Public AC
regress use_public_ac ///
    total_household_income ///
    work_location ///
    d_missed_elec_bill ///
    d_alt_energy_source ///
    health_index ///
    trust_index ///
    environmental_concern_index ///
    perceived_risk_index ///
    age d_female d_college_degree household_size ///
    i.job_type d_metro, vce(cluster postal_code)



* Taking out job type and work location to improve number of obs...

regress ac_hours_per_week ///
    total_household_income ///
    d_missed_elec_bill ///
    d_alt_energy_source ///
    health_index ///
    trust_index ///
    environmental_concern_index ///
    perceived_risk_index ///
    age d_female d_college_degree household_size ///
    d_metro, vce(cluster postal_code)

	
regress d_ac_trans ///
    total_household_income ///
    d_missed_elec_bill ///
    d_alt_energy_source ///
    health_index ///
    trust_index ///
    environmental_concern_index ///
    perceived_risk_index ///
    age d_female d_college_degree household_size ///
    d_metro, vce(cluster postal_code)

	
regress use_public_ac ///
    total_household_income ///
    d_missed_elec_bill ///
    d_alt_energy_source ///
    health_index ///
    trust_index ///
    environmental_concern_index ///
    perceived_risk_index ///
    age d_female d_college_degree household_size ///
    d_metro, vce(cluster postal_code)

	
	
	
* Results: AC hours per week are consistently higher for households with greater income, 
* while perceived risk matters only in the fuller model and is replaced by health and 
* structural factors in the restricted specification. AC transportation is generally weakly 
* explained, but perceived heat risk is a significant predictor once job and work controls 
* are removed. Use of public AC is driven mainly by financial constraints and trust, 
* with little role for income or risk perceptions.
