#' Generalized linear model for four-parameter beta-Possion model
#'
#' @param data Input data matrix for differential expression analysis
#' @param controlIds Indicies of control group
#' @param design Design matrix for glm fitting
#' @param coef An integer to point out the column index corresponding to the coefficient for the GLM model testing. This should be specified by users. Default value is 2
#' @param keepFit An option to keep fit results when the input dataset is small (keepFit=TRUE). Otherwise, keepFit=FALSE by default
#' @param minExp A threshold for minimum expressed values. If a expression is less than minExp, it is set to be zero
#' @param tbreak.num Number of breaks for binning
#' @param break.thres The threshold to decide whether use breaks from logs cale or not. We decide to use breaks from log scale if 75 percent of input data less than this threshold
#' @param estIntPar An option to allow estimating initial parameters for the model from only expressed values
#' @param useExt A parameter setting of getTbreak function that allows to extend the last bin to infinity or not
#' @param extreme.quant A quantile probability to remove extrem values (outliers) higher than the quantile. If extreme.quant=NULL, no elimination of outliers is done
#' @param useParallel An option to allow using parallel computing
#' @return A list of p-values, statistics, indicies, a list of fitting models (if keepFit=TRUE), etc
#' @export
#' @importFrom doParallel registerDoParallel
#' @importFrom foreach foreach
#' @importFrom foreach %dopar%
#' @examples
#' library("BPSC")
#' set.seed(2015)
#' ###Generate a random data matrix from a beta-poisson model
#' #Set the number of genes
#' N=100
#' #Generate randomly the parameters of BP models
#' alp=sample(100,N,replace=TRUE)*0.1;
#' bet=sample(100,N,replace=TRUE)*0.1;
#' lam1=sample(100,N,replace=TRUE)*10;
#' lam2=sample(100,N,replace=TRUE)*0.01
#' #Generate a control group
#' n1=100
#' control.mat=NULL
#' for (i in 1:N) control.mat=rbind(control.mat,rBP(n1,alp=alp[i],
    #' bet=bet[i],lam1=lam1[i],lam2=lam2[i]))
#' #To create biological variation, we randomly set 10% as differentially expressed genes 
#' #by simply replacing the parameter lam1 in treated group by a fold-change fc
#' DE.ids= sample(N,N*0.1)
#' fc=2.0
#' lam1[DE.ids]=lam1[DE.ids] * fc
#' #Generate a treated group
#' n2=100
#' treated.mat=NULL
#' for (i in 1:N)treated.mat=rbind(treated.mat,rBP(n2,alp=alp[i],
    #' bet=bet[i],lam1=lam1[i],lam2=lam2[i]))
#' #Create a data set by merging the control group and the treated group
#' bp.mat=cbind(control.mat,treated.mat)
#' rownames(bp.mat)=c(1:nrow(bp.mat));
#' colnames(bp.mat)=c(1:ncol(bp.mat))
#' group=c(rep(1,ncol(control.mat)),rep(2,ncol(treated.mat)))
#' 
#' #First, choose IDs of all cells of the control group for estimating parameters of BP models
#' controlIds=which(group==1)
#' #Create a design matrix including the group labels. 
#' #All batch effects can be also added here if they are available
#' design=model.matrix(~group) 
#' #Select the column in the design matrix corresponding to 
#' #the coefficient (the group label) for the GLM model testing
#' coef=2 
#' #Run BPglm for differential expression analysis
#' res=BPglm(data=bp.mat, controlIds=controlIds, design=design, coef=coef, estIntPar=FALSE) 
#' #In this function, user can also set estIntPar=TRUE to have better estimated beta-Poisson 
#' #models for the generalized linear model. However, a longer computational time is required.
#' 
#' #Plot the p-value distribution
#' hist(res$PVAL, breaks=20)
#' #Summarize the resutls
#' ss=summary(res)
#' #Compare the discovered DE genes and the true DE genes predefined beforeward
#' fdr=p.adjust(res$PVAL, method="BH")
#' bpglm.DE.ids=which(fdr<=0.05)
#' #Print the indices of the true DE genes:
#' cat(sort(DE.ids))
#' #Print the indices of the DE genes discovered by BPglm:
#' cat(sort(bpglm.DE.ids))
BPglm <- function (data, controlIds, design, coef=2, keepFit=FALSE,minExp=1e-4, tbreak.num=10, break.thres=10,estIntPar=FALSE, useExt=FALSE, extreme.quant=NULL,useParallel=FALSE) 
{    
    if (useParallel){
    fitRes=ind=TVAL=PVAL=NULL;
    fitRes=foreach(i=1:nrow(data),.combine=c) %dopar% {
        fit=NA
        i.pval=NA
        i.tval=NA
        i.converged=NA
        i.bpconverged=NA
        oo4=NA
        par=NA

        x=data[i,]
        #check if data is weird
        gvar=tapply(x,design[,coef],var)
        lowvar=sapply(gvar, function(z) sum(z<0.1*gvar))
        isNearZeroVariance=sum(lowvar>0)>0

        if (!isNearZeroVariance){
            control.x=x[controlIds]
            bpstat=control.x
            if (!is.null(extreme.quant)) bpstat=control.x[control.x <= quantile(control.x,prob=extreme.quant)]         
            bpstat[bpstat<minExp]=0

            par=getInitParam(bpstat,para.num=4)
            if (sum(bpstat>0) > 0.05*length(bpstat)){
                ##### beta-Poisson estimation for control group
                oo4=estimateBP(bpstat,para.num=4,tbreak.num=tbreak.num,break.thres=break.thres)

                if (estIntPar){
                    bpstat2=bpstat[bpstat>0]
                    mypar=getInitParam(bpstat2,para.num=4)
                    oo.tmp=estimateBP(bpstat2,para.num=4,tbreak.num=tbreak.num,break.thres=break.thres,useExt=useExt,param0=mypar)                
                    if (!is.na(oo.tmp$PVAL)) mypar=oo.tmp$par
                    oo4e=estimateBP(bpstat,para.num=4,tbreak.num=tbreak.num,break.thres=break.thres,useExt=useExt,param0=mypar)
                    # select the better model
                    if (is.na(oo4$PVAL)) oo4=oo4e
                    else {
                        if (!is.na(oo4e$PVAL) && oo4e$PVAL > oo4$PVAL && oo4e$X2>=0) oo4=oo4e              
                    }

                }
                par=oo4$par
            }

            ##### start GLM
            fdat=data.frame(x=x,design[,-1])
            colnames(fdat)=c("x",colnames(design)[-1])

            try({
                alp=par[1];bet=par[2];lam1=par[3];lam2=par[4]
                fam0=do.call("BPfam", list(alp=alp, bet=bet, lam1=lam1, lam2=lam2, link = "log"))

                fit=glm(x~.,data=fdat,family=fam0)
                i.pval=summary(fit)$coefficients[coef,4]
                i.tval=summary(fit)$coefficients[coef,3]
                i.bpconverged=fit$converged
                ##### if the fitting is not converged, use quassipoisson
                i.converged=i.bpconverged
                if (!i.converged){
                    fit=glm(x~.,data=fdat,family=quasipoisson)
                    i.pval=summary(fit)$coefficients[coef,4]
                    i.tval=summary(fit)$coefficients[coef,3]
                    i.converged=fit$converged
                }            
            }, silent=TRUE) # keep silent if errors occur
        }

        # Modification: if the fitting is not converged or all samples of one group are all unexpressed, use t.test with unequal variance or Analysis of Variance
        if (isNearZeroVariance) i.pval=NA
        if(is.na(i.pval)) {
            design_group=design
            colnames(design_group)[coef]="group"
            fdat_norm=data.frame(x=log2(x+1))
            fdat_norm=cbind(fdat_norm,design_group)
            fdat_norm=fdat_norm[,-2] #remove intercept
            #fit=lm(group~.,data=fdat_norm)
            #i.pval=summary(fit)$coefficients[2,4]
            #i.tval=summary(fit)$coefficients[2,3]
            #i.converged=NA #no information
            gNum=length(unique(fdat_norm$group))
            if (gNum==2){ #use t-test
                gtest=t.test(x ~ group,data=fdat_norm)
                i.pval=gtest$p.value
                i.tval=gtest$statistic
                i.converged=NA #no information
            }else{ #use aov
                gtest=aov(x ~ group,data=fdat_norm)
                i.pval=summary(gtest)[[1]][["Pr(>F)"]][1]
                i.tval=summary(gtest)[[1]][["F value"]][1]
                i.converged=NA #no information
            }
            #i.pval = t.test(x ~ group)$p.value
        }
        # End modification

        res=list();
        res[["PVAL"]]=i.pval
        res[["TVAL"]]=i.tval
        res[["CONVERGED"]]=i.converged
        res[["BPCONVERGED"]]=i.bpconverged
        res[["ind"]]=i        
        if(keepFit) res[["fit"]]=fit else res[["fit"]]=NA
        res[["par"]]=par;
        res[["oo4"]]=oo4;
        
        res
    } # end of foreach

    }else{
    fitRes=ind=TVAL=PVAL=NULL;
    for (i in 1:nrow(data)){            
        fit=NA
        i.pval=NA
        i.tval=NA
        i.converged=NA
        i.bpconverged=NA
        oo4=NA
        par=NA

        x=data[i,]
        #check if data is weird
        gvar=tapply(x,design[,coef],var)
        lowvar=sapply(gvar, function(z) sum(z<0.1*gvar))
        isNearZeroVariance=sum(lowvar>0)>0

        if (!isNearZeroVariance){
            control.x=x[controlIds]
            bpstat=control.x
            if (!is.null(extreme.quant)) bpstat=control.x[control.x <= quantile(control.x,prob=extreme.quant)]         
            bpstat[bpstat<minExp]=0
            par=getInitParam(bpstat,para.num=4)
            if (sum(bpstat>0) > 0.05*length(bpstat)){
                ##### beta-Poisson estimation for control group
                oo4=estimateBP(bpstat,para.num=4,tbreak.num=tbreak.num,break.thres=break.thres)

                if (estIntPar){
                    bpstat2=bpstat[bpstat>0]
                    mypar=getInitParam(bpstat2,para.num=4)
                    oo.tmp=estimateBP(bpstat2,para.num=4,tbreak.num=tbreak.num,break.thres=break.thres,useExt=useExt,param0=mypar)
                    if (!is.na(oo.tmp$PVAL)) mypar=oo.tmp$par
                    oo4e=estimateBP(bpstat,para.num=4,tbreak.num=tbreak.num,break.thres=break.thres,useExt=useExt,param0=mypar)
                    # select the better model
                    if (is.na(oo4$PVAL)) oo4=oo4e
                    else {
                        if (!is.na(oo4e$PVAL) && oo4e$PVAL > oo4$PVAL && oo4e$X2>=0) oo4=oo4e              
                    }
                }
                par=oo4$par
            }
            ##### start GLM
            fdat=data.frame(x=x,design[,-1])
            colnames(fdat)=c("x",colnames(design)[-1])

            try({
                alp=par[1];bet=par[2];lam1=par[3];lam2=par[4]            
                fam0=do.call("BPfam", list(alp=alp, bet=bet, lam1=lam1, lam2=lam2, link = "log"))
                
                fit=glm(x~.,data=fdat,family=fam0)
                i.pval=summary(fit)$coefficients[coef,4]
                i.tval=summary(fit)$coefficients[coef,3]
                i.bpconverged=fit$converged
                ##### if the fitting is not converged, use quassipoisson
                i.converged=i.bpconverged
                if (!i.converged){
                    fit=glm(x~.,data=fdat,family=quasipoisson)
                    i.pval=summary(fit)$coefficients[coef,4]
                    i.tval=summary(fit)$coefficients[coef,3]
                    i.converged=fit$converged
                }
            }, silent=TRUE) # keep silent if errors occur
        }

        # Modification: if the fitting is not converged or all samples of one group are all unexpressed, use t.test with unequal variance or Analysis of Variance
        if (isNearZeroVariance) i.pval=NA
        if(is.na(i.pval)) {
            design_group=design
            colnames(design_group)[coef]="group"
            fdat_norm=data.frame(x=log2(x+1))
            fdat_norm=cbind(fdat_norm,design_group)
            fdat_norm=fdat_norm[,-2] #remove intercept
            #fit=lm(group~.,data=fdat_norm)
            #i.pval=summary(fit)$coefficients[2,4]
            #i.tval=summary(fit)$coefficients[2,3]
            #i.converged=NA #no information
            gNum=length(unique(fdat_norm$group))
            if (gNum==2){ #use t-test
                gtest=t.test(x ~ group,data=fdat_norm)
                i.pval=gtest$p.value
                i.tval=gtest$statistic
                i.converged=NA #no information
            }else{ #use aov
                gtest=aov(x ~ group,data=fdat_norm)
                i.pval=summary(gtest)[[1]][["Pr(>F)"]][1]
                i.tval=summary(gtest)[[1]][["F value"]][1]
                i.converged=NA #no information
            }
            #i.pval = t.test(x ~ group)$p.value
        }
        # End modification    
    res=list();            
    res[["PVAL"]]=i.pval
    res[["TVAL"]]=i.tval
    res[["CONVERGED"]]=i.converged
    res[["BPCONVERGED"]]=i.bpconverged
    res[["ind"]]=i
    if(keepFit) res[["fit"]]=fit else res[["fit"]]=NA
    res[["par"]]=par;
    res[["oo4"]]=oo4;

    fitRes=c(fitRes,res)            
    }
    }

    ind=unlist(fitRes[which(names(fitRes)=="ind")])
    names(ind)=rownames(data)
    PVAL=unlist(fitRes[which(names(fitRes)=="PVAL")])
    names(PVAL)=rownames(data)
    TVAL=unlist(fitRes[which(names(fitRes)=="TVAL")])
    names(TVAL)=rownames(data)
    CONVERGED=unlist(fitRes[which(names(fitRes)=="CONVERGED")])
    names(CONVERGED)=rownames(data)
    PVAL[which(!CONVERGED)]=NA
    TVAL[which(!CONVERGED)]=NA
    
    res=list(PVAL=PVAL,TVAL=TVAL,ind=ind,fitRes=fitRes,keepFit=keepFit,coef=coef)
    class(res) <- "BPglm"
    return(res)
}