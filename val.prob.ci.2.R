# Based on Harrell's val.prob function
# - scaled Brier score by relating to max for average calibrated Null model
# - risk distribution according to outcome
# - 0 and 1 to indicate outcome label; set with d1lab="..", d0lab=".."
# - labels: y axis: "Observed Frequency"; Triangle: "Grouped patients"
# - confidence intervals around triangles
# - a cut-off can be plotted; set x coordinate

# work done by Yvonne Vergouwe & Ewout Steyerberg
  # adjusted by De Cock Bavo
    # - nonparametric calibration curves: Loess or RCS
      # Loess: - CL Loess can be plotted by specifying CL.smooth=T, specify CL.smooth="fill" to fill the CI
      #        - CL can be computed by using the bootstrap procedure, specify CL.BT=T
      # RCS  : - knots.rcs: specify knots for RCS
      #        - rcs.lazy: use rcspline.eval to find the knots, nr. of knots can be specified in nr.knots
    # - plot : - you can now adjust the plot through use of normal plot commands (cex.axis etc)
    #          - the size of the legend now has to be specified in cex.leg.0 (cex is now used in plot because of the ellipsis
    #            argument)
      
      
val.prob.ci.2<-
  function(p, y, logit, group, weights = rep(1, length(y)), normwt = F, pl = T, 
           smooth = c("loess","rcs"), CL.smooth=F,CL.BT=F,knots.rcs=seq(0.05,0.95,length=5),rcs.lazy=F,
           nr.knots=5,
           logistic.cal = T, xlab = "Predicted probability", ylab = 
             "Observed frequency", xlim = c(-0.02, 1),ylim = c(-0.15,1), m, g, cuts, emax.lim = c(0, 1), 
           legendloc =  c(0.0 , 0.8), statloc = c(0,.85),dostats=c(12,13,2,15,3),roundstats=2,
           riskdist = "predicted", cex=0.75,cex.leg.0 = 0.7, mkh = 0.02, connect.group = 
             F, connect.smooth = T, g.group = 4, evaluate = 100, nmin = 0, d0lab="0", d1lab="1", cex.d01=0.7,
           dist.label=0.04, line.bins=-.05, dist.label2=.03, cutoff, las=1, length.seg=1,
           xd1lab=0.95,yd1lab=-0.0001,xd0lab=0.95,yd0lab=-0.1,use.legend=T,...)
  {
    if(missing(p))
      p <- 1/(1 + exp( - logit))
    else logit <- log(p/(1 - p))
    if(length(p) != length(y))
      stop("lengths of p or logit and y do not agree")
    names(p) <- names(y) <- names(logit) <- NULL
    if(!missing(group)) {
      if(length(group) == 1 && is.logical(group) && group)
        group <- rep("", length(y))
      if(!is.factor(group))
        group <- if(is.logical(group) || is.character(group)) 
          as.factor(group) else cut2(group, g = 
                                       g.group)
      names(group) <- NULL
      nma <- !(is.na(p + y + weights) | is.na(group))
      ng <- length(levels(group))
    }
    else {
      nma <- !is.na(p + y + weights)
      ng <- 0
    }
    logit <- logit[nma]
    y <- y[nma]
    p <- p[nma]
    
    # Sort vector with probabilities
    y     <- y[order(p)]
    logit <- logit[order(p)]
    p     <- p[order(p)]
    
    smooth <- match.arg(smooth)
    
    if(ng > 0) {
      group <- group[nma]
      weights <- weights[nma]
      return(val.probg(p, y, group, evaluate, weights, normwt, nmin)
      )
    }
    if(length(unique(p)) == 1) {
      #22Sep94
      P <- mean(y)
      Intc <- log(P/(1 - P))
      n <- length(y)
      D <- -1/n
      L01 <- -2 * sum(y * logit - log(1 + exp(logit)), na.rm = T)
      L.cal <- -2 * sum(y * Intc - log(1 + exp(Intc)), na.rm = T)
      U.chisq <- L01 - L.cal
      U.p <- 1 - pchisq(U.chisq, 1)
      U <- (U.chisq - 1)/n
      Q <- D - U
      
      stats <- c(0, 0.5, 0, D, 0, 1, U, U.chisq, U.p, Q, mean((y - p[
        1])^2), Intc, 0, rep(abs(p[1] - P), 2))
      names(stats) <- c("Dxy", "C (ROC)", "R2", "D", "D:Chi-sq", 
                        "D:p", "U", "U:Chi-sq", "U:p", "Q", "Brier", 
                        "Intercept", "Slope", "Emax", "Eavg")
      return(stats)
    }
    i <- !is.infinite(logit)
    nm <- sum(!i)
    if(nm > 0)
      warning(paste(nm, 
                    "observations deleted from logistic calibration due to probs. of 0 or 1"
      ))
    f.or <- lrm(y[i]~logit[i])
    f <- lrm.fit(logit[i], y[i])
    f2<-	lrm.fit(offset=logit[i], y=y[i])
    stats <- f$stats
    n <- stats["Obs"]
    predprob <- seq(emax.lim[1], emax.lim[2], by = 0.0005)
    lt <- f$coef[1] + f$coef[2] * log(predprob/(1 - predprob))
    calp <- 1/(1 + exp( - lt))
    emax <- max(abs(predprob - calp))
    if (pl) {
      plot(0.5, 0.5, xlim = xlim, ylim = ylim, type = "n", xlab = xlab, 
           ylab = ylab, las=las,...)
      clip(0,1,0,1)
      abline(0, 1, lty = 2)
      do.call("clip", as.list(par()$usr))
      
      lt <- 2
      lw.d <- 1
      leg <- "Ideal"
      marks <- -1
      if (logistic.cal) {
        lt <- c(lt, 1)
        lw.d <- c(lw.d,1)
        leg <- c(leg, "Logistic calibration")
        marks <- c(marks, -1)
      }
      if (smooth=="loess") {
        #Sm <- lowess(p,y,iter=0)
        Sm <- loess(y~p,degree=2)
        Sm <- data.frame(Sm$x,Sm$fitted)
        Sm <- Sm[which(Sm$Sm.fitted<1),]
        Sm <- Sm[which(Sm$Sm.fitted>0),]
        
        if (connect.smooth) {
          lines(Sm, lty = 1,lwd=2)
          lt <- c(lt, 1)
          lw.d <- c(lw.d,2)
          marks <- c(marks, -1)
        }else{
          points(Sm)
          lt <- c(lt, 0)
          lw.d <- c(lw.d,1)
          marks <- c(marks, 1)
        }
        if(CL.smooth==T | CL.smooth=="fill"){
          to.pred <- seq(min(p),max(p),length=200)
          if(CL.BT==T){
            if(length(p)>1000){warning("Number of observations is > 1000, this could take a while...")}
            BT.samples <- function(y,p){
              data.1 <- cbind.data.frame(y,p)
              
              # REPEAT TO PREVENT BT SAMPLES WITH NA'S
              repeat{
                BT.sample.rows <- sample(1:nrow(data.1),replace=T)
                BT.sample <- data.1[BT.sample.rows,]
                loess(y~p,BT.sample) ->loess.BT
                predict(loess.BT,to.pred,type="fitted") ->pred.loess
                if(!any(is.na(pred.loess))){break}
              }
              return(pred.loess)
            }
            replicate(2000,BT.samples(y,p)) -> res.BT
            apply(res.BT,1,quantile,c(0.025,0.975)) -> CL.BT
            colnames(CL.BT) <- to.pred
            
            clip(0,1,0,1)
            lines(to.pred,CL.BT[1,],lty=5,lwd=2);clip(0,1,0,1);lines(to.pred,CL.BT[2,],lty=5,lwd=2)
            do.call("clip", as.list(par()$usr))
            
          }else{
            Sm.0 <- loess(y~p,degree=2)
            predict(Sm.0,type="fitted",se=T) -> cl.loess
            clip(0,1,0,1)
            if(CL.smooth=="fill"){
              polygon(x = c(Sm.0$x, rev(Sm.0$x)), y = c(cl.loess$fit+cl.loess$se.fit*1.96,
                                                        rev(cl.loess$fit-cl.loess$se.fit*1.96)), 
                      col = rgb(177, 177, 177, 177, maxColorValue = 255), border = NA)
              do.call("clip", as.list(par()$usr))
              leg <- c(leg, "Nonparametric")
            }else{	
              lines(Sm.0$x,cl.loess$fit+cl.loess$se.fit*1.96,lty=6,lwd=2)
              lines(Sm.0$x,cl.loess$fit-cl.loess$se.fit*1.96,lty=6,lwd=2)
              do.call("clip", as.list(par()$usr))
              leg <- c(leg,"Nonparametric","CL nonparametric")
              lt <- c(lt,6)
              lw.d <- c(lw.d,2)
              marks <- c(marks,-1)
            }
            
          } 
          
        }else{
          leg <- c(leg, "Nonparametric")}
        cal.smooth <- approx(Sm, xout = p)$y
        eavg <- mean(abs(p - cal.smooth))
      }
      if(smooth=="rcs"){
        par(lwd=2)
        rcspline.plot(p,y,model="logistic",knots=knots.rcs,show="prob", statloc = "none"
                      ,add=T,showknots=F)
        if(rcs.lazy==T){
          rcspline.eval(p,nk=nr.knots)->knots
          attributes(knots)$knots ->vec.knots
          rcspline.plot(p,y,model="logistic",knots=vec.knots,show="prob", statloc = "none"
                        ,add=T,showknots=F)
        }
        par(lwd=1)
        leg <- c(leg,"RCS","CL RCS")
        lt <- c(lt,1,2)
        lw.d <- c(lw.d,2,2)
        marks <- c(marks,-1,-1)
      }
      if(!missing(m) | !missing(g) | !missing(cuts)) {
        if(!missing(m))
          q <- cut2(p, m = m, levels.mean = T, digits = 7)
        else if(!missing(g))
          q <- cut2(p, g = g, levels.mean = T, digits = 7)
        else if(!missing(cuts))
          q <- cut2(p, cuts = cuts, levels.mean = T, digits = 7)
        means <- as.single(levels(q))
        prop <- tapply(y, q, function(x)mean(x, na.rm = T))
        points(means, prop, pch = 2, cex=cex)
        #18.11.02: CI triangles			
        ng	<-tapply(y, q, length)
        og	<-tapply(y, q, sum)
        ob	<-og/ng
        se.ob	<-sqrt(ob*(1-ob)/ng)
        g		<- length(as.single(levels(q)))
        
        for (i in 1:g) lines(c(means[i], means[i]), c(prop[i],min(1,prop[i]+1.96*se.ob[i])), type="l")
        for (i in 1:g) lines(c(means[i], means[i]), c(prop[i],max(0,prop[i]-1.96*se.ob[i])), type="l")
        
        if(connect.group) {
          lines(means, prop)
          lt <- c(lt, 1)
          lw.d <- c(lw.d,1)
        }
        else lt <- c(lt, 0)
        lw.d <- c(lw.d,0)
        leg <- c(leg, "Grouped patients")
        marks <- c(marks, 2)
      }
    }
    lr <- stats["Model L.R."]
    p.lr <- stats["P"]
    D <- (lr - 1)/n
    L01 <- -2 * sum(y * logit - logb(1 + exp(logit)), na.rm = TRUE)
    U.chisq <- L01 - f$deviance[2]
    p.U <- 1 - pchisq(U.chisq, 2)
    U <- (U.chisq - 2)/n
    Q <- D - U
    Dxy <- stats["Dxy"]
    C <- stats["C"]
    R2 <- stats["R2"]
    B <- sum((p - y)^2)/n
    # ES 15dec08 add Brier scaled
    Bmax  <- mean(y) * (1-mean(y))^2 + (1-mean(y)) * mean(y)^2
    Bscaled <- 1 - B/Bmax
    stats <- c(Dxy, C, R2, D, lr, p.lr, U, U.chisq, p.U, Q, B, 
               f2$coef[1], f$coef[2], emax, Bscaled)
    names(stats) <- c("Dxy", "C (ROC)", "R2", "D", "D:Chi-sq", 
                      "D:p", "U", "U:Chi-sq", "U:p", "Q", "Brier", "Intercept", 
                      "Slope", "Emax", "Brier scaled")
    if(smooth=="loess")
      stats <- c(stats, c(Eavg = eavg))
    
    # Cut off definition	
    if(!missing(cutoff)) {
      arrows(x0=cutoff,y0=.1,x1=cutoff,y1=-0.025,length=.15)
    }	
    if(pl) {
      if(min(p)>0.1 & max(p)<0.9){
        
        lrm(y~qlogis(p))-> lrm.fit.1
        lines(p,plogis(lrm.fit.1$linear.predictors),lwd=1,lty=1)
        
      }else{logit <- seq(-7, 7, length = 200)
      prob <- 1/(1 + exp( - logit))
      pred.prob <- f$coef[1] + f$coef[2] * logit
      pred.prob <- 1/(1 + exp( - pred.prob))
      if(logistic.cal) lines(prob, pred.prob, lty = 1,lwd=1)
      }
      #	pc <- rep(" ", length(lt))
      #	pc[lt==0] <- "."
      lp <- legendloc
      if (!is.logical(lp)) {
        if (!is.list(lp)) 
          lp <- list(x = lp[1], y = lp[2])
        if(use.legend==T){
          legend(lp, leg, lty = lt, pch = marks, cex = cex.leg.0, bty = "n",lwd=lw.d)
        }
      }
      if(is.character(riskdist)) {
        if(riskdist == "calibrated") {
          x <- f$coef[1] + f$coef[2] * log(p/(1 - p))
          x <- 1/(1 + exp( - x))
          x[p == 0] <- 0
          x[p == 1] <- 1
        }
        else x <- p
        bins <- seq(0, min(1,max(xlim)), length = 101) 
        x <- x[x >= 0 & x <= 1]
        #08.04.01,yvon: distribution of predicted prob according to outcome
        f0	<-table(cut(x[y==0],bins))
        f1	<-table(cut(x[y==1],bins))
        j0	<-f0 > 0
        j1	<-f1 > 0
        bins0 <-(bins[-101])[j0]
        bins1 <-(bins[-101])[j1]
        f0	<-f0[j0]
        f1	<-f1[j1]
        maxf <-max(f0,f1)
        f0	<-(0.1*f0)/maxf
        f1	<-(0.1*f1)/maxf
        
        segments(bins1,line.bins,bins1,length.seg*f1+line.bins)
        segments(bins0,line.bins,bins0,length.seg*-f0+line.bins)
        lines(c(min(bins0,bins1)-0.01,max(bins0,bins1)+0.01),c(line.bins,line.bins))
        text(xd1lab,yd1lab,d1lab,cex=cex.d01)
        text(xd0lab,yd0lab,d0lab,cex=cex.d01)
        
      }
    }
    stats
  }
