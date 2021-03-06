% Generated by roxygen2 (4.1.1): do not edit by hand
% Please edit documentation in R/getBPMCnullmatrix.R
\name{getBPMCnullmatrix}
\alias{getBPMCnullmatrix}
\title{Generate Monte-Carlo null distributions for a list of beta-Poisson models}
\usage{
getBPMCnullmatrix(bp.model.list, fout = NULL, sim.num = 1000,
  useParallel = FALSE, cpu.num = 16, ran.num = 1e+05, E.esp = 0,
  tbreak.num = 10, useDebug = FALSE)
}
\arguments{
\item{bp.model.list}{List of beta-Poisson models that are results from \code{\link{estimateBPMatrix}} function}

\item{fout}{A *.RData file name to export results}

\item{sim.num}{A number of simulation of each model}

\item{useParallel}{An option for using parallel (=TRUE)}

\item{cpu.num}{The number of cpus if using parallel}

\item{ran.num}{The number of data points generated from the beta-Poisson model to approximate the theoretical model}

\item{E.esp}{An small value added to expected value when computing X2, E.esp=0.0 by default}

\item{tbreak.num}{Number of breaks for binning}

\item{useDebug}{A parameter setting of \code{\link{getBPMCnull}} function that is just used for debug and checking, so useDebug=FALSE by default}
}
\value{
A list of Monte-Carlo null distributions from the input models (MCdis.list) and setting values of parameters sim.num, ran.num and E.esp
}
\description{
Generate Monte-Carlo null distributions for a list of beta-Poisson models
}
\examples{
set.seed(2015)
#create random data matrix from a beta-poisson model
N=10
alp=sample(100,N,replace=TRUE)*0.1;
bet=sample(100,N,replace=TRUE)*0.1;
lam1=sample(100,N,replace=TRUE)*10;
lam2=sample(100,N,replace=TRUE)*0.01;
n=100
bp.mat=NULL
for (i in 1:N)
  bp.mat=rbind(bp.mat,rBP(n,alp=alp[i],bet=bet[i],lam1=lam1[i],lam2=lam2[i]))
#Estimate parameters from the data set
mat.res=estimateBPMatrix(bp.mat,para.num=4,fout=NULL,estIntPar=FALSE,useParallel=FALSE)
MCnullmatrix.res=getBPMCnullmatrix(bp.model.list=mat.res$bp.model.list,fout=NULL,
                                   sim.num=100,useParallel=FALSE)
#Get Monte-Carlo p-values
MC.pval=getMCpval(bp.model.list=mat.res$bp.model.list,
                  MCdis.list=MCnullmatrix.res$MCdis.list)
MC.pval
}

