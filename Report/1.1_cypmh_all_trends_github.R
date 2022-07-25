knitr::opts_chunk$set(echo = TRUE)

## install.packages("dplyr")
## install.packages("tidyr")
## install.packages("reshape2")
## install.packages("ggplot2")
## install.packages("knitr")
## install.packages("grid")
## install.packages("png")

library(dplyr)
library(tidyr)
library(reshape2) #melt
library(ggplot2)
library(knitr)
library(grid)

raw_event <- read.csv(".Data/DF_data/SAIL exports/Current obj2 (all services) newAgeGp/eventsCountByServiceTab.csv")

raw_cohort <- read.csv(".Data/DF_data/SAIL exports/Current obj2 (all services) newAgeGp/cohortDenomTab.csv")

raw_age_sex <- read.csv(".Data/DF_data/SAIL exports/Current obj2 (all services) newAgeGp/eventRateSexAgeYrTab.csv")

raw_person_sms <- read.csv(".Data/DF_data/SAIL exports/Current obj2 (all services) newAgeGp/people_by_sms_MHevent_yr.csv")

#long event count table
df_event_long <- raw_event %>%
  select(-X) %>%
  rename(overall = events) %>% 
  melt(id = c("yr", "first_service")) %>% 
  group_by(yr, variable) %>%
  mutate(events = sum(value)) %>% 
  select(-value, - first_service) %>%
  distinct() 

#long denominator table
df_cohort_long <- raw_cohort %>%
  select(-X, -persondays) %>%
  rename(overall = personyears) %>%
  melt(id = c("yr")) %>%
  rename(pyar = value)

#person count table
df_person <- raw_person_sms %>%
  select(-X,-noMH, -MHper1000) %>% 
  group_by(yr) %>%
  mutate(person_count = sum(MH)) %>% 
  select(yr, person_count) %>% 
  distinct() 

#combine and calculate rates and CIs
df_all_service_rates <- df_event_long %>%
  merge(df_cohort_long, all = TRUE) %>% 
  merge(df_person, all = TRUE) %>%
  #calculate rates and CIs
  rowwise() %>%
  mutate(rate_1000pyar = events/pyar * 1000,
         lci = poisson.test(events, pyar) [[4]] [1] * 1000,
         uci = poisson.test(events, pyar) [[4]] [2] * 1000)

#tidy up column names, add column for category
df_all_service <- df_all_service_rates %>%
  rename(level = variable) %>%
  mutate(category = ifelse(level == "overall", "overall", ifelse(level %in% c("male", "female"), "sex",
                           ifelse(level %in% c("X11.15", "X16.17", "X18.24"), "age", 
                                  ifelse(level %in% c("wimd1", "wimd2", "wimd3", "wimd4", "wimd5"), "wimd", 
                                         ifelse(level %in% c("rural", "urban"), "ruc",
                                                ifelse(level %in% c("sms", "nosms"), "sms", "hb")))))),
         level = gsub("X", "", as.character(level)),
         level = gsub("\\b.\\b", "-",  as.character(level))) %>%
  select(yr, category, everything()) %>%
  arrange(yr, category)

saveRDS(df_all_service, "df_all_service.Rdata")

df_events_person <- df_all_service %>%
  select(yr, category, events, person_count) %>%
  filter(category == "overall") %>% 
  pivot_longer(cols = !yr & !category,
               names_to = "type",
               values_to = "counts") 

line_overall_ppt <- df_all_service %>%
  filter(category == "overall") %>% 
  ggplot(aes(x = yr, 
             y = rate_1000pyar, 
             colour = level, 
             group = level)) +
  geom_line() +
  geom_errorbar(aes(ymin = lci, ymax = uci), width = 0.1) +
  scale_colour_manual(values = c("#325083"), 
                      labels = c("Total")) +
  scale_y_continuous(expand = c(0, 0), limits = c(0, 25),
                     breaks = seq(0, 25, 5)) +
  labs(title = "Figure 3: Overall rate of mental health (MH) crisis events \n (2016-2020)",
       x = "Year",
       y = "Rate of MH crisis events per 1,000 PYAR") +
  theme(# text = element_text(size = 14),
        plot.title.position = "plot",
        legend.position = "none",
        # legend.justification = "left",
        axis.title = element_text(color = "#3c5888"),
        axis.text = element_text(color = "#3c5888"),
        plot.title = element_text(color = "#3c5888"),
        axis.line = element_line(colour = "gray55"),
        legend.title = element_blank(),
        panel.background = element_blank(),
        panel.grid.major.x = element_blank(),
        panel.grid.minor.x = element_blank(),
        panel.grid.major.y = element_line(colour = "gray55"),
        panel.grid.minor.y = element_blank())

print(line_overall_ppt)

jpeg("line_overall_sex_ppt.jpg")
print(line_overall_ppt)
dev.off()

line_age_sex_ppt <- raw_age_sex %>%
  rename(sex = gndr_cd,
         age = agegp_for_yr) %>%
  ggplot(aes(x = yr, 
             y = rate, 
             colour = age, 
             group = age)) +
  geom_line(size = 0.5) +
  geom_errorbar(aes(ymin = lci, ymax = uci), width = 0.1) +
  scale_colour_manual(values = c("#28B8CE", "#FAC403", "seagreen")) +
  scale_y_continuous(expand = c(0, 0), limits = c(0, 40),
                     breaks = seq(0, 40, 10),
                     minor_breaks = seq(0, 40, 1)) +
  facet_grid( ~ factor(sex, levels = c("male", "female"), labels = c("Male", "Female"))) +
  labs(title = "Figue 4: Rate of mental health (MH) crisis events by sex \n and age group (2016-2020)",
       x = "Year",
       y = "Rate of MH crisis events per 1,000 PYAR",
       colour = "Age Group") +
  theme(# text = element_text(size = 14),
        axis.text.x = element_text(size = 8),
        plot.title.position = "plot",
        legend.position = "right",
        legend.justification = "left",
        legend.text = element_text(color = "#3c5888"),
        legend.title = element_text(color = "#3c5888"),
        axis.line = element_line(colour = "gray55"),
        axis.title = element_text(color = "#3c5888"),
        axis.text = element_text(color = "#3c5888"),
        plot.title = element_text(color = "#3c5888"),
        strip.text = element_text(color = "#3c5888"),
        panel.background = element_blank(),
        panel.grid.major.x = element_blank(),
        panel.grid.minor.x = element_blank(),
        panel.grid.major.y = element_line(colour = "gray55"),
        panel.grid.minor.y = element_blank())

print(line_age_sex_ppt)

jpeg("line_age_sex_ppt.jpg")
print(line_age_sex_ppt)
dev.off()

line_wimd_ppt <- df_all_service %>%
  filter(category == "wimd") %>%
  ggplot(aes(x = yr, 
             y = rate_1000pyar, 
             colour = factor(level, levels = c("wimd1", "wimd2", "wimd3", "wimd4", "wimd5")), 
             group = level)) +
  geom_line(size = 1) +
  geom_errorbar(aes(ymin = lci, ymax = uci), width = 0.1) +
  scale_colour_manual(values = c("#325083", "#28B8CE", "#FAC403", "#E03882", "limegreen"),
                      labels = c("1 (most)", "2", "3", "4", "5 (least)")) +
  scale_y_continuous(expand = c(0, 0), limits = c(0, 35),
                     breaks = seq(0, 35, 5),
                     minor_breaks = seq(0, 35, 1)) +
  labs(title = "Figure 5: Rate of mental health (MH) crisis events by \n deprivation quintile (2016-2020).",
       x = "Year",
       y = "Rate of MH crisis events per 1,000 PYAR",
       colour = "Deprivation quintile") +
  theme(# text = element_text(size = 14),
        plot.title.position = "plot",
        legend.position = "right",
        legend.justification = "left",
        legend.text = element_text(color = "#3c5888"),
        legend.title = element_text(color = "#3c5888"),
        axis.line = element_line(colour = "gray55"),
        axis.title = element_text(color = "#3c5888"),
        axis.text = element_text(color = "#3c5888"),
        plot.title = element_text(color = "#3c5888"),
        panel.background = element_blank(),
        panel.grid.major.x = element_blank(),
        panel.grid.minor.x = element_blank(),
        panel.grid.major.y = element_line(colour = "gray55"),
        panel.grid.minor.y = element_blank())

print(line_wimd_ppt)

jpeg("line_wimd_ppt.jpg")
print(line_wimd_ppt)
dev.off()

line_ruc_ppt <- df_all_service %>%
  filter(category == "ruc") %>%
  ggplot(aes(x = yr, 
             y = rate_1000pyar, 
             colour = factor(level, levels = c("urban", "rural")), 
             group = level)) +
  geom_line(size = 1) +
  geom_errorbar(aes(ymin = lci, ymax = uci), width = 0.1) +
  scale_colour_manual(values = c("#325083", "#28B8CE"),
                      labels = c("Urban", "Rural")) +
  scale_y_continuous(expand = c(0, 0), limits = c(0, 25),
                     breaks = seq(0, 25, 5)) +
  labs(title = "Figure 6: Rate of mental health (MH) crisis events by \n rurality (2016-2020).",
       x = "Year",
       y = "Rate of MH crisis events per 1,000 PYAR",
       colour = "Rurality") +
  theme(# text = element_text(size = 14),
        plot.title.position = "plot",
        legend.position = "right",
        legend.justification = "left",
        legend.text = element_text(color = "#3c5888"),
        legend.title = element_text(color = "#3c5888"),
        axis.line = element_line(colour = "gray55"),
        axis.title = element_text(color = "#3c5888"),
        axis.text = element_text(color = "#3c5888"),
        plot.title = element_text(color = "#3c5888"),
        panel.background = element_blank(),
        panel.grid.major.x = element_blank(),
        panel.grid.minor.x = element_blank(),
        panel.grid.major.y = element_line(colour = "gray55"),
        panel.grid.minor.y = element_blank())

print(line_ruc_ppt)

jpeg("line_ruc_ppt.jpg")
print(line_ruc_ppt)
dev.off()
