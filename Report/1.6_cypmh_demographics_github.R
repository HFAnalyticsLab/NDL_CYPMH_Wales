knitr::opts_chunk$set(echo = TRUE)

## install.packages("flextable")
## install.packages("data.table")
## install.packages("base64enc")
## install.packages("uuid")
## install.packages("janitor")
## install.packages("officer")
## install.packages("kableExtra")
## install.packages("viridisLite")

library(dplyr)
library(reshape2)
library(janitor)
library(flextable)
library(officer)
library(kableExtra)
library(stringr)
library(tidyr)

raw_cohort <- read.csv(".Data/DF_data/SAIL exports/Current obj2 (all services) newAgeGp/cohortDenomTab.csv")
raw_RR2016_2020 <- read.csv('.Data/DF_data/SAIL exports/Current obj3 newAgeGp/Obj3Table_2016_2020.csv')
raw_cohort_mh <- read.csv(".Data/DF_data/SAIL exports/Current obj1 (WAST) newAgeGp/cohortDenomTab_MHonly2.csv")
raw_cohort_non_mh <- read.csv(".Data/DF_data/SAIL exports/Current obj1 (WAST) newAgeGp/cohortDenomTab_nonMonly.csv")

#long denominator table
df_cohort_long <- raw_cohort %>%
  select(-X, -persondays) %>%
  rename(overall = personyears) %>%
  melt(id = c("yr", "overall")) %>%
  rename(pyar = value)

# tidy up column names, add column for category
df_cohort_pct <- df_cohort_long %>%
  mutate(pct = pyar / overall * 100) %>%
  rename(level = variable) %>%
  mutate(category = ifelse(level == "overall", "overall", ifelse(level %in% c("male", "female"), "sex",
                           ifelse(level %in% c("X11.15", "X16.17", "X18.24"), "age", 
                                  ifelse(level %in% c("wimd1", "wimd2", "wimd3", "wimd4", "wimd5"), "wimd", 
                                         ifelse(level %in% c("rural", "urban"), "ruc",
                                                ifelse(level %in% c("sms", "nosms"), "sms", "hb")))))),
         level = gsub("X", "", as.character(level)),
         level = gsub("\\b.\\b", "-",  as.character(level))) %>% 
  select(yr, category, level, everything())

# Average percentage table
df_cohort_pct_avg_long <- df_cohort_pct %>%
  select(-overall, -pyar) %>%
  group_by(level) %>%
  mutate(avg_pct = mean(pct)) %>% 
  select(-yr, -pct) %>%
  distinct() %>%
  filter(category != "hb") %>%
  arrange(factor(category, levels = c("sex", "age", "wimd", "ruc", "sms")))

# Tidy average pct table for flextable output
df_cohort_pct_avg_long_tidy <- df_cohort_pct_avg_long %>%
  mutate(category = gsub("sex", "Sex", as.character(category)),
         category = gsub("age", "Age Group", as.character(category)),
         category = gsub("wimd", "Deprivation Quintile", as.character(category)),
         category = gsub("ruc", "Rurality", as.character(category)),
         category = gsub("sms", "Substance Misuse Services History", as.character(category)),
         level = gsub("\\bmale\\b", "Male", as.character(level)),
         level = gsub("\\bfemale\\b", "Female", as.character(level)),
         level = gsub("wimd", "", as.character(level)),
         level = gsub("\\b1\\b", "1 (most)", as.character(level)),
         level = gsub("\\b5\\b", "5 (least)", as.character(level)),
         level = gsub("rural", "Rural", as.character(level)),
         level = gsub("urban", "Urban", as.character(level)),
         level = gsub("nosms", "No SMS history", as.character(level)),
         level = gsub("sms", "SMS history", as.character(level)))

#long denominator table
df_cohort_non_mh_long <- raw_cohort_non_mh %>%
  select(-X, -persondays) %>%
  rename(overall = personyears) %>%
  melt(id = c("yr", "overall")) %>%
  rename(pyar = value)

# tidy up column names, add column for category
df_cohort_non_mh_pct <- df_cohort_non_mh_long %>%
  mutate(pct = pyar / overall * 100) %>%
  rename(level = variable) %>%
  mutate(category = ifelse(level == "overall", "overall", ifelse(level %in% c("male", "female"), "sex",
                           ifelse(level %in% c("X11.15", "X16.17", "X18.24"), "age", 
                                  ifelse(level %in% c("wimd1", "wimd2", "wimd3", "wimd4", "wimd5"), "wimd", 
                                         ifelse(level %in% c("rural", "urban"), "ruc",
                                                ifelse(level %in% c("sms", "nosms"), "sms", "hb")))))),
         level = gsub("X", "", as.character(level)),
         level = gsub("\\b.\\b", "-",  as.character(level))) %>% 
  select(yr, category, level, everything())

# Average percentage table
df_cohort_non_mh_pct_avg_long <- df_cohort_non_mh_pct %>%
  select(-overall, -pyar) %>%
  group_by(level) %>%
  mutate(non_mh_avg_pct = mean(pct)) %>% 
  select(-yr, -pct) %>%
  distinct() %>%
  filter(category != "hb") %>%
  arrange(factor(category, levels = c("sex", "age", "wimd", "ruc", "sms")))

# Tidy average pct table for flextable output
df_cohort_non_mh_pct_avg_long_tidy <- df_cohort_non_mh_pct_avg_long %>%
  mutate(category = gsub("sex", "Sex", as.character(category)),
         category = gsub("age", "Age Group", as.character(category)),
         category = gsub("wimd", "Deprivation Quintile", as.character(category)),
         category = gsub("ruc", "Rurality", as.character(category)),
         category = gsub("sms", "Substance Misuse Services History", as.character(category)),
         level = gsub("\\bmale\\b", "Male", as.character(level)),
         level = gsub("\\bfemale\\b", "Female", as.character(level)),
         level = gsub("wimd", "", as.character(level)),
         level = gsub("\\b1\\b", "1 (most)", as.character(level)),
         level = gsub("\\b5\\b", "5 (least)", as.character(level)),
         level = gsub("rural", "Rural", as.character(level)),
         level = gsub("urban", "Urban", as.character(level)),
         level = gsub("nosms", "No SMS history", as.character(level)),
         level = gsub("sms", "SMS history", as.character(level)))

#long denominator table
df_cohort_mh_long <- raw_cohort_mh %>%
  select(-X, -persondays) %>%
  rename(overall = personyears) %>%
  melt(id = c("yr", "overall")) %>%
  rename(pyar = value)

# tidy up column names, add column for category
df_cohort_mh_pct <- df_cohort_mh_long %>%
  mutate(pct = pyar / overall * 100) %>%
  rename(level = variable) %>%
  mutate(category = ifelse(level == "overall", "overall", ifelse(level %in% c("male", "female"), "sex",
                           ifelse(level %in% c("X11.15", "X16.17", "X18.24"), "age", 
                                  ifelse(level %in% c("wimd1", "wimd2", "wimd3", "wimd4", "wimd5"), "wimd", 
                                         ifelse(level %in% c("rural", "urban"), "ruc",
                                                ifelse(level %in% c("sms", "nosms"), "sms", "hb")))))),
         level = gsub("X", "", as.character(level)),
         level = gsub("\\b.\\b", "-",  as.character(level))) %>% 
  select(yr, category, level, everything())

# Average percentage table
df_cohort_mh_pct_avg_long <- df_cohort_mh_pct %>%
  select(-overall, -pyar) %>%
  group_by(level) %>%
  mutate(mh_avg_pct = mean(pct)) %>% 
  select(-yr, -pct) %>%
  distinct() %>%
  filter(category != "hb") %>%
  arrange(factor(category, levels = c("sex", "age", "wimd", "ruc", "sms")))

# Tidy average pct table for flextable output
df_cohort_mh_pct_avg_long_tidy <- df_cohort_mh_pct_avg_long %>%
  mutate(category = gsub("sex", "Sex", as.character(category)),
         category = gsub("age", "Age Group", as.character(category)),
         category = gsub("wimd", "Deprivation Quintile", as.character(category)),
         category = gsub("ruc", "Rurality", as.character(category)),
         category = gsub("sms", "Substance Misuse Services History", as.character(category)),
         level = gsub("\\bmale\\b", "Male", as.character(level)),
         level = gsub("\\bfemale\\b", "Female", as.character(level)),
         level = gsub("wimd", "", as.character(level)),
         level = gsub("\\b1\\b", "1 (most)", as.character(level)),
         level = gsub("\\b5\\b", "5 (least)", as.character(level)),
         level = gsub("rural", "Rural", as.character(level)),
         level = gsub("urban", "Urban", as.character(level)),
         level = gsub("nosms", "No SMS history", as.character(level)),
         level = gsub("sms", "SMS history", as.character(level)))

df_RR2016_2020 <- raw_RR2016_2020 %>%
  filter(variable != "Health board" & variable != "(Intercept)" & variable != "Year") %>%
  mutate(IRR_LCI_UCI = str_c(RR_adj, " (", lci_adj, ", ", uci_adj, ")")) %>%
  select(variable, category, IRR_LCI_UCI) %>%
  rename(category = variable, level = category) %>%
  mutate(category = gsub("Age group", "Age Group", as.character(category)),
         category = gsub("WIMD", "Deprivation Quintile", as.character(category)),
         category = gsub("Urban/rural", "Rurality", as.character(category)),
         category = gsub("SMS history", "Substance Misuse Services History", as.character(category)),
         level = gsub("[*]", "", as.character(level)),
         level = if_else(category == "Substance Misuse Services History" & level == 0, "No SMS history", if_else(category == "Substance Misuse Services History" & level == 1, "SMS history", level)),
         level = gsub("\\b1\\b", "1 (most)", as.character(level)),
         level = gsub("\\b5\\b", "5 (least)", as.character(level)))

df_RR2016_2020[is.na(df_RR2016_2020)] <- "reference"

df_demographics <- df_cohort_pct_avg_long_tidy %>%
  merge(df_cohort_non_mh_pct_avg_long_tidy, all = TRUE) %>%
  merge(df_cohort_mh_pct_avg_long_tidy, all = TRUE) %>%
  merge(df_RR2016_2020, all = TRUE) %>%
  arrange(factor(category, levels = c("Sex", "Age Group", "Deprivation Quintile", "Rurality", "Substance Misuse Services History")))


# One column with average across 5 years
ft_cohort_pct_avg_long <- flextable(
  df_cohort_pct_avg_long_tidy,
  col_keys = c("category", "level", "avg_pct")
)
              
ft_pct_avg_long <- ft_cohort_pct_avg_long %>%
  merge_v(j = ~ category) %>%
  set_header_labels(category = "Demographic", level = "Demographic", avg_pct = "Average Percentage (2016-2020)") %>%
  merge_at(i = 1, j = 1:2, part = "header") %>%
  colformat_double(digits = 2) %>%
  border_inner(border = fp_border(color = "grey")) %>%
  hline(i = 2, border = fp_border(color = "black", width = 2)) %>%
  hline(i = 5, border = fp_border(color = "black", width = 2)) %>%
  hline(i = 10, border = fp_border(color = "black", width = 2)) %>%
  hline(i = 12, border = fp_border(color = "black", width = 2)) %>%
  hline(i = 14, border = fp_border(color = "black", width = 2)) %>%
  bold(j = 1:2, bold = TRUE) %>%
  bold(i = 1, part = "header", bold = TRUE) %>% 
  fix_border_issues() %>%
  fontsize(size = 14, part = "all") %>%
  color(color = "#3c5888", part = "all") %>%
  border(border = fp_border(color = "#3c5888"), part = "all")

ft_pct_avg_long2 <- ft_pct_avg_long %>%
  width(width = c(1.8, 1.5, 1.5)) %>%
  hrule(rule = "exact") %>%
  height_all(height = 0.25)

ft_demographics_mh_irr <- flextable(
  df_demographics,
  col_keys = c("category", "level", "non_mh_avg_pct", "mh_avg_pct", "IRR_LCI_UCI")
)
              
ft_demographics2_mh_irr <- ft_demographics_mh_irr %>%
  merge_v(j = ~ category) %>%
  colformat_double(digits = 2) %>%
  set_header_labels(category = "Demographic", level = "Demographic", mh_avg_pct = "Average yearly % with a MH crisis event (2016-2020)", non_mh_avg_pct = "Average yearly % without a MH crisis event (2016-2020)", IRR_LCI_UCI = "Adjusted incidence rate ratio (95%)*") %>%
  merge_at(i = 1, j = 1:2, part = "header") %>%
  add_footer(top = FALSE, category = "*adjusted for sex, age group, deprivation quintile, rurality, health board, year and SMS history.") %>%
  merge_at(i = 1, j = 1:5, part = "footer") %>%
  border_inner(border = fp_border(color = "grey")) %>%
  hline(i = 2, border = fp_border(color = "black", width = 2)) %>%
  hline(i = 5, border = fp_border(color = "black", width = 2)) %>%
  hline(i = 10, border = fp_border(color = "black", width = 2)) %>%
  hline(i = 12, border = fp_border(color = "black", width = 2)) %>%
  hline(i = 14, border = fp_border(color = "black", width = 2)) %>%
  bold(j = 1:2, bold = TRUE) %>%
  bold(i = 1, part = "header", bold = TRUE) %>% 
  fix_border_issues() %>%
  fontsize(size = 14, part = "all") %>%
  color(color = "#3c5888", part = "all") %>%
  border(border = fp_border(color = "#3c5888"), part = "all")

ft_demographics3_mh_irr <- ft_demographics2_mh_irr %>%
  width(width = 2) %>%
  hrule(rule = "exact") %>%
  height_all(height = 0.25)

