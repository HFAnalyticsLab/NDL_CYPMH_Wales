knitr::opts_chunk$set(echo = TRUE)

## install.packages("plotly")
## install.packages("DiagrammeR")
## webshot::install_phantomjs()
## install.packages("callr")
## install.packages("DiagrammeRsvg")
## install.packages("rsvg")
## install.packages("curl")

library(plotly)
library(dplyr)
library(DiagrammeR)
library(reshape2)
library(tidyr)
library(png)
library(DiagrammeRsvg)
library(rsvg)

raw_services <- read.csv(".Data/DF_data/SAIL exports/Current obj2 (all services) newAgeGp/mh_presentations_by_service.csv")

# select, rename, pivot
df_services <- raw_services %>%
  select(-X) %>%
  rename(service = SERVICE) %>%
  pivot_wider(names_from = service,
              values_from = n)

funnel_plot <- grViz("digraph {
  
graph[layout = dot, rankdir = TB]

# Define nodes
node[fontsize=40, fontcolor = '#3c5888', color = '#3c5888']

amb [label = '@@1']
ae [label = '@@2']
admis [label = '@@3']
total [label = '@@4']
linked [label = '@@5']

# edge definitions with node IDs
{amb ae admis} -> total -> linked

} 

# add n from data
[1]: paste0('Ambulance Attendances \\n (n =', df_services$WAST %>% comma(), ')')
[2]: paste0('A&E \\n (n = ', df_services$ED %>% comma(), ')')
[3]: paste0('Emergency Admissions \\n (n =', df_services$PEDW %>% comma(), ')')
[4]: paste0('Total MH crisis presentations \\n (n =', rowSums(df_services) %>% comma(),')')
[5]: paste0('Linked events across services \\n (n =', df_all_service %>% filter(category == 'overall') %>% select(events) %>% sum() %>% comma(),')')
")

funnel_plot %>%
    export_svg %>% charToRaw %>% rsvg %>% png::writePNG("funnel_plot.png")
