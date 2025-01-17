library("deSolve"); library("ggplot2"); library("plotly"); library("reshape2")
library("bayestestR"); library("tmvtnorm"); library("ggpubr"); library("sensitivity"); library("fast");
library("cowplot")

rm(list=ls())
setwd("C:/Users/amorg/Documents/PhD/Chapter_2/Chapter2_Fit_Data/FinalData/NewFit")

# Model Functions ----------------------------------------------------------
#Function to remove negative prevalence values and round large DP numbers
rounding <- function(x) {
  if(as.numeric(x) < 1e-10) {x <- 0
  } else{signif(as.numeric(x), digits = 6)}
}

#Model ODEs
amr <- function(t, y, parms) {
  with(as.list(c(y, parms)), {
    dSa = ua + ra*(Isa + Ira) + kappa*tau*Isa - (betaAA*Isa*Sa) - (betaAH*Ish*Sa) - (1-alpha)*(betaAH*Irh*Sa) - (1-alpha)*(betaAA*Ira*Sa) - ua*Sa -
      zeta*Sa*(1-alpha) - zeta*Sa 
    dIsa = betaAA*Isa*Sa + betaAH*Ish*Sa + phi*Ira - kappa*tau*Isa - tau*Isa - ra*Isa - ua*Isa + zeta*Sa
    dIra = (1-alpha)*betaAH*Irh*Sa + (1-alpha)*betaAA*Ira*Sa + tau*Isa - phi*Ira - ra*Ira - ua*Ira + zeta*Sa*(1-alpha)
    
    dSh = uh + rh*(Ish+Irh) - (betaHH*Ish*Sh) - (1-alpha)*(betaHH*Irh*Sh) - (betaHA*Isa*Sh) - (1-alpha)*(betaHA*Ira*Sh) - uh*Sh 
    dIsh = betaHH*Ish*Sh + betaHA*Isa*Sh - rh*Ish - uh*Ish 
    dIrh = (1-alpha)*(betaHH*Irh*Sh) + (1-alpha)*(betaHA*Ira*Sh) - rh*Irh - uh*Irh 
    return(list(c(dSa,dIsa,dIra,dSh,dIsh,dIrh)))
  })
}

#Importing in the Datasets
import <- function(id) {
  data <- data.frame(matrix(ncol = 6, nrow = 0))
  for(i in 1:10) {
    test  <- cbind(read.csv(paste0("results_ABC_SMC_gen_",substitute(id),"_",i,".csv"), 
                            header = TRUE), "group" = paste0("data",i), "fit" = as.character(substitute(id)))
    data <- rbind(data, test)
  }
  return(data)
}

# Identify the MAP averages for the Parameter Sets ---------------------------------
#Import of Posterior Distributions
data <- do.call(rbind, list(import(tet), import(amp), import(broil)))

MAPtet <- c("phi" <- mean(data$phi[which(data$group == "data10" & data$fit == "tet")]),
            "kappa" <- mean(data$kappa[which(data$group == "data10" & data$fit == "tet")]),
            "betaAA" <- mean(data$betaAA[which(data$group == "data10" & data$fit == "tet")]),
            "alpha" <- mean(data$alpha[which(data$group == "data10" & data$fit == "tet")]),
            "zeta" <- mean(data$zeta[which(data$group == "data10" & data$fit == "tet")]))

MAPamp <- c("phi" <- mean(data$phi[which(data$group == "data10" & data$fit == "amp")]),
            "kappa" <- mean(data$kappa[which(data$group == "data10" & data$fit == "amp")]),
            "betaAA" <- mean(data$betaAA[which(data$group == "data10" & data$fit == "amp")]),
            "alpha" <- mean(data$alpha[which(data$group == "data10" & data$fit == "amp")]),
            "zeta" <- mean(data$zeta[which(data$group == "data10" & data$fit == "amp")]))

MAPbroil <- c("phi" <- mean(data$phi[which(data$group == "data10" & data$fit == "broil")]),
              "kappa" <- mean(data$kappa[which(data$group == "data10" & data$fit == "broil")]),
              "betaAA" <- mean(data$betaAA[which(data$group == "data10" & data$fit == "broil")]),
              "alpha" <- mean(data$alpha[which(data$group == "data10" & data$fit == "broil")]),
              "zeta" <- mean(data$zeta[which(data$group == "data10" & data$fit == "broil")]))

MAP <- rbind(MAPtet, MAPamp, MAPbroil); colnames(MAP) <- c("phi", "kappa", "betaAA", "alpha", "zeta")

sensparms <- c("phi" = mean(MAP[1:3]), 
               "kappa" = mean(MAP[4:6]),
               "betaAA" = mean(MAP[7:9]),
               "alpha" = mean(MAP[10:12]),
               "zeta" = mean(MAP[13:15]),
               "tau" = mean(c(0.0122887,0.01156391,0.006666697)))

# Sensitivity Analysis ---------------------------------------------------
# Joint Parameters

#We do this for Tetracycline for the Parameter Bounds
#All other parameters will be included in the ranges

times <- seq(0,30000, by = 100) 
init <- c(Sa=0.98, Isa=0.01, Ira=0.01, Sh=1, Ish=0, Irh=0)

#These Parameters Are Based on MAP from Model Fitting
#parms = fast_parameters(minimum = c(600^-1, 55^-1, 2400^-1, 288350^-1, 
#                                    0, 0.000001, 0.000001, 0.000001, 
#                                    0, 0, 0, 0, 0), 
#                        maximum = c(6^-1, 0.55^-1, 24^-1, 2883.5^-1, 
#                                    0.5, 0.0001, 0.0001, 0.0001, 
#                                    0.1310852 , 11.30831, 1, 0.1, 0.5), 
#                        factor=13, names = c("ra", "rh" ,"ua", "uh", 
#                                             "betaAA", "betaAH", "betaHH", "betaHA",
#                                             "phi", "kappa", "alpha", "tau", "zeta"))

parms = fast_parameters(minimum = c(600^-1, 55^-1, 2400^-1, 288350^-1, 
                                    sensparms["betaAA"]/10, 0.000001, 0.000001, 0.000001, 
                                    sensparms["phi"]/10 , sensparms["kappa"]/10, 0, sensparms["tau"]/10, sensparms["zeta"]/10), 
                        maximum = c(6^-1, 0.55^-1, 24^-1, 2883.5^-1, 
                                    sensparms["betaAA"]*10, 0.0001, 0.0001, 0.0001, 
                                    sensparms["phi"]*10 , sensparms["kappa"]*10, 1, sensparms["tau"]*10, sensparms["zeta"]*10), 
                        factor=13, names = c("ra", "rh" ,"ua", "uh", 
                                           "betaAA", "betaAH", "betaHH", "betaHA",
                                             "phi", "kappa", "alpha", "tau", "zeta"))

# General Sensitivity Analysis - ICombH and ResRat -------------------------

output <- data.frame(matrix(ncol = 2, nrow = nrow(parms)))
colnames(output) <- c("ICombH", "IResRat")

for (i in 1:nrow(parms)) {
  temp <- numeric(1)
  parms1 = c(ra = parms$ra[i], rh = parms$rh[i], ua = parms$ua[i], uh = parms$uh[i], betaAA = parms$betaAA[i],
             betaAH = parms$betaAH[i], betaHH = parms$betaHH[i], betaHA = parms$betaHA[i], phi=parms$phi[i],
             tau=parms$tau[i], kappa=parms$kappa[i], alpha = parms$alpha[i], zeta = parms$zeta[i])
  out <- ode(y = init, func = amr, times = times, parms = parms1)
  temp[1] <- rounding(out[nrow(out),6]) + rounding(out[nrow(out),7])
  temp[2] <- rounding(out[nrow(out),7])/(rounding(out[nrow(out),6]) + rounding(out[nrow(out),7]))
  print(paste0("Progress: ",signif(i/nrow(parms))*100, digits = 3, "%"))
  output[i,] <- temp
}

output1 <- output
output1$IResRat[is.nan(output1$IResRat)] <- 0
output1 <- output1[!is.infinite(rowSums(output1)),]

#ICombH
sensit1 <- NULL; df.equilibrium <- NULL
sensit1 <- output1$ICombH #Creating Variable for the output variable of interest
sens1 <- sensitivity(x=sensit1, numberf=13, make.plot=T, names = c("ra", "rh" ,"ua", "uh", "betaAA", "betaAH", "betaHH", "betaHA",
                                                                   "phi", "kappa", "alpha", "tau", "zeta"))

df.equilibrium <- data.frame(parameter=rbind("ra", "rh" ,"ua", "uh", "betaAA", "betaAH", "betaHH", "betaHA",
                                             "phi", "kappa", "alpha", "tau", "zeta"), value=sens1)

ggplot(df.equilibrium, aes(x = reorder(parameter, -value), y = value)) + geom_bar(stat="identity", fill="lightgrey", col = "black", width  = 0.8)

ICombH <- ggplot(df.equilibrium, aes(x = reorder(parameter, -value), y = value)) + geom_bar(stat="identity", fill="lightgrey", col = "black", width  = 0.8) + theme_bw() + 
  scale_y_continuous(limits = c(0,  max(df.equilibrium$value)*1.1), expand = c(0, 0), name = "Partial Variance") + 
  scale_x_discrete(expand = c(0, 0.7), name = "Parameter", 
                   labels = c(expression(r[H]), expression(beta[HA]),  expression(alpha),expression(zeta), expression(beta[HH]),
                              expression(tau), expression(kappa), expression(r[A]), expression(beta[AA]), expression(mu[H]),
                              expression(mu[A]),  expression(beta[AH]), expression(phi))) +
  labs(fill = NULL, title = bquote(Sensitivity~Analysis~of~"I*"["H"])) + 
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
                   labels = c(expression(alpha), expression(tau), expression(phi), expression(kappa), expression(r[A]), expression(mu[A]),
                              expression(beta[AA]), expression(zeta), expression(mu[H]), expression(beta[AH]),
                              expression(r[H]), expression(beta[HA]), expression(beta[HH]))) +
  labs(fill = NULL, title = bquote(Sensitivity~Analysis~of~"I*"["RHProp"])) + 
  theme(legend.text=element_text(size=14), axis.text=element_text(size=14), plot.title = element_text(size = 15, vjust = 1.5, hjust = 0.5, face = "bold"),
        axis.title.y=element_text(size=14), axis.title.x= element_text(size=14), plot.margin = unit(c(0.4,0.4,0.4,0.55), "cm"))

sensplot <- ggarrange(ICombH, resprop, nrow = 2, ncol = 1, align = "v", labels = c("A","B"), font.label = c(size = 20)) 

ggsave(sensplot, filename = "Sensitivity_ICombH_ResRat.png", dpi = 300, type = "cairo", width = 7, height = 8, units = "in",
       path = "C:/Users/amorg/Documents/PhD/Chapter_2/Figures/Redraft_v1")

# What Parameters Cause the Largest Relative Increase? --------------------

parms = fast_parameters(minimum = c(600^-1, 55^-1, 2400^-1, 288350^-1, 
                                    sensparms["betaAA"]/10, 0.000001, 0.000001, 0.000001, 
                                    sensparms["phi"]/10 , sensparms["kappa"]/10, 0, sensparms["zeta"]/10), 
                        maximum = c(6^-1, 0.55^-1, 24^-1, 2883.5^-1, 
                                    sensparms["betaAA"]*10, 0.0001, 0.0001, 0.0001, 
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
    out <- ode(y = init, func = amr, times = times, parms = parms2)
    temp[i] <- (rounding(out[nrow(out),6]) + rounding(out[nrow(out),7]))*100000
  }
  tauoutput <- rbind(tauoutput, c(temp[1], temp[2], abs(temp[1] - temp[2]), parms2[parms2 != "tau"] ))
  print(j/nrow(parms))
}

colnames(tauoutput) <- c("curt", "usage", "diff") 

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

mean(c(0.0122887, 0.01156391, 0.006666697))
hist(tauanalysis, xlab = bquote("% Increase above Baseline"~"I*"["H"]~" (Tau = 0.0102)"), breaks = 50)

# What Parameters Can Compensate? ------------------------------------------

tauoutput <- data.frame(matrix(nrow = 0, ncol = 3))

for (j in 1:nrow(parms)) {
  parms2 = c(ra = parms$ra[j], rh = parms$rh[j], ua = parms$ua[j], uh = parms$uh[j], betaAA = parms$betaAA[j],
             betaAH = parms$betaAH[j], betaHH = parms$betaHH[j], betaHA = parms$betaHA[j], phi=parms$phi[j],
             kappa=parms$kappa[j], alpha = parms$alpha[j], tau = 0, zeta = parms$zeta[j])
  out <- ode(y = init, func = amr, times = times, parms = parms2)
  temp <- (rounding(out[nrow(out),6]) + rounding(out[nrow(out),7]))*100000
  tauoutput <- rbind(tauoutput, c(temp ,abs(temp - 3.26)))
  print(j/nrow(parms))
}

colnames(tauoutput) <- c("IComb0","diff") 

tauoutput1 <- tauoutput 

tauoutput1$inc <- ((tauoutput1$IComb0 / 3.26) - 1)* 100 # % Increase from the current usage scenario
tauoutput1$inc[is.nan(tauoutput1$inc)] <- 0; neg <- tauoutput1[tauoutput1$inc < 0,] 
tauanalysis2 <- tauoutput1$inc[!is.infinite(tauoutput1$inc)]
tauanalysis2 <- tauanalysis2[tauanalysis2 < quantile(tauanalysis2, 0.99)]
#This step changes all NA input to 0 and removes infinities
#removes all negative changes - might need to review
#The tail of the distribution has also been trimmed to prevent massive artificial increases from showing up

hist(tauanalysis2, xlab = bquote("% Increase above Baseline"~"I*"["H"]~" (3.26 per 100,000)"), breaks = 50)

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
                   labels = c(expression(zeta), expression(kappa), expression(alpha), expression(r[A]), expression(phi), expression(mu[H]),
                              expression(mu[A]), expression(beta[AA]),expression(r[H]),
                              expression(beta[AH]) , expression(beta[HH]), expression(beta[HA]))) +
  labs(fill = NULL, title = bquote(bold("Increase in"~ "I*"["H"] ~ "from" ~ tau ~ "=" ~ 0.0102 ~ "to" ~ tau ~ "=" ~  0))) + 
  theme(legend.text=element_text(size=14), axis.text=element_text(size=14), plot.title = element_text(size = 15, vjust = 1.5, hjust = 0.5),
        axis.title.y=element_text(size=14), axis.title.x= element_text(size=14), plot.margin = unit(c(0.4,0.4,0.4,0.55), "cm"))

ggplot(df.equilibrium1, aes(x = reorder(parameter, -value), y = value)) + geom_bar(stat="identity", fill="lightgrey", col = "black", width  = 0.8)

p2 <- ggplot(df.equilibrium1, aes(x = reorder(parameter, -value), y = value)) + geom_bar(stat="identity", fill="lightgrey", col = "black", width  = 0.8) + theme_bw() + 
  scale_y_continuous(limits = c(0,  max(df.equilibrium1$value)*1.1), expand = c(0, 0), name = "Partial Variance") + 
  scale_x_discrete(expand = c(0, 0.7), name = "Parameter", 
                   labels = c(expression(r[H]), expression(beta[HA]), expression(r[A]), expression(alpha), 
                              expression(zeta),expression(beta[AA]), expression(kappa), expression(beta[AH]),
                              expression(mu[A]), expression(beta[HH]), expression(phi),expression(mu[H]))) +
  labs(fill = NULL, title = bquote(bold(.(Mitigating ~ Increases ~ from ~ Baseline ~ "I*"["H"] ~ "=" ~ 3.26~ per ~ "100,000")))) + 
  theme(legend.text=element_text(size=14), axis.text=element_text(size=14), plot.title = element_text(size = 15, vjust = 1.5, hjust = 0.5),
        axis.title.y=element_text(size=14), axis.title.x= element_text(size=14), plot.margin = unit(c(0.4,0.4,0.4,0.55), "cm"))

#bquote(bold(.(Mitigating ~ Increases ~ from ~ Baseline ~ I[CombH] ~ "=" ~ 3.26)))

sensplot <- ggarrange(p1,p2, nrow = 2, ncol = 1,
                      align = "v", labels = c("A","B"), font.label = c(size = 20)) 

ggsave(sensplot, filename = "Sensitivity.png", dpi = 300, type = "cairo", width = 7, height = 8, units = "in",
       path = "C:/Users/amorg/Documents/PhD/Chapter_2/Figures/Redraft_v1")

# Effect on Parameters ----------------------------------------------------

parmdetails <- rbind(data.frame("Parameter" = "betaAA", "Value" = seq(0, sensparms["betaAA"]*10, by = (sensparms["betaAA"]*10)/100)),
                     data.frame("Parameter" = "betaHA", "Value" = seq(0, 0.0001, by = 0.0001/100)),
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

times <- seq(0,30000, by = 100) 
init <- c(Sa=0.98, Isa=0.01, Ira=0.01, Sh=1, Ish=0, Irh=0)
tau_range <- c(0, sensparms[["tau"]])

parms = c(ra = 60^-1, rh =  (5.5^-1), ua = 240^-1, uh = 28835^-1, betaAA = (sensparms[["betaAA"]]), betaAH = 0.00001, betaHH = 0.00001, 
          betaHA = (0.00001), phi = sensparms[["phi"]], kappa = sensparms[["kappa"]], alpha = sensparms[["alpha"]], zeta = sensparms[["zeta"]])

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
        out <- ode(y = init, func = amr, times = times, parms = parmstemp)
        temp[1,1] <- (rounding(out[nrow(out),6]) + rounding(out[nrow(out),7]))*100000
        temp[1,2] <- as.character(parmdetails[parmdetails == as.character(unique(parmdetails[,1])[j]), 2][x]) #what is the parameter value used
        temp[1,3] <- as.character(unique(parmdetails[,1])[j]) # what is the parameter explored 
        temp1 <- rbind.data.frame(temp1, temp)
      }
      output <- rbind(output, stringsAsFactors = FALSE,
                      c(as.numeric(temp1[1,1]), 
                        as.numeric(temp1[2,1]), 
                        as.numeric(abs(temp1[1,1] - temp1[2,1])),
                        as.numeric(abs(((temp1[1,1] / temp1[2,1]) - 1)* 100)),
                        as.numeric(abs(((temp1[1,1] / 3.26) - 1)* 100)),
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
    
    if(unique(parmdetails[,1])[j] == "betaHA"){
      p2 <- p2 + geom_vline(xintercept = 8.0e-06, col = "red", size  = 0.7, lty = 3)
    }
    if(unique(parmdetails[,1])[j] == "zeta"){
      p2 <- p2 + geom_vline(xintercept = 0.011084193, col = "red", size  = 0.7, lty = 3)
    }
    if(unique(parmdetails[,1])[j] == "ra"){
      p2 <- p2 + geom_vline(xintercept = 0.038333333, col = "red", size  = 0.7, lty = 3)
    }
    if(unique(parmdetails[,1])[j] == "ua"){
      p2 <- p2 + geom_vline(xintercept = 0.0254166667, col = "red", size  = 0.7, lty = 3)
    }
    
    if(unique(parmdetails[,1])[j] == "rh"){
      p2 <- p2 + geom_vline(xintercept = 0.22818182, col = "red", size  = 0.7, lty = 3)
    }
    
    
    return(list(p1,p2))
  })
}

#Absolute Diff
pabdiff <- plot_grid(plot_grid(suppplotlist[[1]][[1]], suppplotlist[[2]][[1]], suppplotlist[[3]][[1]],suppplotlist[[4]][[1]], suppplotlist[[5]][[1]], 
                    suppplotlist[[6]][[1]], suppplotlist[[7]][[1]], suppplotlist[[8]][[1]], suppplotlist[[9]][[1]], suppplotlist[[10]][[1]], suppplotlist[[11]][[1]],
                    suppplotlist[[12]][[1]], nrow = 4, ncol =3), scale=0.95) + 
  draw_label(bquote("% Change in"~ " I*"["H"]~" Relative to Baseline Usage"), x=  0, y=0.5, vjust= 1.5, angle=90, size = 12)

ggsave(pabdiff, filename = "Sensitivity_RelInc.png", dpi = 300, type = "cairo", width = 5, height = 7, units = "in",
       path = "C:/Users/amorg/Documents/PhD/Chapter_2/Figures/Redraft_v1")

#Relative Increase from 3.382
pcompdiff <- plot_grid(plot_grid(suppplotlist[[1]][[2]], suppplotlist[[2]][[2]], suppplotlist[[3]][[2]],suppplotlist[[4]][[2]], suppplotlist[[5]][[2]], 
                    suppplotlist[[6]][[2]], suppplotlist[[7]][[2]], suppplotlist[[8]][[2]], suppplotlist[[9]][[2]], suppplotlist[[10]][[2]], suppplotlist[[11]][[2]], 
                    suppplotlist[[12]][[2]], nrow = 4, ncol =3), scale=0.95) + 
  draw_label(bquote("% Change in"~ " I*"["H"]~ " Relative to Case Study Baseline (3.26 per 100,000)"), x=  0, y=0.5, vjust= 1.5, angle=90, size = 12)

ggsave(pcompdiff, filename = "Sensitivity_Compen.png", dpi = 300, type = "cairo", width = 5, height = 7, units = "in",
       path = "C:/Users/amorg/Documents/PhD/Chapter_2/Figures/Redraft_v1")
