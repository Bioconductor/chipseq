
library("chipseq")

if (file.exists("alignInfo.rda")) load("alignInfo.rda") else
{

    library("BSgenome.Mmusculus.UCSC.mm9")

    ##lanes 1, 3, 6 are Myoblasts
    ##lanes 2, 4, 7 are Myotubes
    ##lane 8 is a reference lane

    lanes <- c(1, 2, 3, 4, 6, 7, 8)

    reads = vector("list", length = length(lanes))
    names(reads) = as.character(lanes)

    for (i in seq_along(lanes) ) {
        lane <- lanes[i]
        message("Starting Lane ", lane)
        pat <- paste("s_", lane, ".map", sep="")
        ## we drop the sex chromosomes and mitochondria.
        reads[[i]] <- readAndClean("/home/jdavison/ycao/26-06-2008/binary",
                                   pattern = pat, exclude = "[MXY]|rand")
    }

    lreads <- lapply(reads, as.list) # same info (no quality etc) as nested list

    ## mouse has 19 chromosomes

    chrom.list <- paste("chr", c(1:19), sep = "")

    ## nchrom <- length(chrom.list)
    ## chromLens = rep(NA, nchrom)
    ## names(chromLens) = chrom.list
    ## for( i in 1:nchrom) 
    ##     chromLens[i] = nchar(unmasked(Mmusculus[[chrom.list[i]]])) 

    chromLens <-
        sapply(chrom.list,
               function(chr) {
                   nchar(unmasked(Mmusculus[[chr]]))
                   ## same as 'length(Mmusculus[[chr]])' ?
               },
               simplify = TRUE)


    save(lreads, chromLens, file = "alignInfo.rda")

    ## system.time(seqRanges.old <- lapply(reads, extendReads), gcFirst=TRUE)
} 


## basically same, but retains order of chromosomes
system.time(seqRanges <- lapply(lreads, extendReads), gcFirst=TRUE)

cblasts = combineLanes(seqRanges[c(1,3,5)])
ctubes = combineLanes(seqRanges[c(2,4,6)])


## GOALS:

## Background: Suppose all reads could be represented by a point that
## is "close" to the underlying binding site (this could be the center
## of our extended intervals).  Without loss of generality, the
## locations of these points could be modeled as a non-uniform Poisson
## process.  Comparisons between lanes (or unions of lanes), say lane
## A and lane B, could be viewed as the null hypothesis that the
## intensities of the corresponding processes are multiples of each
## other (the constant factor c reflecting differences in the overall
## number of reads).  In this situation, suppose we had an interval I
## where A had exactly k points.  Then conditional on I, the number of
## points in I from B would be Poisson(c * |I|), where |I| is some
## measure of the length of I.  The unconditional distribution would
## be a Poisson mixture over the distribution of |I|, which would
## hopefully depend only on k and not the unknown Poisson process
## intensity.

## Anyway, so one pseudo-logical choice of I is as follows: within
## each ``island'', choose the shortest interval covering k reads.

## We are doing things in terms of islands, not point estimates.  In
## terms of coverage x on an island, viewSums(x) / 200L gives the
## number of reads in the island.  For now, we will assume this is
## also approximately true (and meaningful) for parts of an island.
## So we could think of finding shortest subintervals in an island so
## that viewSums(x) / 200L is close to k.  We would then count
## viewSums(x) for the other lane.

## For now, we won't even do that.  We will just slice coverage of A
## at k, and for the resulting "peaks", do viewSums() on both A and B.
## We can then think of the values on A as predictor and those on B as
## response, and maybe come up with some sort of variance model.

covblasts = laneCoverage(cblasts[1:4], chromLens)
covtubes = laneCoverage(ctubes[1:4], chromLens)
covctrl = laneCoverage(seqRanges[["8"]][1:4], chromLens)


## coverage() is potentially memory intensive

if (file.exists("peakSummary.rda")) load("peakSummary.rda") else
{

    ref.peaks <- lapply(covtubes, slice, lower = 10)
    ref.peaks.in.blasts <-
        copyIRangesbyChr(ref.peaks, covblasts)
    ref.peaks.in.ctrl <-
        copyIRangesbyChr(ref.peaks, covctrl)


    ## Switch roles (ref vs response).  Beware of wrong column names
    if (FALSE)
    {
        ref.peaks <- lapply(covblasts, slice, lower = 10)
        ref.peaks.in.blasts <-
            copyIRangesbyChr(ref.peaks, covtubes)
        ref.peaks.in.ctrl <-
            copyIRangesbyChr(ref.peaks, covctrl)
    }


    peakSummary <-
        do.call(make.groups,
                sapply(names(ref.peaks),
                       function(chr) {
                           data.frame(start = start(ref.peaks[[chr]]),
                                      end = end(ref.peaks[[chr]]),
                                      reads.tubes = viewSums(ref.peaks[[chr]]) / 200,
                                      reads.blasts = viewSums(ref.peaks.in.blasts[[chr]]) / 200,
                                      reads.ctrl = viewSums(ref.peaks.in.ctrl[[chr]]) / 200)
                       },
                       simplify = FALSE))
    names(peakSummary)[names(peakSummary) == "which"] <- "chromosome"


    save(peakSummary, file = "peakSummary.rda")
}


xyplot(sqrt(reads.blasts) + sqrt(3 * reads.ctrl) ~ sqrt(reads.tubes) | chromosome,
       data = peakSummary, auto.key = TRUE,
       subset = chromosome %in% c("chr1", "chr2", "chr3", "chr4"),
       par.settings = simpleTheme(pch = 16, alpha = 0.4),
       type = c("p", "g", "r"), col.line = "black", aspect = "iso")


xyplot(sqrt(reads.blasts) ~ sqrt(reads.tubes) | chromosome,
       data = peakSummary, auto.key = TRUE,
       subset = (chromosome %in% c("chr1", "chr2", "chr3", "chr4") &
                 reads.ctrl < quantile(reads.ctrl, 0.99)),
       par.settings = simpleTheme(pch = ".", cex = 3),
       type = c("p", "g", "r"), col.line = "black", aspect = "iso")


xyplot(log2(1+reads.blasts) ~ log2(1+reads.tubes) | chromosome,
       data = peakSummary, auto.key = TRUE,
       subset = (chromosome %in% c("chr1", "chr2", "chr3", "chr4") &
                 reads.ctrl < quantile(reads.ctrl, 0.99)),
       par.settings = simpleTheme(pch = ".", cex = 3),
       type = c("p", "g", "r"), col.line = "black", aspect = "iso")


## Naive regression: y|x ~ Poisson(cx), i.e., mean=cx, variance=cx.
## We fit a model with y ~ 0 + x with
## weights=1/sqrt(variance)=1/sqrt(x).  This ignores that Poisson has
## no scale factor to estimate, but we probably have some variance
## inflation anyway.  The other option, of course, is to use glm().
## UPDATE: the proper weights seem to be 1/x, even with sqrt(y) as the
## response.

peakSummary.lm <- 
    within(peakSummary,
       {
           fm <- lm(sqrt(reads.blasts) ~ 0 + chromosome:sqrt(reads.tubes),
                    weights = 1/reads.tubes)
           ## print(summary(fm))
           pred.blasts <- predict(fm)
           resid.blasts <- residuals(fm, type = "deviance")
           rstandard.blasts <- rstandard(fm)
           rstudent.blasts <- rstudent(fm)
           rm(fm)
       })

xyplot(resid.blasts ~ log2(reads.tubes) | chromosome,
       data = peakSummary.lm, auto.key = TRUE,
       subset = (chromosome %in% c("chr1", "chr2", "chr3", "chr4")),
       par.settings = simpleTheme(pch = ".", cex = 3),
       type = c("p", "g", "smooth"), col.line = "black")

xyplot(abs(resid.blasts) ~ log2(reads.tubes) | chromosome,
       data = peakSummary.lm, auto.key = TRUE,
       subset = (chromosome %in% c("chr1", "chr2", "chr3", "chr4")),
       par.settings = simpleTheme(pch = ".", cex = 3),
       type = c("p", "g", "smooth"), col.line = "black")

qqmath(~resid.blasts | chromosome,
       data = peakSummary.lm, 
       subset = (chromosome %in% c("chr1", "chr2", "chr3", "chr4")),
       par.settings = simpleTheme(pch = ".", cex = 3),
       panel = function(...) {
           panel.abline(0, 1)
           panel.qqmath(...)
       },
       type = c("p", "g"), col.line = "black", aspect = "iso")

bwplot(chromosome ~ resid.blasts, data = peakSummary.lm)


## library(robustbase)

## A desirable alternative is robust regression, but lmrob in
## robustbase doesn't seem to handle weights.  The log2 responses seem
## reasoanbly homoskedastic.  


xyplot(abs(log2(reads.blasts)-log2(reads.tubes)) ~ log2(reads.tubes) | chromosome,
       data = peakSummary.lm, auto.key = TRUE,
       subset = (chromosome %in% c("chr1", "chr2", "chr3", "chr4")),
       par.settings = simpleTheme(pch = ".", cex = 3),
       type = c("p", "g", "smooth"), col.line = "black")

## Our model of y ~ c.x translates to log(y) ~ log(c) + log(x), so all
## we need to do is estimate log(c). A robust estimate is
## median(log(y)-log(x)).  So residuals are
##  [ (log(y)-log(x)) - median(log(y)-log(x)) ]


peakSummary.rob <- 
    within(peakSummary,
       {
           diffs <- log2(reads.blasts)-log2(reads.tubes)
           resids <-  # prefer per-chromosome?
               (diffs - median(diffs)) / mad(diffs)
           resids.mean <- diffs - mean(diffs[is.finite(diffs)])
       })

median(peakSummary.rob$diffs)

2^median(peakSummary.rob$diffs)
sum(sapply(cblasts, length)) / sum(sapply(ctubes, length))

xyplot(resids ~ log2(reads.tubes) | chromosome,
       data = peakSummary.rob, auto.key = TRUE,
       subset = (chromosome %in% c("chr1", "chr2", "chr3", "chr4")),
       par.settings = simpleTheme(pch = ".", cex = 3),
       type = c("p", "g", "smooth"), col.line = "black")


xyplot(abs(resids) ~ log2(reads.tubes) | chromosome,
       data = peakSummary.rob, auto.key = TRUE,
       subset = (chromosome %in% c("chr1", "chr2", "chr3", "chr4")),
       par.settings = simpleTheme(pch = ".", cex = 3),
       type = c("p", "g", "smooth"), col.line = "black")

qqmath(~resids | chromosome,
       data = peakSummary.rob, 
       subset = (chromosome %in% c("chr1", "chr2", "chr3", "chr4")),
       par.settings = simpleTheme(pch = ".", cex = 3),
       panel = function(...) {
           panel.abline(0, 1)
           panel.qqmath(...)
       },
       type = c("p", "g"), col.line = "black", aspect = "iso")

bwplot(chromosome ~ resids, data = peakSummary.rob)

toppeaks <- subset(peakSummary.rob, abs(resids) > 4)
rownames(toppeaks) <- NULL
toppeaks[rev(order(abs(toppeaks$resids))), 1:6]



