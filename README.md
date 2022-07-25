<img src="ndlbanner.png" width="405" height="96">

# Networked Data Lab: NDL Wales analysis on mental health crises in 11-24 year olds in Wales between 2016 and 2020

#### Project Status: In-progress

## Project Description

- This Networked Data Lab analysis by the NDL lab in Wales focusses on mental health crises in children and young people aged 11-24 years old in Wales between 2016 and 2020. There are three publications to the analysis:
  *Contribution to the [Health Foundation NDL Briefing](https://www.health.org.uk/publications/reports/improving-children-and-young-peoples-mental-health-services) 
  *Academic publication on mental health crisis attendance rates by Welsh Ambulance Service Trust *[in progress, add link when published]*
  *[Slide deck](https://github.com/HFAnalyticsLab/NDL_CYPMH_Wales/blob/main/Report/2022PHWNDLMentalHealth_final.pdf) on mental health crisis presentations across acute care services (ambulance, emergency department and emergency inpatient admissions) 
- Please note that these research outputs have not yet been peer-reviewed and should be treated as preliminary.

## Data sources

This analysis used the following data, accessed via the SAIL Databank, Project 1330:

- Welsh Ambulance Service Trust (WAST) (as at 17/9/2021), used to identify WAST attendances for mental health-related issues
- Emergency Department Data Set (EDDS) (as at 1/10/2021), used to identify emergency department visits for mental health-related issues
- Patient Episode Database Wales (PEDW) (as at 4/7/2021), used to identify emergency admissions for mental health-related issues
- Substance Misuse Data Set (SMDS) (as at 28/6/2021), used to determine whether individuals had a history of substance use
- Welsh Demographic Service Dataset (WDSD) (as at 4/7/2021), used to determine individuals that meet the study criteria for inclusion in the cohort, the time periods for inclusion, and their demographic information
- Annual District Death Extract (ADDE) (as at 28/6/2021), used to censor deaths in the cohort
- Wales Longitudinal General Practice data (WLGP) (as at 1/6/2021), used to identify GP attendances before and after a patient’s mental health crisis


## How does it work?
A cohort of individuals meeting the study criteria is created based on the WDSD and ADDE datasets. The amount of time each individual spends in the cohort (person years at risk) and their demographic information is determined for each calendar year between 2016 and 2020. Substance misuse history is determined for each individual from the SMDS dataset.
Cases definitions for mental health crisis were determined and applied for each dataset (WAST, EDDS and PEDW). To prevent counting an individual’s mental health crisis multiple times, if they have multiple presentations within a two day period, these cases are merged together. Analysis was performed separately on this combined case list and the list of cases presenting to WAST. 


## Requirements

SQL was written to query a DB2 database in SAIL Project 1330. R scripts were written in R 4.1.2 and run in RStudio.

## Getting started

In SAIL Project 1330, ‘create_cohort_and_caselist.sql’ was run first to create the cohort and case lists for all outputs.
Then the following files were run for each publication output:
- Health Foundation NDL Briefing [add link when published]:
  * In SAIL Project 1330:
    * ‘NDLWales_HealthFoundationBriefing.rmd’ was run to produce the outputs included in the Health Foundation Briefing 
- Academic publication [in progress]:
  * In SAIL Project 1330:
    * ‘df_obj1 wastpaper.rmd’ was run for the main analysis
    * ‘wastpaper_regression.rmd’ was run for the regression output
  * locally:
    * ‘01_cypmh_wast_paper_trends.rmd’
    * ‘02_cypmh_wast_paper_totals.Rmd’
    * ‘03_cypmh_wast_paper_sms_trends.Rmd’
    * '04_cypmh_wast_paper_outcomes.Rmd'
- Slide deck on mental health crisis presentations across acute care services [in progress]:
  * In SAIL Project 1330:
    * 'acute_services_analysis.rmd' - produces rate tables (re-requested 9/5/2022 acute_services_events_export.Rmd)
    * 'acute_services_risk_factor_model.rmd' - produces adjusted risk ratio table
  * Run locally:
    * 'cypmh_slides_ppt.rmd' (calls on files: ‘1.1_cypmh_all_trends.Rmd’, ‘1.3_cypmh_sms_trends.R’, ‘1.5_Obj3_slides.R’, ‘1.6_cypmh_demographics.R’, ‘1.7_cypmh_funnel.R’, ‘1.8_cypmh_images.R’ - *1.5 must be run before the .Rmd*)


## Authors

- David Florentin 
- Laura Bentley - [Email](laura.bentley@wales.nhs.uk)

## License

This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).
