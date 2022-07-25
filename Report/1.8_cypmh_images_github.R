knitr::opts_chunk$set(echo = TRUE)

## install.packages("magick")

library(magick)

# map
map <- image_read('ndl_map.png')

# risk ratios graph
risk <- image_read('RR2016_2020_slides.png')

# funnel plot
funnel <- image_read('funnel_plot.png')

# map
map_txt <- image_annotate(map, "NDL Wales is one of five national \n networked data labs funded by the \n Health Foundation.", size = 12, gravity = "south", color = "#3c5888")

# risk ratios
  # add space for text
risk_border <- image_border(risk, "white", "0x70")

  # Add text
risk_txt1 <- image_annotate(risk_border, "*adjusted for sex, age group, deprivation, rurality, health board, year and SMS history. \n Inset: SMS history has adjusted IRR of 9.89 so is not displayed on main plot due to \n scale. Reference groups: Sex: Male; Age group: 11-15; Deprivation: 5 (least deprived); \n Rurality: Rural; SMS history: No history.", size = 16, gravity = "southwest", color = "#3c5888")

risk_txt2 <- image_annotate(risk_txt1, "Figure 2: Incident rate ratio of mental health crisis events.", size = 24, gravity = "northwest", color = "#3c5888")

# funnel plot
  # add space for text
funnel_border <- image_border(funnel, "white", "0x280")

  # Add text
funnel_txt1 <- image_annotate(funnel_border, "Figure 1: Number of mental health crisis events by acute care service \n (2016-2020)", size = 60, gravity = "northwest", color = "#3c5888") 

funnel_txt2 <- image_annotate(funnel_txt1, "NB: Accessing healthcare services may not directly reflect MH need \n because of differences in help seeking behaviour and access to \n services. This should be considered when interpreting the data \n presented in this slide deck.", size = 60, gravity = "Southwest", color = "#3c5888")
  

# map
image_write(map_txt, path = "ndl_map_txt.png", format = "png")

# risk ratios
image_write(risk_txt2, path = "risk_txt.png", format = "png")

# funnel plot 
image_write(funnel_txt2, path = "funnel_txt.png", format = "png")
