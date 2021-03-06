% Generated by roxygen2 (4.1.1): do not edit by hand
% Please edit documentation in R/estimateBPMatrix.R
\name{estimateBPMatrix}
\alias{estimateBPMatrix}
\title{Estimate parameters of beta-Poisson models for a data matrix}
\usage{
estimateBPMatrix(dataMat, para.num = 4, tbreak.num = 10, fout = NULL,
  break.thres = 10, estIntPar = TRUE, extreme.quant = NULL,
  useExt = FALSE, min.exp = 1e-04, useParallel = FALSE)
}
\arguments{
\item{dataMat}{Data matrix that needs to be modelled}

\item{para.num}{Mode of beta-Poisson model: 3, 4 (default) or 5 parameters}

\item{tbreak.num}{Number of breaks for binning}

\item{fout}{A *.RData file name to export results}

\item{break.thres}{A parameter setting of \code{\link{getTbreak}} function}

\item{estIntPar}{An option to allow estimating initial parameters for the model from only expressed values}

\item{extreme.quant}{A quantile probability to remove extrem values (outliers) higher than the quantile. If extreme.quant=NULL, no elimination of outliers is done}

\item{useExt}{A parameter setting of \code{\link{getTbreak}} function that allows to extend the last bin to infinity or not}

\item{min.exp}{A threshold for minimum expressed values. If a expression is less than min.exp, it is set to be zero}

\item{useParallel}{An option to allow using parallel computing}
}
\value{
A list of optimal models corresponding to the rows of the matrix. Each model consists of optimal parameters, X2 test results (X2 and PVAL), etc..
}
\description{
Estimate parameters of beta-Poisson models for a data matrix
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
#In this function, user can also set estIntPar=TRUE to have better estimated beta-Poisson
#models for the generalized linear model. However, a longer computational time is required.
}

