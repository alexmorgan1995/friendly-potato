library("deSolve"); library("ggplot2"); library("reshape2")
library("bayestestR"); library("tmvtnorm"); library("ggpubr"); library("sensitivity"); library("metR"); 
library("grid"); library("gridExtra"); library("rootSolve"); library("fast"); library("cowplot")

rm(list=ls())
setwd("C:/Users/amorg/Documents/PhD/Chapter_2/Models/Github/Chapter-2/NewFits_041021/data/new/full")

# Model Functions ----------------------------------------------------------

#Model ODEs
amr <- function(t, y, parms) {
  with(as.list(c(y, parms)), {
    dSa = ua + ra*(Isa + Ira) + kappa*tau*Isa - (betaAA*Isa*Sa) - (betaAH*Ish*Sa) - (1-alpha)*(betaAH*Irh*Sa) - (1-alpha)*(betaAA*Ira*Sa) - ua*Sa -
      (0.5*zeta)*Sa*(1-alpha) - (0.5*zeta)*Sa 
    dIsa = betaAA*Isa*Sa + betaAH*Ish*Sa + phi*Ira - kappa*tau*Isa - tau*Isa - ra*Isa - ua*Isa + (0.5*zeta)*Sa
    dIra = (1-alpha)*betaAH*Irh*Sa + (1-alpha)*betaAA*Ira*Sa + tau*Isa - phi*Ira - ra*Ira - ua*Ira + (0.5*zeta)*Sa*(1-alpha)
    
    dSh = uh + rh*(Ish+Irh) - (betaHH*Ish*Sh) - (1-alpha)*(betaHH*Irh*Sh) - (betaHA*Isa*Sh) - (1-alpha)*(betaHA*Ira*Sh) - uh*Sh 
    dIsh = betaHH*Ish*Sh + betaHA*Isa*Sh - rh*Ish - uh*Ish 
    dIrh = (1-alpha)*(betaHH*Irh*Sh) + (1-alpha)*(betaHA*Ira*Sh) - rh*Irh - uh*Irh 
    
    CumS = betaHH*Ish*Sh + betaHA*Isa*Sh
    CumR = (1-alpha)*(betaHH*Irh*Sh) + (1-alpha)*(betaHA*Ira*Sh)
    
    return(list(c(dSa,dIsa,dIra,dSh,dIsh,dIrh), CumS, CumR))
  })
}

#Importing in the Datasets
import <- function(id) {
  data <- data.frame(matrix(ncol = 6, nrow = 0))
  for(i in 1:length(grep(paste0("post_",id), list.files(), value = TRUE))) {
    test  <- cbind(read.csv(paste0("ABC_post_",substitute(id),"_",i,".csv"), 
                            header = TRUE), "group" = paste0("data",i), "fit" = as.character(substitute(id)))
    data <- rbind(data, test)
  }
  return(data)
}

# Identify the MAP for the Parameter Sets ---------------------------------
#Import of Posterior Distributions

data <- list(import("tetbroil"), import("ampbroil"), import("tetpigs"), import("amppigs"))
lapply(1:4, function(x) data[[x]]$group = factor(data[[x]]$group, levels = unique(data[[x]]$group)))

#Obtain the MAPs for each dataset

MAP <- rbind(c(colMeans(data[[1]][which(data[[1]]$group == tail(unique(data[[1]]$group),1)),][,1:6])),
             c(colMeans(data[[2]][which(data[[2]]$group == tail(unique(data[[2]]$group),1)),][,1:6])),
             c(colMeans(data[[3]][which(data[[3]]$group == tail(unique(data[[3]]$group),1)),][,1:6])),
             c(colMeans(data[[4]][which(data[[4]]$group == tail(unique(data[[4]]$group),1)),][,1:6])))

colnames(MAP) <- c("betaAA", "phi", "kappa", "alpha", "zeta", "betaHA")
rownames(MAP) <- c("ampbroil", "tetbroil","amppigs", "tetpigs")

sensparms <- c("betaAA" = mean(MAP[1:4]), 
               "phi" = mean(MAP[5:8]),
               "kappa" = mean(MAP[9:12]),
               "alpha" = mean(MAP[13:16]),
               "zeta" = mean(MAP[17:20]),
               "betaHA" = mean(MAP[21:24]),
               "tau" = mean(c(0.01305462,0.004913664,0.006861898, 0.0125423)))

mean_ua <- (42^-1 + 240^-1)/2

# Sensitivity Analysis ---------------------------------------------------
# Joint Parameters

#We do this for Tetracycline for the Parameter Bounds
#All other parameters will be included in the ranges

init <- c(Sa=0.98, Isa=0.01, Ira=0.01, Sh=1, Ish=0, Irh=0)

parms = fast_parameters(minimum = c(0, 55^-1, mean_ua/10, 288350^-1, 
                                    sensparms["betaAA"]/10, 0.000001, 0.000001, sensparms["betaHA"]/10, 
                                    sensparms["phi"]/10 , sensparms["kappa"]/10, 0, sensparms["tau"]/10, sensparms["zeta"]/10), 
                        maximum = c(6^-1, 0.55^-1, mean_ua*10, 2883.5^-1, 
                                    sensparms["betaAA"]*10, 0.0001, 0.0001, sensparms["betaHA"]*10, 
                                    sensparms["phi"]*10 , sensparms["kappa"]*10, 1, sensparms["tau"]*10, sensparms["zeta"]*10), 
                        factor=13, names = c("ra", "rh" ,"ua", "uh", 
                                           "betaAA", "betaAH", "betaHH", "betaHA",
                                             "phi", "kappa", "alpha", "tau", "zeta"))

# General Sensitivity Analysis - ICombH and ResRat -------------------------

output <- data.frame(matrix(ncol = 2, nrow = nrow(parms)))
colnames(output) <- c("IncH", "IResRat")

for (i in 1:nrow(parms)) {
  temp <- numeric(1)
  parms1 = c(ra = parms$ra[i], rh = parms$rh[i], ua = parms$ua[i], uh = parms$uh[i], betaAA = parms$betaAA[i],
             betaAH = parms$betaAH[i], betaHH = parms$betaHH[i], betaHA = parms$betaHA[i], phi=parms$phi[i],
             tau=parms$tau[i], kappa=parms$kappa[i], alpha = parms$alpha[i], zeta = parms$zeta[i])
  
  out <- runsteady(y = init, func = amr, times = c(0, Inf), parms = parms1)
  
  temp[1] <- ((out[[2]] + out[[3]])*(446000000))/100000
  temp[2] <- out[[1]][["Irh"]] / (out[[1]][["Ish"]] + out[[1]][["Irh"]])
  print(paste0("Progress: ",signif(i/nrow(parms))*100, digits = 3, "%"))
  output[i,] <- temp
}

output1 <- output
output1$IResRat[is.nan(output1$IResRat)] <- 0
output1 <- output1[!is.infinite(rowSums(output1)),]

#ICombH
sensit1 <- NULL; df.equilibrium <- NULL
sensit1 <- output1$IncH #Creating Variable for the output variable of interest
sens1 <- sensitivity(x=sensit1, numberf=13, make.plot=T, names = c("ra", "rh" ,"ua", "uh", "betaAA", "betaAH", "betaHH", "betaHA",
                                                                   "phi", "kappa", "alpha", "tau", "zeta"))

df.equilibrium <- data.frame(parameter=rbind("ra", "rh" ,"ua", "uh", "betaAA", "betaAH", "betaHH", "betaHA",
                                             "phi", "kappa", "alpha", "tau", "zeta"), value=sens1)

ggplot(df.equilibrium, aes(x = reorder(parameter, -value), y = value)) + geom_bar(stat="identity", fill="lightgrey", col = "black", width  = 0.8)

ICombH <- ggplot(df.equilibrium, aes(x = reorder(parameter, -value), y = value)) + geom_bar(stat="identity", fill="lightgrey", col = "black", width  = 0.8) + theme_bw() + 
  scale_y_continuous(limits = c(0,  max(df.equilibrium$value)*1.1), expand = c(0, 0), name = "Partial Variance") + 
  scale_x_discrete(expand = c(0, 0.7), name = "Parameter", 
                   labels = c(expression(beta[HA]), expression(alpha), expression(zeta), expression(tau),  expression(kappa), 
                              expression(phi), expression(beta[AA]), expression(r[A]), expression(beta[HH]),
                              expression(mu[A]), expression(r[H]), expression(mu[H]),   expression(beta[AH]))) +
  labs(fill = NULL, title = bquote(Sensitivity~Analysis~of~Daily~Incidence)) + 
  theme(legend.text=element_text(size=14), axis.text=element_text(size=14), plot.title = element_text(size = 15, vjust = 1.5, hjust = 0.5, face = "bold"),
        axis.title.y=element_text(size=14), axis.title.x= element_text(size=14), plot.margin = unit(c(0.4,0.4,0.4,0.55), "cm"))

#ResProp
sensit2 <- NULL; df.equilibrium1 <- NULL
sensit2 <- output1$IResRat #Creating Variable for the output variable of interest
sens2 <- sensitivity(x=sensit2, numberf=13, make.plot=T, names = c("ra", "rh" ,"ua", "uh", "betaAA", "betaAH", "betaHH", "betaHA",
                                                                   "phi", "kappa", "alpha", "tau", "zeta"))

df.equilibrium1 <- data.frame(parameter=rbind("ra", "rh" ,"ua", "uh", "betaAA", "betaAH", "betaHH", "betaHA",
                                              "phi", "kappa", "alpha", "tau", "zeta"), value=sens2)

ggplot(df.equilibrium1, aes(x = reorder(parameter, -value), y = value)) + geom_bar(stat="identity", fill="lightgrey", col = "black", width  = 0.8)

resprop <- ggplot(df.equilibrium1, aes(x = reorder(parameter, -value), y = value)) + geom_bar(stat="identity", fill="lightgrey", col = "black", width  = 0.8) + theme_bw() + 
  scale_y_continuous(limits = c(0,  max(df.equilibrium1$value)*1.1), expand = c(0, 0), name = "Partial Variance") + 
  scale_x_discrete(expand = c(0, 0.7), name = "Parameter", 
                   labels = c(expression(alpha), expression(tau), expression(phi), expression(kappa), expression(r[A]),  expression(mu[A]), expression(mu[H]),
                              expression(beta[AA]), expression(beta[AH]),expression(zeta), 
                              expression(r[H]), expression(beta[HA]), expression(beta[HH]))) +
  labs(fill = NULL, title = bquote(Sensitivity~Analysis~of~"I*"["RHProp"])) + 
  theme(legend.text=element_text(size=14), axis.text=element_text(size=14), plot.title = element_text(size = 15, vjust = 1.5, hjust = 0.5, face = "bold"),
        axis.title.y=element_text(size=14), axis.title.x= element_text(size=14), plot.margin = unit(c(0.4,0.4,0.4,0.55), "cm"))

sensplot <- ggarrange(ICombH, resprop, nrow = 2, ncol = 1, align = "v", labels = c("A","B"), font.label = c(size = 20)) 

ggsave(sensplot, filename = "Sensitivity_ICombH_ResRat.png", dpi = 300, type = "cairo", width = 7, height = 8, units = "in",
       path = "C:/Users/amorg/Documents/PhD/Chapter_2/Models/Github/Chapter-2/NewFits_041021/figures")

# What Parameters Cause the Largest Relative Increase? --------------------

parms = fast_parameters(minimum = c(0, 55^-1, mean_ua/10, 288350^-1, 
                                    sensparms["betaAA"]/10, 0.000001, 0.000001, sensparms["betaHA"]/10, 
                                    sensparms["phi"]/10 , sensparms["kappa"]/10, 0,  sensparms["zeta"]/10), 
                        maximum = c(6^-1, 0.55^-1, mean_ua*10, 2883.5^-1, 
                                    sensparms["betaAA"]*10, 0.0001, 0.0001, sensparms["betaHA"]*10, 
                                    sensparms["phi"]*10 , sensparms["kappa"]*10, 1, sensparms["zeta"]*10), 
                        factor=12, names = c("ra", "rh" ,"ua", "uh", 
                                             "betaAA", "betaAH", "betaHH", "betaHA",
                                             "phi", "kappa", "alpha", "zeta"))



tauoutput <- data.frame(matrix(nrow = 0, ncol = 3))
tau_range <- c(0, sensparms[["tau"]]) # Comparing Baseline Average with Curtailment

for (j in 1:nrow(parms)) {
  temp <- numeric(2)
  for (i in 1:length(tau_range)) {
    parms2 = c(ra = parms$ra[j], rh = parms$rh[j], ua = parms$ua[j], uh = parms$uh[j], betaAA = parms$betaAA[j],
               betaAH = parms$betaAH[j], betaHH = parms$betaHH[j], betaHA = parms$betaHA[j], phi=parms$phi[j],
               kappa=parms$kappa[j], alpha = parms$alpha[j], tau = tau_range[i], zeta = parms$zeta[j])
    
    out <- runsteady(y = init, func = amr, times = c(0,Inf), parms = parms2)
    temp[i] <- ((out[[2]] + out[[3]])*(446000000))/100000
  }
  tauoutput <- rbind(tauoutput, c(temp[1], temp[2], abs(temp[1] - temp[2]), parms2[parms2 != "tau"] ))
  print(j/nrow(parms))
}

colnames(tauoutput) <- c("curt", "usage", "diff", names(parms2)) 


#Running the FAST Sensitivity Analysis
tauoutput1 <- tauoutput 

tauoutput1$inc <- ((tauoutput1$curt / tauoutput1$usage) - 1)* 100 # % Change from the current usage scenario

tauoutput1$inc[is.nan(tauoutput1$inc)] <- 0; neg <- tauoutput1[tauoutput1$inc < 0,] 
tauanalysis <- tauoutput1$inc[!is.infinite(tauoutput1$inc)]
tauanalysis <- tauanalysis[tauanalysis < quantile(tauanalysis, 0.99)]
#This step changes all NA input to 0 and removes infinities
#removes all negative changes - might need to review
#The tail of the distribution has also been trimmed to prevent massive artificial increases from showing up

#We then view the Distribution of Increases Above Baseline
sensparms[["tau"]]
hist(tauanalysis, xlab = bquote("% Increase above Baseline Incidence (Tau = 0.00934)"), breaks = 50)

# What Parameters Can Compensate? ------------------------------------------

tauoutput <- data.frame(matrix(nrow = 0, ncol = 3))

for (j in 1:nrow(parms)) {
  parms2 = c(ra = parms$ra[j], rh = parms$rh[j], ua = parms$ua[j], uh = parms$uh[j], betaAA = parms$betaAA[j],
             betaAH = parms$betaAH[j], betaHH = parms$betaHH[j], betaHA = parms$betaHA[j], phi=parms$phi[j],
             kappa=parms$kappa[j], alpha = parms$alpha[j], tau = 0, zeta = parms$zeta[j])
  out <- runsteady(y = init, func = amr, times = c(0, Inf), parms = parms2)
  temp <- ((out[[2]] + out[[3]])*(446000000))/100000
  tauoutput <- rbind(tauoutput, c(temp ,abs(temp - 0.593)))
  print(j/nrow(parms))
}

colnames(tauoutput) <- c("IComb0","diff") 

tauoutput1 <- tauoutput 

tauoutput1$inc <- ((tauoutput1$IComb0 / 0.593) - 1)* 100 # % Increase from the current usage scenario
tauoutput1$inc[is.nan(tauoutput1$inc)] <- 0; neg <- tauoutput1[tauoutput1$inc < 0,] 
tauanalysis2 <- tauoutput1$inc[!is.infinite(tauoutput1$inc)]
tauanalysis2 <- tauanalysis2[tauanalysis2 < quantile(tauanalysis2, 0.99)]
#This step changes all NA input to 0 and removes infinities
#removes all negative changes - might need to review
#The tail of the distribution has also been trimmed to prevent massive artificial increases from showing up

hist(tauanalysis2, xlab = bquote("% Increase above Baseline Incidence (0.593 per 100,000)"), breaks = 50)

# Plotting Sensitivity Analysis -------------------------------------------

#Increase
sensit <- tauanalysis 
sens <- sensitivity(x=sensit, numberf=12, make.plot=T, names = c("ra", "rh" ,"ua", "uh", "betaAA", "betaAH", "betaHH", "betaHA",
                                                                 "phi", "kappa", "alpha", "zeta"))
df.equilibrium <- NULL; df.equilibrium <- data.frame(parameter=rbind("ra", "rh" ,"ua", "uh", "betaAA", "betaAH", "betaHH", "betaHA",
                                                                     "phi", "kappa", "alpha", "zeta"), value=sens)

#Compensation
sensit1 <- tauanalysis2 #Creating Variable for the output variable of interest
sens1 <- sensitivity(x=sensit1, numberf=12, make.plot=T, names = c("ra", "rh" ,"ua", "uh", "betaAA", "betaAH", "betaHH", "betaHA",
                                                                 "phi", "kappa", "alpha", "zeta"))
df.equilibrium1 <- NULL; df.equilibrium1 <- data.frame(parameter=rbind("ra", "rh" ,"ua", "uh", "betaAA", "betaAH", "betaHH", "betaHA",
                                                                     "phi", "kappa", "alpha", "zeta"), value=sens1)

#Plotting

ggplot(df.equilibrium, aes(x = reorder(parameter, -value), y = value)) + geom_bar(stat="identity", fill="lightgrey", col = "black", width  = 0.8)

p1 <- ggplot(df.equilibrium, aes(x = reorder(parameter, -value), y = value)) + geom_bar(stat="identity", fill="lightgrey", col = "black", width  = 0.8) + theme_bw() + 
  scale_y_continuous(limits = c(0,  max(df.equilibrium$value)*1.1), expand = c(0, 0), name = "Partial Variance") + 
  scale_x_discrete(expand = c(0, 0.7), name = "Parameter", 
                   labels = c(expression(alpha), expression(zeta), expression(kappa),  expression(r[A]),  expression(phi),  expression(mu[A]), 
                              expression(beta[HA]), expression(r[H]), expression(beta[AA]),
                              expression(beta[AH]),expression(beta[HH]), expression(mu[H]))) +
  labs(fill = NULL, title = bquote(bold("Increase in Incidence due to Curtailment" ~ tau ~ "=" ~ 0.00934 ~ "to" ~ tau ~ "=" ~  0))) + 
  theme(legend.text=element_text(size=14), axis.text=element_text(size=14), plot.title = element_text(size = 15, vjust = 1.5, hjust = 0.5),
        axis.title.y=element_text(size=14), axis.title.x= element_text(size=14), plot.margin = unit(c(0.4,0.4,0.4,0.55), "cm"))

ggplot(df.equilibrium1, aes(x = reorder(parameter, -value), y = value)) + geom_bar(stat="identity", fill="lightgrey", col = "black", width  = 0.8)

p2 <- ggplot(df.equilibrium1, aes(x = reorder(parameter, -value), y = value)) + geom_bar(stat="identity", fill="lightgrey", col = "black", width  = 0.8) + theme_bw() + 
  scale_y_continuous(limits = c(0,  max(df.equilibrium1$value)*1.1), expand = c(0, 0), name = "Partial Variance") + 
  scale_x_discrete(expand = c(0, 0.7), name = "Parameter", 
                   labels = c(expression(beta[HA]), expression(r[H]),  expression(zeta), expression(phi), expression(alpha),
                              expression(r[A]),  expression(mu[A]), expression(beta[HH]), expression(beta[AA]),
                              expression(kappa), expression(mu[H]),  expression(beta[AH]))) +
  labs(fill = NULL, title = bquote(bold(.(Mitigating ~ Increases ~ from ~ Baseline ~ Incidence ~ "=" ~ 0.593~ per ~ "100,000")))) + 
  theme(legend.text=element_text(size=14), axis.text=element_text(size=14), plot.title = element_text(size = 15, vjust = 1.5, hjust = 0.5),
        axis.title.y=element_text(size=14), axis.title.x= element_text(size=14), plot.margin = unit(c(0.4,0.4,0.4,0.55), "cm"))

#bquote(bold(.(Mitigating ~ Increases ~ from ~ Baseline ~ I[CombH] ~ "=" ~ 3.26)))

sensplot <- ggarrange(p1,p2, nrow = 2, ncol = 1,
                      align = "v", labels = c("A","B"), font.label = c(size = 20)) 

ggsave(sensplot, filename = "Sensitivity.png", dpi = 300, type = "cairo", width = 8, height = 8, units = "in",
       path = "C:/Users/amorg/Documents/PhD/Chapter_2/Models/Github/Chapter-2/NewFits_041021/figures")

# Effect on Parameters ----------------------------------------------------

parmdetails <- rbind(data.frame("Parameter" = "betaAA", "Value" = seq(0, sensparms["betaAA"]*10, by = (sensparms["betaAA"]*10)/100)),
                     data.frame("Parameter" = "betaHA", "Value" = seq(0, sensparms["phi"]*10, by = (sensparms["phi"]*10)/100)),
                     data.frame("Parameter" = "betaHH", "Value" = seq(0, 0.0001, by = 0.0001/100)),
                     data.frame("Parameter" = "betaAH", "Value" = seq(0, 0.0001, by = 0.0001/100)),
                     data.frame("Parameter" = "phi", "Value" = seq(0, sensparms["phi"]*10, by = (sensparms["phi"]*10)/100)),
                     data.frame("Parameter" = "kappa", "Value" = seq(0, sensparms["kappa"]*10, by = (sensparms["kappa"]*10)/100)),
                     data.frame("Parameter" = "alpha", "Value" = seq(0, 1, by = 1/100)),
                     data.frame("Parameter" = "zeta", "Value" = seq(0, sensparms["zeta"]*10, by = (sensparms["zeta"]*10)/100)),
                     data.frame("Parameter" = "rh", "Value" = seq(0.01, 0.55^-1, by = 0.55^-1/100)),
                     data.frame("Parameter" = "ra", "Value" = seq(0, 6^-1, by = 6^-1/100)),
                     data.frame("Parameter" = "uh", "Value" = seq(0, 2883.5^-1, by = 2883.5^-1/100)),
                     data.frame("Parameter" = "ua", "Value" = seq(0, 24^-1, by = 24^-1/100)))

init <- c(Sa=0.98, Isa=0.01, Ira=0.01, Sh=1, Ish=0, Irh=0)
tau_range <- c(0, sensparms[["tau"]])

parms = c(ra = 60^-1, rh =  (5.5^-1), ua = 240^-1, uh = 28835^-1, betaAA = (sensparms[["betaAA"]]), betaAH = 0.00001, betaHH = 0.00001, 
          betaHA = sensparms[["betaHA"]], phi = sensparms[["phi"]], kappa = sensparms[["kappa"]], alpha = sensparms[["alpha"]], zeta = sensparms[["zeta"]])

suppplotlist <- list()

for (j in 1:length(unique(parmdetails[,1]))) { 
  
  suppplotlist[[j]] <- local ({ 
    output <- data.frame()
    
    for (x in 1:length(parmdetails[parmdetails == as.character(unique(parmdetails[,1])[j]),2])) { #for the individual parameter values in the sequence
      temp1 <- data.frame()
      
      for (i in 1:length(tau_range)) {
        temp <- data.frame(matrix(nrow = 0, ncol=3))
        parmstemp <- c(parms, tau = tau_range[i])
        parmstemp[as.character(unique(parmdetails[,1])[j])] <- parmdetails[parmdetails == as.character(unique(parmdetails[,1])[j]), 2][x]
        out <- runsteady(y = init, func = amr, times = c(0, Inf), parms = parmstemp)
        temp[1,1] <- ((out[[2]] + out[[3]])*(446000000))/100000
        temp[1,2] <- as.character(parmdetails[parmdetails == as.character(unique(parmdetails[,1])[j]), 2][x]) #what is the parameter value used
        temp[1,3] <- as.character(unique(parmdetails[,1])[j]) # what is the parameter explored 
        temp1 <- rbind.data.frame(temp1, temp)
      }
      output <- rbind(output, stringsAsFactors = FALSE,
                      c(as.numeric(temp1[1,1]), 
                        as.numeric(temp1[2,1]), 
                        as.numeric(abs(temp1[1,1] - temp1[2,1])),
                        as.numeric(abs(((temp1[1,1] / temp1[2,1]) - 1)* 100)),
                        as.numeric(abs(((temp1[1,1] / 0.593) - 1)* 100)),
                        as.numeric(temp1[i,2]),
                        as.factor(temp1[i,3])))
      
      print(paste0("Parameter ",unique(parmdetails[,1])[j], " | ", round(x/101, digits = 2)*100,"%" ))
    }
    
    colnames(output)[1:7] <- c("ICombHCurt", "ICombHUsage","IDiff", "PercInc", "RelInc", "ParmValue", "Parm")
    output <- output[!is.nan(output$PercInc) & !is.nan(output$RelInc) & !is.infinite(output$PercInc),]

    plotnames <- c(bquote(beta["AA"]~Parameter), bquote(beta["HA"]~Parameter), bquote(beta["HH"]~Parameter), bquote(beta["AH"]~Parameter), 
                   bquote(phi~Parameter), bquote(kappa~Parameter), bquote(alpha~Parameter), bquote(zeta~Parameter), bquote(r["H"]~Parameter), bquote(r["A"]~Parameter), 
                   bquote(mu["H"]~Parameter), bquote(mu["A"]~Parameter))[[j]]

    p1 <- ggplot(output, aes(x = as.numeric(ParmValue), y = as.numeric(PercInc))) + theme_bw() + geom_line(lwd = 1.02, col ="darkblue") +
      scale_x_continuous(expand = c(0, 0)) + scale_y_continuous(limits = c(0, max(output$PercInc) + 10), expand = c(0, 0)) +
      labs(x = plotnames) + theme(plot.margin=unit(c(0.3,0.3,0.3,0.3),"cm"), axis.title.y=element_blank())

    p2 <- ggplot(output, aes(x = as.numeric(ParmValue), y = as.numeric(RelInc))) + theme_bw() + geom_line(lwd = 1.02, col ="darkblue") +
      scale_x_continuous(expand = c(0, 0)) + scale_y_continuous(limits = c(0, max(output$RelInc) + 10), expand = c(0, 0)) +
      labs(x = plotnames) + theme(plot.margin=unit(c(0.3,0.3,0.3,0.3),"cm"), axis.title.y=element_blank())
    
    if(unique(parmdetails[,1])[j] == "alpha"){
      #print(output)
      p2 <- p2 + geom_vline(xintercept = 0.61, col = "red", size  = 0.7, lty = 3)
    }
    if(unique(parmdetails[,1])[j] == "zeta"){
      #print(output)
      p2 <- p2 + geom_vline(xintercept = 0.07124386, col = "red", size  = 0.7, lty = 3)
    }
    if(unique(parmdetails[,1])[j] == "ra"){
      #print(output)
      p2 <- p2 + geom_vline(xintercept = 0.070000000, col = "red", size  = 0.7, lty = 3)
    }
    return(list(p1,p2))
  })
}

#Absolute Diff
pabdiff <- plot_grid(plot_grid(suppplotlist[[1]][[1]], suppplotlist[[2]][[1]], suppplotlist[[3]][[1]],suppplotlist[[4]][[1]], suppplotlist[[5]][[1]], 
                    suppplotlist[[6]][[1]], suppplotlist[[7]][[1]], suppplotlist[[8]][[1]], suppplotlist[[9]][[1]], suppplotlist[[10]][[1]], suppplotlist[[11]][[1]],
                    suppplotlist[[12]][[1]], nrow = 4, ncol =3), scale=0.95) + 
  draw_label(bquote("% Change in Incidence Relative to Baseline Usage"), x=  0, y=0.5, vjust= 1.5, angle=90, size = 12)

ggsave(pabdiff, filename = "Sensitivity_RelInc.png", dpi = 300, type = "cairo", width = 8, height = 8, units = "in",
       path = "C:/Users/amorg/Documents/PhD/Chapter_2/Models/Github/Chapter-2/NewFits_041021/figures")

#Relative Increase from 3.382
pcompdiff <- plot_grid(plot_grid(suppplotlist[[1]][[2]], suppplotlist[[2]][[2]], suppplotlist[[3]][[2]],suppplotlist[[4]][[2]], suppplotlist[[5]][[2]], 
                    suppplotlist[[6]][[2]], suppplotlist[[7]][[2]], suppplotlist[[8]][[2]], suppplotlist[[9]][[2]], suppplotlist[[10]][[2]], suppplotlist[[11]][[2]], 
                    suppplotlist[[12]][[2]], nrow = 4, ncol =3), scale=0.95) + 
  draw_label(bquote("% Change in Incidence Relative to Case Study Baseline (0.593 per 100,000)"), x=  0, y=0.5, vjust= 1.5, angle=90, size = 12)

ggsave(pcompdiff, filename = "Sensitivity_Compen.png", dpi = 300, type = "cairo", width = 8, height = 8, units = "in",
       path = "C:/Users/amorg/Documents/PhD/Chapter_2/Models/Github/Chapter-2/NewFits_041021/figures")

# What Parameters Cause the Largest Relative Increase? - RESISTANCE --------------------

parms = fast_parameters(minimum = c(0, 55^-1, mean_ua/10, 288350^-1, 
                                    sensparms["betaAA"]/10, 0.000001, 0.000001, sensparms["betaHA"]/10, 
                                    sensparms["phi"]/10 , sensparms["kappa"]/10, 0,  sensparms["zeta"]/10), 
                        maximum = c(6^-1, 0.55^-1, mean_ua*10, 2883.5^-1, 
                                    sensparms["betaAA"]*10, 0.0001, 0.0001, sensparms["betaHA"]*10, 
                                    sensparms["phi"]*10 , sensparms["kappa"]*10, 1, sensparms["zeta"]*10), 
                        factor=12, names = c("ra", "rh" ,"ua", "uh", 
                                             "betaAA", "betaAH", "betaHH", "betaHA",
                                             "phi", "kappa", "alpha", "zeta"))

tauoutput3 <- data.frame(matrix(nrow = 0, ncol = 3))
tau_range <- c(0, sensparms[["tau"]]) # Comparing Baseline Average with Curtailment

for (j in 1:nrow(parms)) {
  temp <- numeric(2)
  for (i in 1:length(tau_range)) {
    parms2 = c(ra = parms$ra[j], rh = parms$rh[j], ua = parms$ua[j], uh = parms$uh[j], betaAA = parms$betaAA[j],
               betaAH = parms$betaAH[j], betaHH = parms$betaHH[j], betaHA = parms$betaHA[j], phi=parms$phi[j],
               kappa=parms$kappa[j], alpha = parms$alpha[j], tau = tau_range[i], zeta = parms$zeta[j])
    
    out <- runsteady(y = init, func = amr, times = c(0,Inf), parms = parms2)
    temp[i] <- out[[1]][["Irh"]] / (out[[1]][["Ish"]] + out[[1]][["Irh"]])
  }
  tauoutput3 <- rbind(tauoutput3, c(temp[1], temp[2], abs(temp[1] - temp[2]), parms2[parms2 != "tau"] ))
  print(j/nrow(parms))
}

colnames(tauoutput3) <- c("curt", "usage", "diff", names(parms2)) 


#Running the FAST Sensitivity Analysis
tauoutput_res <- tauoutput3

tauoutput_res$inc <- ((tauoutput_res$curt / tauoutput_res$usage))* 100 # % Change from the current usage scenario

tauoutput_res$inc[is.nan(tauoutput_res$inc)] <- 0; neg <- tauoutput_res[tauoutput_res$inc < 0,] 
tauoutput_res_df <- tauoutput_res$inc[!is.infinite(tauoutput_res$inc)]
tauoutput_res_df <- tauoutput_res_df[tauoutput_res_df < quantile(tauoutput_res_df, 0.99)]

#This step changes all NA input to 0 and removes infinities
#removes all negative changes - might need to review
#The tail of the distribution has also been trimmed to prevent massive artificial increases from showing up

#We then view the Distribution of Increases Above Baseline
sensparms[["tau"]]
hist(tauoutput_res_df, xlab = bquote("% Change from Baseline Incidence (Tau = 0.00934)"), breaks = 50)

sensit <- tauoutput_res_df
sens <- sensitivity(x=sensit, numberf=12, make.plot=T, names = c("ra", "rh" ,"ua", "uh", "betaAA", "betaAH", "betaHH", "betaHA",
                                                                 "phi", "kappa", "alpha", "zeta"))
df.equilibrium_res <- NULL; df.equilibrium_res <- data.frame(parameter=rbind("ra", "rh" ,"ua", "uh", "betaAA", "betaAH", "betaHH", "betaHA",
                                                                     "phi", "kappa", "alpha", "zeta"), value=sens)

ggplot(df.equilibrium_res, aes(x = reorder(parameter, -value), y = value)) + geom_bar(stat="identity", fill="lightgrey", col = "black", width  = 0.8)

p1 <- ggplot(df.equilibrium_res, aes(x = reorder(parameter, -value), y = value)) + geom_bar(stat="identity", fill="lightgrey", col = "black", width  = 0.8) + theme_bw() + 
  scale_y_continuous(limits = c(0,  max(df.equilibrium_res$value)*1.1), expand = c(0, 0), name = "Partial Variance") + 
  scale_x_discrete(expand = c(0, 0.7), name = "Parameter", 
                   labels = c(expression(r[A]), expression(mu[A]), expression(alpha), expression(beta[AA]),
                              expression(zeta), expression(mu[H]), expression(beta[HA]), expression(phi),
                              expression(kappa), expression(r[H]), expression(beta[HH]), expression(beta[AH]))) + 
  labs(fill = NULL, title = bquote(bold("Change in Resistance due to Curtailment" ~ tau ~ "=" ~ 0.00934 ~ "to" ~ tau ~ "=" ~  0))) + 
  theme(legend.text=element_text(size=14), axis.text=element_text(size=14), plot.title = element_text(size = 15, vjust = 1.5, hjust = 0.5),
        axis.title.y=element_text(size=14), axis.title.x= element_text(size=14), plot.margin = unit(c(0.4,0.4,0.4,0.55), "cm"))

ggsave(p1, filename = "Sensitivity_res.png", dpi = 300, type = "cairo", width = 8, height = 4, units = "in",
       path = "C:/Users/amorg/Documents/PhD/Chapter_2/Models/Github/Chapter-2/NewFits_041021/figures")

