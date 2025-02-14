library(ggplot2)
library(ggpubr)
library(here)
library(dplyr)
library(forcats)
library(gtable)
library(cowplot)
library(tidyr)
library(RColorBrewer)
library(reshape2)
library(ggnewscale)
library(stringr)


# build a named color palette for each condition
condition_palette <- c("#762983","#9a6faa","#c3a5d0","#acaaaf","#7ebd42","#4d9222","#26641a") 
names(condition_palette) <- c("OH", "OR", "OF", "NF", "ZF", "ZR", "ZH")

# build a named set of labels for each condition (just the temperatures)
condition_labels <- c("40°C","23°C","-80°C","-80°C","-80°C","23°C","40°C")
names(condition_labels) <- c("OH", "OR", "OF", "NF", "ZF", "ZR", "ZH")



##### METAGENOMIC ####
genus_sig <- read.csv(here("QSU_Data/sig_data_dna_full.tsv"), sep="\t", header=TRUE)
genus_sig <- genus_sig %>% mutate(PercentFormatted = as.numeric(gsub("%.*", "", percentchange)))
genus_sig <- genus_sig %>% mutate(PFormatted = as.numeric(ifelse(p == "< 0.001", "0.001", p)))
genus_sig <- genus_sig %>% filter(grepl(":", feature)) %>% filter(!grepl("Absolute ", feature)) %>% 
  filter(!grepl("Relative ", feature))
genus_sig <- genus_sig %>% mutate(feature = ifelse(feature == "Firmicutes: unclassified Firmicutes sensu stri...", "Firmicutes: Firmicutes s.s.", feature))


genus_sig <- genus_sig %>% mutate(Condition = group2)
genus_sig <- genus_sig %>% mutate(y.position = ifelse(Condition == "OF", 2, 
                                                      ifelse(Condition=="ZF", 1, 
                                                             ifelse(Condition=="OR", 4, 
                                                                    ifelse(Condition == "OH", 3, 
                                                                           ifelse(Condition == "ZR", 2, 1))))))

raw_abundance <- read.csv(here("QSU_Data/model_data_dna_full.csv"), header=TRUE)
raw_abundance <- raw_abundance %>% mutate(Condition=Sample_Type)
raw_abundance <- raw_abundance %>% filter(Condition == "NF") %>% select(feature, prediction)
names(raw_abundance) <- c("feature", "NFMean")
raw_abundance <- raw_abundance %>% filter(grepl(":", feature)) %>% filter(!grepl("Absolute ", feature)) %>% 
  filter(!grepl("Relative ", feature))
raw_abundance <- raw_abundance %>% mutate(feature = gsub("Firmicutes: unclassified Clostridiales.*", "Firmicutes: unclassified Clostridiales (miscel...", feature))
raw_abundance <- raw_abundance %>% mutate(feature = gsub("Firmicutes: unclassified Firmicutes sensu.*", "Firmicutes: unclassified Firmicutes sensu stri...", feature))
raw_abundance <- raw_abundance %>% mutate(feature = ifelse(feature == "Firmicutes: unclassified Firmicutes sensu stri...", "Firmicutes: Firmicutes s.s.", feature))
raw_abundance <- raw_abundance %>% mutate(Phylum = gsub(":.*", "", feature))
raw_abundance <- raw_abundance %>% 
  group_by(Phylum) %>% 
  arrange(Phylum, desc(NFMean))
raw_abundance$x.position <- as.numeric(row.names(raw_abundance))


genus_sig <- merge(genus_sig, raw_abundance, by="feature", all.x = TRUE)
genus_sig <- genus_sig %>% mutate(Phylum = gsub(":.*", "", feature))
genus_sig <- genus_sig %>% mutate(Phylum = ifelse(Phylum == "null", "Virus", Phylum))
genus_sig <- genus_sig %>% mutate(Plabel = ifelse(PFormatted <= 0.05, "*", ""))
genus_sig <- genus_sig %>% mutate(GenusStrange = ifelse((str_count(feature, pattern=" ") > 1) & feature != "null: crAss-like viruses", "*", ""))
genus_sig <- genus_sig %>% mutate(Genus = gsub(" sensu.*", "", gsub("unclassified ", "", gsub(".*: ", "", gsub(" \\(misc.*", "", gsub(": environmental.*", "", feature))))))
genus_sig <- genus_sig %>% mutate(Genus = paste(Genus, GenusStrange, sep=""))

preservative <- ggplot(genus_sig %>% filter(Condition == "OF" | Condition == "ZF"), aes(x=x.position, y=y.position, fill=PercentFormatted)) + 
  geom_tile() + 
  coord_fixed() + 
  scale_x_continuous(expand = c(0,0)) + 
  scale_y_continuous(expand = c(0,0), breaks=c(1, 2), labels=c("Zymo -80°C", "OMNI -80°C")) + 
  labs(title = "Preservative Effect (Relative to no preservative)") +
  theme_bw() + theme(axis.ticks = element_blank(), axis.title = element_blank(), axis.text.x = element_blank(), 
                     title = element_text(size=8), plot.margin = unit(c(0,0,0,0), "cm")) +
  scale_fill_gradientn(colours = c("blue", "white", "red"), limits=c(-81, 81)) +
  labs(fill="Percent\nEnrichment")+
  geom_point(data = genus_sig %>% filter(Condition == "OF" | Condition == "ZF") %>% filter(Plabel == "*"), size=1, color="white") + 
  geom_vline(xintercept=3.5) + 
  geom_vline(xintercept=8.5) + 
  geom_hline(yintercept=1.5) +
  theme(panel.border = element_rect(size=1))

preservative

z <- get_legend(preservative)

temperature <- ggplot(genus_sig %>% filter(Condition != "OF" & Condition != "ZF"), aes(x=x.position, y=y.position, fill=PercentFormatted)) + 
  geom_tile() + 
  coord_fixed() + 
  scale_x_continuous(expand = c(0,0), breaks=genus_sig$x.position, labels=genus_sig$Genus) + 
  scale_y_continuous(expand = c(0,0), breaks=c(1,2, 3, 4), labels=c("Zymo 40°C", "Zymo 23°C", "OMNI 40°C", "OMNI 23°C")) + 
  labs(title = "Temperature Effect (Relative to -80°C for each preservative)") +
  theme_bw() + theme(axis.ticks = element_blank(), axis.title = element_blank(),
                     title = element_text(size=8), plot.margin = unit(c(0,0,0,0), "cm")) +
  scale_fill_gradientn(colours = c("blue", "white", "red"), limits=c(-81, 81)) +
  geom_point(data = genus_sig %>% filter(Condition != "OF" & Condition !="ZF") %>% filter(Plabel == "*"), size=1, color="white") +
  theme(axis.text.x = element_text(angle=45, hjust=1, vjust=1))+ 
  geom_vline(xintercept=3.5) + 
  geom_vline(xintercept=8.5) + 
  geom_hline(yintercept=2.5) +
  theme(panel.border = element_rect(size=1))


temperature

raw_abund <- ggplot(genus_sig %>% filter(Condition == "ZF"), aes(x=x.position, y=y.position, fill=NFMean*100)) + 
  geom_tile() + 
  coord_fixed() + 
  scale_x_continuous(expand = c(0,0)) + 
  scale_y_continuous(expand = c(0,0), breaks=c(1), labels=c("Abundance")) + 
  theme_bw() + theme(axis.ticks = element_blank(), axis.title = element_blank(), axis.text.x = element_blank(), 
                     title = element_text(size=8), plot.margin = unit(c(0,0,0,0), "cm")) +
  scale_fill_gradientn(colours = c("#F3F3F3", "black")) +
  labs(fill="Baseline %\nAbundance")+ 
  geom_vline(xintercept=3.5) + 
  geom_vline(xintercept=8.5) + 
  theme(panel.border = element_rect(size=1))
raw_abund

z2 <- get_legend(raw_abund)


main_andabund <- plot_grid(raw_abund + theme(legend.position="none"), 
                           preservative + theme(legend.position="none"), 
                           temperature + theme(legend.position="none"), 
                           nrow=3, ncol=1, align="v", axis="lr", rel_heights=c(1,3,8))

main_andabund # works well at 11.5 x 3

legend_plot <- plot_grid(z2, z, ncol=1, nrow=2, align = "v")
legend_plot

plot_grid(main_andabund, legend_plot, nrow=1, ncol=2, rel_widths=c(1, 0.1)) # seems to work well at 12x3
ggsave(here("QSU_Data/Figure3_heatmap_raw.pdf"), dpi=300, w=12, h=4)
ggsave(here("QSU_Data/Figure3_heatmap_raw.jpeg"), dpi=300, w=12, h=4)



##### METATRANSCIRPTOMIC #####

genus_sig <- read.csv(here("QSU_Data/sig_data_rna_full.tsv"), sep="\t", header=TRUE)
genus_sig <- genus_sig %>% mutate(PercentFormatted = as.numeric(gsub("%.*", "", percentchange)))
genus_sig <- genus_sig %>% mutate(PFormatted = as.numeric(ifelse(p == "< 0.001", "0.001", p)))
genus_sig <- genus_sig %>% filter(grepl(":", feature)) %>% filter(!grepl("Absolute ", feature)) %>% 
  filter(!grepl("Relative ", feature))
genus_sig <- genus_sig %>% mutate(feature = ifelse(feature == "Firmicutes: unclassified Firmicutes sensu stri...", "Firmicutes: Firmicutes s.s.", feature))


genus_sig <- genus_sig %>% mutate(Condition = group2)
genus_sig <- genus_sig %>% mutate(y.position = ifelse(Condition == "OF", 2, 
                                                      ifelse(Condition=="ZF", 1, 
                                                             ifelse(Condition=="OR", 3, 
                                                                           ifelse(Condition == "ZR", 2, 1)))))

raw_abundance <- read.csv(here("QSU_Data/model_data_rna_full.csv"), header=TRUE)
raw_abundance <- raw_abundance %>% mutate(Condition=Sample_Type)
raw_abundance <- raw_abundance %>% filter(Condition == "NF") %>% select(feature, prediction)
names(raw_abundance) <- c("feature", "NFMean")
raw_abundance <- raw_abundance %>% filter(grepl(":", feature)) %>% filter(!grepl("Absolute ", feature)) %>% 
  filter(!grepl("Relative ", feature))
raw_abundance <- raw_abundance %>% mutate(feature = gsub("Firmicutes: unclassified Clostridiales.*", "Firmicutes: unclassified Clostridiales (miscel...", feature))
raw_abundance <- raw_abundance %>% mutate(feature = gsub("Firmicutes: unclassified Firmicutes sensu.*", "Firmicutes: unclassified Firmicutes sensu stri...", feature))
raw_abundance <- raw_abundance %>% mutate(feature = ifelse(feature == "Firmicutes: unclassified Firmicutes sensu stri...", "Firmicutes: Firmicutes s.s.", feature))
raw_abundance <- raw_abundance %>% mutate(Phylum = gsub(":.*", "", feature))
raw_abundance <- raw_abundance %>% 
  group_by(Phylum) %>% 
  arrange(Phylum, desc(NFMean))
raw_abundance$x.position <- as.numeric(row.names(raw_abundance))


genus_sig <- merge(genus_sig, raw_abundance, by="feature", all.x = TRUE)
genus_sig <- genus_sig %>% mutate(Phylum = gsub(":.*", "", feature))
genus_sig <- genus_sig %>% mutate(Phylum = ifelse(Phylum == "null", "Virus", Phylum))
genus_sig <- genus_sig %>% mutate(Plabel = ifelse(PFormatted <= 0.05, "*", ""))
genus_sig <- genus_sig %>% mutate(GenusStrange = ifelse((str_count(feature, pattern=" ") > 1) & feature != "null: crAss-like viruses", "*", ""))
genus_sig <- genus_sig %>% mutate(Genus = gsub(" sensu.*", "", gsub("unclassified ", "", gsub(".*: ", "", gsub(" \\(misc.*", "", gsub(": environmental.*", "", feature))))))
genus_sig <- genus_sig %>% mutate(Genus = paste(Genus, GenusStrange, sep=""))
genus_sig <- genus_sig %>% mutate(PercentFormatted2 = ifelse(PercentFormatted > 100, 100, PercentFormatted))

preservative <- ggplot(genus_sig %>% filter(Condition == "OF" | Condition == "ZF"), aes(x=x.position, y=y.position, fill=PercentFormatted2)) + 
  geom_tile() + 
  coord_fixed() + 
  scale_x_continuous(expand = c(0,0)) + 
  scale_y_continuous(expand = c(0,0), breaks=c(1, 2), labels=c("Zymo -80°C", "OMNI -80°C")) + 
  labs(title = "Preservative Effect (Relative to no preservative)") +
  theme_bw() + theme(axis.ticks = element_blank(), axis.title = element_blank(), axis.text.x = element_blank(), 
                     title = element_text(size=8), plot.margin = unit(c(0,0,0,0), "cm")) +
  scale_fill_gradientn(colours = c("blue", "white", "red"), limits=c(-100, 100)) +
  labs(fill="Percent\nEnrichment")+
  geom_point(data = genus_sig %>% filter(Condition == "OF" | Condition == "ZF") %>% filter(Plabel == "*"), size=1, color="white") + 
  theme(panel.border = element_rect(size=1)) + 
  geom_vline(xintercept=6.5) +
  geom_vline(xintercept=12.5) +
  geom_vline(xintercept=13.5) +
  geom_vline(xintercept=41.5) +
  geom_vline(xintercept=43.5) +
  geom_hline(yintercept=1.5) 
preservative

z <- get_legend(preservative)

temperature <- ggplot(genus_sig %>% filter(Condition == "OR" | Condition == "ZH" | Condition == "ZR"), aes(x=x.position, y=y.position, fill=PercentFormatted2)) + 
  geom_tile() + 
  coord_fixed() + 
  scale_x_continuous(expand = c(0,0), breaks=genus_sig$x.position, labels=genus_sig$Genus) + 
  scale_y_continuous(expand = c(0,0), breaks=c(1,2,3), labels=c("Zymo 40°C", "Zymo 23°C", "OMNI 23°C")) + 
  labs(title = "Temperature Effect (Relative to -80°C for each preservative)") +
  theme_bw() + theme(axis.ticks = element_blank(), axis.title = element_blank(),
                     title = element_text(size=8), plot.margin = unit(c(0,0,0,0), "cm")) +
  scale_fill_gradientn(colours = c("blue", "white", "red"), limits=c(-100, 100)) +
  geom_point(data = genus_sig %>% filter(Condition == "OR" | Condition == "ZH" | Condition == "ZR") %>% filter(Plabel == "*"), size=1, color="white") +
  theme(axis.text.x = element_text(angle=45, hjust=1, vjust=1))+ 
  geom_vline(xintercept=6.5) +
  geom_vline(xintercept=12.5) +
  geom_vline(xintercept=13.5) +
  geom_vline(xintercept=41.5) +
  geom_vline(xintercept=43.5) +
  geom_hline(yintercept=2.5) +
  theme(panel.border = element_rect(size=1))
temperature

raw_abund <- ggplot(genus_sig %>% filter(Condition == "ZF"), aes(x=x.position, y=y.position, fill=NFMean*100)) + 
  geom_tile() + 
  coord_fixed() + 
  scale_x_continuous(expand = c(0,0)) + 
  scale_y_continuous(expand = c(0,0), breaks=c(1), labels=c("Abundance")) + 
  theme_bw() + theme(axis.ticks = element_blank(), axis.title = element_blank(), axis.text.x = element_blank(), 
                     title = element_text(size=8), plot.margin = unit(c(0,0,0,0), "cm")) +
  scale_fill_gradientn(colours = c("#F3F3F3", "black")) +
  labs(fill="Baseline %\nAbundance")+ 
  geom_vline(xintercept=6.5) +
  geom_vline(xintercept=12.5) +
  geom_vline(xintercept=13.5) +
  geom_vline(xintercept=41.5) +
  geom_vline(xintercept=43.5) +
  theme(panel.border = element_rect(size=1))
raw_abund

z2 <- get_legend(raw_abund)


main <- plot_grid(raw_abund + theme(legend.position ="none"),  
                  preservative + theme(legend.position = "none"), 
                  temperature + theme(legend.position = "none"), 
                  ncol=1, nrow=3, rel_widths = c(1,1,1,1), rel_heights = c(1, 3, 6),
                  align="v", axis="l")
main

legend_plot <- plot_grid(z2, z, ncol=1, nrow=2, align = "v")
legend_plot

plot_grid(main, legend_plot, nrow=1, ncol=2, rel_widths=c(1, 0.1)) # seems to work well at 12x3


ggsave(here("QSU_Data/Fig4_Heatmap_raw.pdf"), dpi=300, w=12, h=3.5)
ggsave(here("QSU_Data/Fig4_Heatmap_raw.jpeg"), dpi=300, w=12, h=3.5)

