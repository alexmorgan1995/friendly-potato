library("deSolve"); library("ggplot2"); library("plotly"); library("reshape2")
library("bayestestR"); library("tmvtnorm"); library("ggpubr")

rm(list=ls())
setwd("C:/Users/amorg/Documents/PhD/Chapter_2/Chapter2_Fit_Data/FinalData/NewFit")

# Pairs Plot --------------------------------------------------------------

final_amp_post <- lapply(sapply(1:2, function(x) tail(grep(list.files(), pattern = c("gen_tet", "gen_broil")[x], value = TRUE),1)), read.csv)

MAP_list <- lapply(1:2, function(x) map_estimate(final_amp_post[[x]]))

plot_lower <- function(data, mapping){
  p <- ggplot(data = data, mapping = mapping) + scale_x_continuous(expand = c(0,0))  + scale_y_continuous(expand = c(0,0)) + 
    stat_density2d(aes(fill=..density..), geom="tile", contour = FALSE) +
    scale_fill_gradientn(colours=viridis::viridis(100))
  return(p)
}

plot_diag <- function(data, mapping){
  p <- ggplot(data = data, mapping = mapping) + scale_x_continuous(expand = c(0,0))  + 
    geom_density(fill = "grey", alpha = 0.3, size = 1.2) + theme_bw()
  return(p)
}

plot_tet <- GGally::ggpairs(final_amp_post[[1]], lower=list(continuous=plot_lower), diag = list(continuous = plot_diag)) + theme_bw()
plot_broil <- GGally::ggpairs(final_amp_post[[2]], lower=list(continuous=plot_lower), diag = list(continuous = plot_diag)) + theme_bw()
plot_amp <- GGally::ggpairs(final_amp_post[[3]], lower=list(continuous=plot_lower), diag = list(continuous = plot_diag)) + theme_bw()

ggsave(plot_tet, filename = "pairs_plot_tet.png", dpi = 300, type = "cairo", width = 8, height = 8, units = "in",
       path = "C:/Users/amorg/Documents/PhD/Chapter_2/Figures/Redraft_v1")

ggsave(plot_broil, filename = "pairs_plot_broil.png", dpi = 300, type = "cairo", width = 8, height = 8, units = "in",
       path = "C:/Users/amorg/Documents/PhD/Chapter_2/Figures/Redraft_v1")

ggsave(plot_amp, filename = "pairs_plot_amp.png", dpi = 300, type = "cairo", width = 8, height = 8, units = "in",
       path = "C:/Users/amorg/Documents/PhD/Chapter_2/Figures/Redraft_v1")

# Diagnostic Plots -------------------------------------------------------

tetRDS <- lapply(list.files(pattern = ".rds"), readRDS)

#Create a list of the RDSs

p_diag_list <- list()

for(i in 1:1) {
  p_diag_list <- local({
    pre_plist <- list()
    #Distances
    
    case_RDS <- tetRDS[[i]]
      
    dist_dat <- data.frame(dist = sapply(1:10, function(x) case_RDS[[x]][[1]]), "gen" = sapply(1:10, function(x) paste0("gen", x)))
    dist_dat$accept_perc <- (1000/dist_dat$dist)*100
    
    #Summary Statistics 
    
    sum_diag <- as.data.frame(cbind(t(sapply(1:10, function(x) colMeans(case_RDS[[x]][[2]]))/c(1,3.26,0.35)),
                                    t(sapply(1:10, function(x) apply(case_RDS[[x]][[2]], 2, min))/c(1,3.26,0.35)),
                                    t(sapply(1:10, function(x) apply(case_RDS[[x]][[2]], 2, max))/c(1,3.26,0.35))))
    
    colnames(sum_diag) <- c("mean_dist","mean_ICombH","mean_ResPropHum",
                            "low_dist","low_ICombH","low_ResPropHum",
                            "high_dist","high_ICombH","high_ResPropHum")
    sum_diag$gen <- seq(1,10)
    
    pre_plist[[1]] <- ggplot(sum_diag, aes(y = mean_dist, x = gen)) + 
      geom_ribbon(aes(ymin = low_dist, ymax = high_dist), inherit.aes = TRUE , alpha = 0.5) + geom_line(size = 1.2)+
      scale_x_continuous(expand = c(0,0), name = "Generation") + scale_y_continuous(expand = c(0,0), name = "Average Sum of Squared Distances") + 
      ggtitle(label = c("Tetracycline Usage in Fattening Pigs")[i])
    
    pre_plist[[2]] <-  ggplot(sum_diag, aes(y = mean_ICombH, x = gen)) + 
      geom_ribbon(aes(ymin = low_ICombH, ymax = high_ICombH), inherit.aes = TRUE , alpha = 0.5) + geom_line(size = 1.2)+
      scale_x_continuous(expand = c(0,0), name = "Generation") + scale_y_continuous(expand = c(0,0), name = "Distance from Target ICombH Value")
    
    pre_plist[[3]] <- ggplot(sum_diag, aes(y = mean_ResPropHum, x = gen)) + 
      geom_ribbon(aes(ymin = low_ResPropHum, ymax = high_ResPropHum), inherit.aes = TRUE , alpha = 0.5) + geom_line(size = 1.2) +
      scale_x_continuous(expand = c(0,0), name = "Generation") + scale_y_continuous(expand = c(0,0), name = "Distance from Target ResPropHum Value") 
    
    return(pre_plist)
  })
}

ggarrange(p_diag_list[[1]][[1]], p_diag_list[[2]][[1]], p_diag_list[[3]][[1]],
          p_diag_list[[1]][[2]], p_diag_list[[2]][[2]], p_diag_list[[3]][[2]],
          p_diag_list[[1]][[3]], p_diag_list[[2]][[3]], p_diag_list[[3]][[3]],
          ncol = 3, nrow = 3)
