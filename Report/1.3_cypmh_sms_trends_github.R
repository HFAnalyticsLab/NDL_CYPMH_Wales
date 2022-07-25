knitr::opts_chunk$set(echo = TRUE)

## install.packages("dplyr")
## install.packages("ggplot2")
## install.packages("knitr")
## install.packages("cowplot")
## install.packages("gridExtra")
## install.packages("gtable")

library(dplyr)
library(ggplot2)
library(knitr)
library(cowplot)
library(gridExtra)
library(gtable)

raw_sms <- read.csv(".Data/DF_data/SAIL exports/Current obj2 (all services) newAgeGp/events_sms_yr.csv")

raw_sms_sex <- read.csv(".Data/DF_data/SAIL exports/Current obj2 (all services) newAgeGp/events_sms_gndr.csv")

raw_sms_age <- read.csv(".Data/DF_data/SAIL exports/Current obj2 (all services) newAgeGp/events_sms_age.csv")

raw_sms_wimd <- read.csv(".Data/DF_data/SAIL exports/Current obj2 (all services) newAgeGp/events_sms_wimd.csv")

raw_sms_ruc <- read.csv(".Data/DF_data/SAIL exports/Current obj2 (all services) newAgeGp/events_sms_urbrur.csv")

raw_sms_hb <- read.csv(".Data/DF_data/SAIL exports/Current obj2 (all services) newAgeGp/events_sms_hb.csv")

df_sms_overall <- raw_sms %>%
  select(-X) %>%
  mutate(category = "overall",
         level = "overall")

df_sms_sex <- raw_sms_sex %>%
  select(-X) %>%
  rename(level = gndr_cd) %>%
  mutate(category = "sex")

df_sms_age <- raw_sms_age %>%
  select(-X) %>%
  rename(level = agegp_for_yr) %>%
  mutate(category = "age")

df_sms_wimd <- raw_sms_wimd %>%
  select(-X) %>%
  rename(level = wimd_quintile) %>%
  mutate(category = "wimd")

df_sms_ruc <- raw_sms_ruc %>%
  select(-X) %>%
  rename(level = urb_rur) %>%
  mutate(category = "ruc")

df_sms_hb <- raw_sms_hb %>%
  select(-X) %>%
  rename(level = hb_name) %>%
  mutate(category = "hb")

df_sms <- df_sms_overall %>%
  merge(df_sms_sex, all = TRUE) %>% 
  merge(df_sms_age, all = TRUE) %>% 
  merge(df_sms_wimd, all = TRUE) %>% 
  merge(df_sms_ruc, all = TRUE) %>% 
  merge(df_sms_hb, all = TRUE) %>%
  select(yr, category, level, everything(), -RR)

df_sms_yes <- df_sms %>%
  select(-cases_nosms, -pyears_nosms, -rate_nosms) %>%
  mutate(sms = "sms") %>%
  rename(events = cases_sms, pyar = pyears_sms, rate = rate_sms)

df_sms_no <- df_sms %>%
  select(-cases_sms, -pyears_sms, -rate_sms) %>%
  mutate(sms = "no_sms") %>%
  rename(events = cases_nosms, pyar = pyears_nosms, rate = rate_nosms)

df_sms_long <- df_sms_yes %>%
  merge(df_sms_no, all = TRUE) %>%
  select(yr, sms, everything()) %>%
  rowwise() %>%
  mutate(lci = poisson.test(events, pyar) [[4]] [1] * 1000,
         uci = poisson.test(events, pyar) [[4]] [2] * 1000)

saveRDS(df_sms_long, "df_sms_long.Rdata")

line_sms_overall_sex_ppt <- df_sms_long %>%
  filter(category == "overall" | category == "sex") %>%
  ggplot(aes(x = yr, 
             y = rate, 
             colour = factor(level, levels = c("overall", "male", "female")), 
             linetype = factor(sms, levels = c("sms", "no_sms")))) +
  geom_line(size = 0.5) +
  geom_errorbar(aes(ymin = lci, ymax = uci), width = 0.1) +
  scale_colour_manual(values = c("#325083", "#E03882", "#4FBAAB"), 
                      labels = c("Total", "Male", "Female")) +
  scale_linetype_manual(values = c("dashed", "solid"), 
                        labels = c("SMS history", "No SMS history")) +
  scale_y_continuous(expand = c(0, 0), limits = c(0, 450),
                     breaks = seq(0, 450, 50)) +
  labs(title = "Figure 7: Rate of mental health (MH) crisis events by \n substance misuse services history and sex.",
       x = "Year",
       y = "Rate of MH crisis events per 1,000 PYAR",
       colour = "",
       linetype = "SMS") +
  theme(plot.title.position = "plot",
        axis.line = element_line(colour = "gray55"),
        legend.position = "right",
        legend.text = element_text(color = "#3c5888"),
        legend.title = element_text(color = "#3c5888"),
        axis.title = element_text(color = "#3c5888"),
        axis.text = element_text(color = "#3c5888"),
        plot.title = element_text(color = "#3c5888"),
        panel.background = element_blank(),
        panel.grid.major.x = element_blank(),
        panel.grid.minor.x = element_blank(),
        panel.grid.major.y = element_line(colour = "gray55"),
        panel.grid.minor.y = element_blank())

print(line_sms_overall_sex_ppt)

jpeg("line_sms_overall_sex_ppt.jpg")
print(line_sms_overall_sex_ppt)
dev.off()
