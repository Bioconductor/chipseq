

## goal: model peak height distribution by negative binomial truncated
## at some height

library(chipseq)
library(latticeExtra)


dtnbinom <- function(k, size, mu, log = FALSE)
{
    const <- pnbinom(k - 0.5, size = size, mu = mu, lower.tail = FALSE, log.p = log)
    if (log)
        function(x)
        {
            ifelse(x < k, -Inf,
                   dnbinom(x, size = size, mu = mu, log = TRUE) - const)
        }
    else
        function(x)
        {
            ifelse(x < k, 0,
                   dnbinom(x, size = size, mu = mu, log = FALSE) / const)
        }
}


negllik <- function(data, cutoff = 8)
{
    data <- subset(data, depth >= cutoff)
    ## data = data.frame(depth = <peak height>, count = <number of peaks>) 
    function(size, mu)
    {
        dfun <- dtnbinom(k = cutoff, size = size, mu = mu, log = TRUE)
        with(data,
             -sum(count * dfun(depth)))
    }
}


startest <- function(data)
{
    ## naive: use untruncated dist
    mu <- with(data, sum(depth * count) / sum(count))
    ex2 <- with(data, sum(depth^2 * count) / sum(count))
    varx <- ex2 - mu^2
    size <- (varx - mu) / mu^2
    list(size = size, mu = mu)
}


islandDepthSummary <- function(x, g = extendReads(x))
{
    s <- slice(coverage(g, width = max(end(g))), lower = 1)
    tab <- table(viewMaxs(s))
    ans <- data.frame(depth = as.numeric(names(tab)), count = as.numeric(tab))
    ans
}

load("myodMyo.rda")

combinedMyo <-
    list(cblasts = combineLaneReads(myodMyo[c("1","3","6")]),
         ctubes = combineLaneReads(myodMyo[c("2","4","7")]))

combinedMyoDepth <-
    summarizeReads(combinedMyo, summary.fun = islandDepthSummary)

depthdist.split <-
    split(combinedMyoDepth,
          f = list(combinedMyoDepth$lane, combinedMyoDepth$chromosome))


estimatePars <- function(data, cutoff = 8, ...)
{
    minuslogl <- negllik(data = data, cutoff = cutoff)
    mle(minuslogl, start = startest(data), ...)
}

## estimatePars(depthdist.split$ctubes.chr6)

## estimatePars(subset(combinedMyoDepth, lane == "cblasts"))

## estimatePars(subset(combinedMyoDepth, lane == "ctubes"), cutoff = 5)@coef
## estimatePars(subset(combinedMyoDepth, lane == "ctubes"), cutoff = 6)@coef
## estimatePars(subset(combinedMyoDepth, lane == "ctubes"), cutoff = 7)@coef
## estimatePars(subset(combinedMyoDepth, lane == "ctubes"), cutoff = 8)@coef
## estimatePars(subset(combinedMyoDepth, lane == "ctubes"), cutoff = 9)@coef
## estimatePars(subset(combinedMyoDepth, lane == "ctubes"), cutoff = 10)@coef
## estimatePars(subset(combinedMyoDepth, lane == "ctubes"), cutoff = 11)@coef
## estimatePars(subset(combinedMyoDepth, lane == "ctubes"), cutoff = 12)@coef
## estimatePars(subset(combinedMyoDepth, lane == "ctubes"), cutoff = 13)@coef


## estimatePars(subset(combinedMyoDepth, lane == "cblasts"), cutoff = 5)@coef
## estimatePars(subset(combinedMyoDepth, lane == "cblasts"), cutoff = 6)@coef
## estimatePars(subset(combinedMyoDepth, lane == "cblasts"), cutoff = 7)@coef
## estimatePars(subset(combinedMyoDepth, lane == "cblasts"), cutoff = 8)@coef
## estimatePars(subset(combinedMyoDepth, lane == "cblasts"), cutoff = 9)@coef
## estimatePars(subset(combinedMyoDepth, lane == "cblasts"), cutoff = 10)@coef
## estimatePars(subset(combinedMyoDepth, lane == "cblasts"), cutoff = 11)@coef
## estimatePars(subset(combinedMyoDepth, lane == "cblasts"), cutoff = 12)@coef
## estimatePars(subset(combinedMyoDepth, lane == "cblasts"), cutoff = 13)@coef



collapseChr <- function(data)
{
    tab <- xtabs(count ~ depth, data)
    data.frame(depth = as.numeric(names(tab)),
               count = as.numeric(tab))
}


mycutoff <- 10
subdata <- collapseChr(subset(combinedMyoDepth, lane == "ctubes"))
foo <- estimatePars(subdata, cutoff = mycutoff)


dfun <-
    dtnbinom(k = 10,
             size = coef(foo)["size"],
             mu = coef(foo)["mu"],
             log = FALSE)

rootogram(count ~ depth,
          data = subdata,
          subset = depth >= 10,
          dfun = dfun,
          xlim = c(0, 100))




