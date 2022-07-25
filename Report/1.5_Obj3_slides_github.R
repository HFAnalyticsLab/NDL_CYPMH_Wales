knitr::opts_chunk$set(echo = TRUE)

## install.packages("patchwork")
## install.packages("png")

library(tidyverse)
library(knitr)
library(patchwork)
library(png)

RR2016_2020 <- read.csv('.Data/DF_data/SAIL exports/Current obj3 newAgeGp/Obj3Table_2016_2020.csv')

#RR Graph
eventsRR2016_2020plot_bubbles <- RR2016_2020 %>%
  filter(variable != '(Intercept)',
         variable != 'SMS history',
         variable !=  'Health board',
         variable != "Year",
         !grepl('\\*', category)) %>%
  mutate(variable = if_else(variable == 'Urban/rural', 'Rurality', variable),
         variable = if_else(variable == 'WIMD', 'Deprivation Quintile', variable),
         adjsig = if_else(p_adj < 0.05, '<0.05', '>=0.05'),
         category = if_else(category == '1', '1 (most)', category),
         category = if_else(category == '5', '5 (least)', category)) %>% 
  ggplot() +
    geom_point(aes(x = category, y = RR_adj,
               size = cut(ratePer1000, c(10, 15, 20, 25, 30)),
                ),
               color = "#3c5888"
               ) +
  scale_size_manual(name = 'Crude rate \n per 1000',
                     values = c("(10,15]" = 2,
                                "(15,20]" = 3,
                                "(20,25]" = 4,
                                "(25,30]" = 5),
                    labels = c('10 to <15', '15 to <20', '20 to <25', '25 to <30')) +
  geom_hline(yintercept = 1, lty = 2) +
  xlab('Variable') +
  ylab('Adjusted* IRR') +
  facet_grid( ~ factor(variable, levels = c("Sex", "Age group", "Deprivation Quintile", "Rurality")),
              switch = "both", scales = "free_x", space = "free_x") +
  theme(panel.spacing = unit(0, "lines"),
        strip.placement = "outside",
        strip.text = element_text(color = "#3c5888"),
        legend.position = "right",
        text = element_text(size=20),
        legend.text = element_text(color = "#3c5888"),
        legend.title = element_text(color = "#3c5888"),
        axis.title = element_text(color = "#3c5888"),
        axis.text = element_text(color = "#3c5888"),
        plot.title = element_text(color = "#3c5888"),
        axis.line = element_line(colour = "gray55"),
        axis.text.x = element_text(angle = 90, vjust = .5, hjust = 1),
        panel.background = element_blank(),
        panel.grid.major.x = element_blank(),
        panel.grid.minor.x = element_blank(),
        panel.grid.major.y = element_line(colour = "gray55"),
        panel.grid.minor.y = element_line(colour = "gray90"))


png('eventsRR2016_2020plot_bubbles_slides.png', width = 600)
eventsRR2016_2020plot_bubbles
dev.off()

#RR Graph
RR2016_2020 %>%
  filter(variable != '(Intercept)',
         variable != "Year",
         !grepl('\\*', category),
         variable != 'Health board') %>%
  mutate(variable = if_else(variable == 'Urban/rural', 'Rurality', if_else(variable == 'SMS history', 'SMS', variable)),
         variable = if_else(variable == 'WIMD', 'Deprivation Quintile', variable),
         adjsig = if_else(p_adj < 0.05, '<0.05', '>=0.05')) %>% 
  ggplot() +
    geom_point(aes(x = category, y = RR_adj,
               size = cut(ratePer1000, c(10, 15, 20, 25, 30, 222)),
                ),
               color = "#3c5888"
               ) +
  scale_size_manual(name = 'Crude rate \n per 1000',
                     values = c("(10,15]" = 2,
                                "(15,20]" = 3,
                                "(20,25]" = 4,
                                "(25,30]" = 5,
                                "(30,222]" = 8),
                    labels = c('10 to <15', '15 to <20', '20 to <25', '25 to <30', '221')) +
  geom_hline(yintercept = 1, linetype = 1, size = 1) +
  xlab('') +
  ylab('') +
  facet_grid( ~ factor(variable, levels = c("Sex", "Age group", "Deprivation Quintile", "Rurality", "SMS")),
              switch = "both", scales = "free_x", space = "free_x") +
  theme(panel.spacing = unit(0, "lines"),
        text = element_text(size=20),
        strip.placement = "outside",
        strip.text = element_text(color = "#3c5888"),
        legend.position = "none",
        axis.line = element_line(colour = "gray55"),
        legend.text = element_text(color = "#3c5888"),
        legend.title = element_text(color = "#3c5888"),
        axis.title = element_text(color = "#3c5888"),
        axis.text = element_text(color = "#3c5888"),
        plot.title = element_text(color = "#3c5888"),
        strip.background = element_blank(),
        strip.text.x = element_blank(),
        axis.text.x = element_blank(),
        axis.text.y = element_blank(),
        panel.background = element_rect(fill = "transparent"), # bg of the panel
    plot.background = element_rect(fill = 'gray88'), # bg of the plot
    panel.grid.major = element_blank(), # get rid of major grid
    panel.grid.minor = element_blank(), # get rid of minor grid
    legend.background = element_rect(fill = "transparent"), # get rid of legend bg
    legend.box.background = element_rect(fill = "transparent") # get rid of legend panel bg
   # panel.border = element_rect(linetype = "solid", colour = "black", size=1)
        ) -> eventsRR2016_2020plot_sms


png('eventsRR2016_2020plot_sms_slides.png', height = 350, width = 600, bg= 'transparent')
eventsRR2016_2020plot_sms
dev.off()


#add little image into main ggplot
#https://statisticsglobe.com/add-image-to-plot-in-r
sms_img <- readPNG('eventsRR2016_2020plot_sms_slides.png', native = TRUE)

RR2016_2020_slides <- eventsRR2016_2020plot_bubbles +
  inset_element(p  = sms_img,
                left = 0.55,
                bottom = 0.55,
                right = 1,
                top = 1)

png('RR2016_2020_slides.png', height = 350, width = 600)
RR2016_2020_slides
dev.off()
