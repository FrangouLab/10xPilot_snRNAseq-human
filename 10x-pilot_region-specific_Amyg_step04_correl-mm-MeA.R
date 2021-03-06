### MNT 10x snRNA-seq workflow: step 04 - downstream comparisons
###   **Region-specific analyses**
###     - (3x) NAc samples from: Br5161 & Br5212 & Br5287
###   * Comparison to UCLA's Drop-seq on mouse medial amyg (MeA)
#####################################################################

library(SingleCellExperiment)
library(EnsDb.Hsapiens.v86)
library(org.Hs.eg.db)
library(scater)
library(scran)
library(batchelor)
library(DropletUtils)
library(jaffelab)
library(limma)
library(lattice)
library(RColorBrewer)
library(pheatmap)

### Palette taken from `scater`
tableau10medium = c("#729ECE", "#FF9E4A", "#67BF5C", "#ED665D",
                    "#AD8BC9", "#A8786E", "#ED97CA", "#A2A2A2",
                    "#CDCC5D", "#6DCCDA")
tableau20 = c("#1F77B4", "#AEC7E8", "#FF7F0E", "#FFBB78", "#2CA02C",
              "#98DF8A", "#D62728", "#FF9896", "#9467BD", "#C5B0D5",
              "#8C564B", "#C49C94", "#E377C2", "#F7B6D2", "#7F7F7F",
              "#C7C7C7", "#BCBD22", "#DBDB8D", "#17BECF", "#9EDAE5")

# ===

### Pseudobulk>modeling approach ============================================
  # * Skip this -> Now using sn-level stats for this comparison

## load modeling outputs
# 10x-pilot human Amyg
load("/dcl01/lieber/ajaffe/Matt/MNT_thesis/snRNAseq/10x_pilot_FINAL/rdas/markers-stats_Amyg-n2_manualContrasts_MNTMar2020.rda", verbose=T)
    # eb_contrasts.amy.broad, eb_list.amy.broad, sce.amy.PB

# UCLA mouse MeA Drop-seq
load("/dcl01/ajaffe/data/lab/singleCell/ucla_mouse-MeA/markers-stats_mouse-MeA-Drop-seq_manualContrasts_MNTApr2020.rda", verbose=T)
    # eb_list.amy.mm, corfit.amy.mm, sce.amy.mm.PB


# Add EntrezID for human
hs.entrezIds <- mapIds(org.Hs.eg.db, keys=rowData(sce.amy.PB)$ID, 
                       column="ENTREZID", keytype="ENSEMBL")
# "'select()' returned 1:many mapping between keys and columns"
table(!is.na(hs.entrezIds))
    # 20,578 valid entries (remember this is already subsetted for those non-zero genes only)

# Add to rowData
rowData(sce.amy.PB) <- cbind(rowData(sce.amy.PB), hs.entrezIds)


## Bring in 'HomoloGene.ID' for human (already in rowData for mm SCE) ===
## JAX annotation info
hom = read.delim("http://www.informatics.jax.org/downloads/reports/HOM_AllOrganism.rpt",
                 as.is=TRUE)

hom_hs <- hom[hom$Common.Organism.Name == "human", ]
    # of 19,124 entries
table(rowData(sce.amy.PB)$hs.entrezIds %in% hom_hs$EntrezGene.ID)
    # 17,261
table(rowData(sce.amy.PB)$Symbol %in% hom_hs$Symbol)
    # 16,916 - not a bad difference

        # So for mapping === == === ===
        # human.entrez > HomoloGene.ID < mm.Symbol
        #                ^ filter SCE's on this

# Human (by Entrez)
rowData(sce.amy.PB)$HomoloGene.ID <- hom_hs$HomoloGene.ID[match(rowData(sce.amy.PB)$hs.entrezIds,
                                                                 hom_hs$EntrezGene.ID)]


## Now set/match to shared homologous genes ===

length(intersect(rowData(sce.amy.PB)$HomoloGene.ID,
                 rowData(sce.amy.mm.PB)$HomoloGene.ID))  # 13,444

sharedHomologs <- intersect(rowData(sce.amy.PB)$HomoloGene.ID,
                            rowData(sce.amy.mm.PB)$HomoloGene.ID)
# # That first one is NA - get rid of it
# sharedHomologs <- sharedHomologs[-1]

# Human not in mm
length(setdiff(rowData(sce.amy.PB)$HomoloGene.ID,
                 rowData(sce.amy.mm.PB)$HomoloGene.ID))  # 3657
# mm not in human
length(setdiff(rowData(sce.amy.mm.PB)$HomoloGene.ID,
               rowData(sce.amy.PB)$HomoloGene.ID))  # 928


# Subset for those
sce.mm.PBsub <- sce.amy.mm.PB[rowData(sce.amy.mm.PB)$HomoloGene.ID %in% sharedHomologs, ]   # 14247
sce.hsap.PBsub <- sce.amy.PB[rowData(sce.amy.PB)$HomoloGene.ID %in% sharedHomologs, ]  # 14178
    ## Many are duplicated...

rowData(sce.mm.PBsub)$Symbol[duplicated(rowData(sce.mm.PBsub)$HomoloGene.ID)]
    # shoot many genes are orthologs
rowData(sce.hsap.PBsub)$Symbol[duplicated(rowData(sce.hsap.PBsub)$HomoloGene.ID)]
    # same here, slightly less


### -> Take the higher-expressing of the duplicated - just mean across PB clusters:

    ## mm ===
    duplicatedSet.mm <- which(duplicated(rowData(sce.mm.PBsub)$HomoloGene.ID))
    genes2compare.mm <- list()
    gene2keep.mm <- character()
    for(g in 1:length(duplicatedSet.mm)){
      genes2compare.mm[[g]] <- rownames(sce.mm.PBsub)[rowData(sce.mm.PBsub)$HomoloGene.ID ==
                                              rowData(sce.mm.PBsub)$HomoloGene.ID[duplicatedSet.mm[g]]]
      rowmeansmat <- rowMeans(assay(sce.mm.PBsub[genes2compare.mm[[g]], ], "logcounts"))
      gene2keep.mm[g] <- names(rowmeansmat[order(rowmeansmat, decreasing=TRUE)])[1]
    }
    
    # Now pull out those that not being compared, so can `c()`
    table(rownames(sce.mm.PBsub) %in% unlist(genes2compare.mm)) # 133   - why isn't this ==
    sum(lengths(genes2compare.mm))                               # 328 ????
    length(unique(unlist(genes2compare.mm))) # 133   - oh. also `length(unique(gene2keep.mm)) == 52`
    
    genesNoCompare.mm <- rownames(sce.mm.PBsub)[!(rownames(sce.mm.PBsub) %in% unlist(genes2compare.mm))]
    
    # Finally combine and subset
    sce.mm.PBsub <- sce.mm.PBsub[c(genesNoCompare.mm, unique(gene2keep.mm)), ]
    
    table(rowData(sce.mm.PBsub)$HomoloGene.ID %in% sharedHomologs) # 13444 TRUE
    table(duplicated(rowData(sce.mm.PBsub)$HomoloGene.ID)) # 13444 FALSE         dope.

    
    ## Human ===
    # First change rownames to EnsemblID
    rowData(sce.hsap.PBsub)$Symbol.unique <- rownames(sce.hsap.PBsub)
    rownames(sce.hsap.PBsub) <- rowData(sce.hsap.PBsub)$ID
        
    duplicatedSet.hsap <- which(duplicated(rowData(sce.hsap.PBsub)$HomoloGene.ID))
    genes2compare.hsap <- list()
    gene2keep.hsap <- character()
    for(g in 1:length(duplicatedSet.hsap)){
      genes2compare.hsap[[g]] <- rownames(sce.hsap.PBsub)[rowData(sce.hsap.PBsub)$HomoloGene.ID ==
                                                          rowData(sce.hsap.PBsub)$HomoloGene.ID[duplicatedSet.hsap[g]]]
      rowmeansmat <- rowMeans(assay(sce.hsap.PBsub[genes2compare.hsap[[g]], ], "logcounts"))
      gene2keep.hsap[g] <- names(rowmeansmat[order(rowmeansmat, decreasing=TRUE)])[1]
    }
    
    # Now pull out those that not being compared, so can `c()`
    table(rownames(sce.hsap.PBsub) %in% unlist(genes2compare.hsap)) # 109   - why isn't this ==
    sum(lengths(genes2compare.hsap))                               # 136 ????
    length(unique(unlist(genes2compare.hsap))) # 109   - oh. also `length(unique(gene2keep.hsap)) == 52`
    
    genesNoCompare.hsap <- rownames(sce.hsap.PBsub)[!(rownames(sce.hsap.PBsub) %in% unlist(genes2compare.hsap))]
        # of length 13392 (which + 52 == 13444)
    
    # Finally combine and subset
    sce.hsap.PBsub <- sce.hsap.PBsub[c(genesNoCompare.hsap, unique(gene2keep.hsap)), ]
    
    table(rowData(sce.hsap.PBsub)$HomoloGene.ID %in% sharedHomologs) # 13444 TRUE
    table(duplicated(rowData(sce.hsap.PBsub)$HomoloGene.ID)) # 13444 FALSE         dope.


    ## Match order and save
    sce.mm.PBsub <- sce.mm.PBsub[match(rowData(sce.hsap.PBsub)$HomoloGene.ID,
                                   rowData(sce.mm.PBsub)$HomoloGene.ID), ]

    table(rowData(sce.mm.PBsub)$HomoloGene.ID == rowData(sce.hsap.PBsub)$HomoloGene.ID)
        # all TRUE - good
    pheatmap(cor(assay(sce.mm.PBsub, "logcounts"), assay(sce.hsap.PBsub, "logcounts")), fontsize=5)
        # (ah but this is at the sample:cluster level)
    
    Readme <- "These two SCEs are subsetted and ordered for matching HomoloGene.ID in the rowData. This can be used to subset the nucleus-level SCEs in their respective Rdata files."
    save(sce.mm.PBsub, sce.hsap.PBsub, Readme, file="/dcl01/ajaffe/data/lab/singleCell/ucla_mouse-MeA/SCE_mm-MeA-PBd_w_matchingHsap-Amyg-PBd_HomoloGene.IDs_MNT.rda")
    
    
    
### FINALLY resume comparisons === === === === ===

## mm stats
pvals_mm <- sapply(eb_list.amy.mm, function(x) {
  x$p.value[, 2, drop = FALSE]
})
rownames(pvals_mm) = rownames(sce.amy.mm.PB)

ts_mm <- sapply(eb_list.amy.mm, function(x) {
  x$t[, 2, drop = FALSE]
})
rownames(ts_mm) = rownames(sce.amy.mm.PB)



## Human stats
pvals_hsap <- sapply(eb_list.amy.broad, function(x) {
  x$p.value[, 2, drop = FALSE]
})
rownames(pvals_hsap) = rowData(sce.amy.PB)$ID

ts_hsap <- sapply(eb_list.amy.broad, function(x) {
  x$t[, 2, drop = FALSE]
})
rownames(ts_hsap) = rowData(sce.amy.PB)$ID



### Subset and check matching 'HomoloGene.ID' === === === ===
pvals_mm <- pvals_mm[rownames(sce.mm.PBsub), ]
ts_mm <- ts_mm[rownames(sce.mm.PBsub), ]

pvals_hsap <- pvals_hsap[rowData(sce.hsap.PBsub)$ID, ]
ts_hsap <- ts_hsap[rowData(sce.hsap.PBsub)$ID, ]

rownames(ts_mm) <- rowData(sce.mm.PBsub)$HomoloGene.ID
rownames(pvals_mm) <- rowData(sce.mm.PBsub)$HomoloGene.ID

rownames(ts_hsap) <- rowData(sce.hsap.PBsub)$HomoloGene.ID
rownames(pvals_hsap) <- rowData(sce.hsap.PBsub)$HomoloGene.ID

table(rownames(ts_mm) == rownames(ts_hsap))
    ## all 14121 TRUE - good


## Now run correlation
cor_t = cor(ts_mm, ts_hsap)
signif(cor_t, 2)

## On just hsap cluster-specific homologous genes ===
hsap_specific_indices = mapply(function(t, p) {
    oo = order(t, decreasing = TRUE)[1:100]
  },
  as.data.frame(ts_hsap),
  as.data.frame(pvals_hsap)
)
hsap_ind = unique(as.numeric(hsap_specific_indices))

cor_t_hsap = cor(ts_mm[hsap_ind, ],
                  ts_hsap[hsap_ind, ])
signif(cor_t_hsap, 3)

## On just mouse cluster-specific homologous genes ===
mm_specific_indices = mapply(function(t, p) {
    oo = order(t, decreasing = TRUE)[1:100]
  },
  as.data.frame(ts_mm),
  as.data.frame(pvals_mm)
)
mm_ind = unique(as.numeric(mm_specific_indices))

cor_t_mm = cor(ts_mm[mm_ind, ],
                 ts_hsap[mm_ind, ])
signif(cor_t_mm, 3)



### Heatmap
theSeq.all = seq(-.5, .5, by = 0.01)
my.col.all <- colorRampPalette(brewer.pal(7, "PRGn"))(length(theSeq.all))

ct = colData(sce.hsap.PBsub)
ct = ct[!duplicated(sce.hsap.PBsub$cellType.final), ]

cor_t_hsap_toPlot = cor_t_hsap
rownames(cor_t_hsap_toPlot) = paste0(rownames(cor_t_hsap_toPlot),"_","M.mus")
colnames(cor_t_hsap_toPlot) = paste0(colnames(cor_t_hsap_toPlot),"_","H.sap")

cor_t_mm_toPlot = cor_t_mm
rownames(cor_t_mm_toPlot) = paste0(rownames(cor_t_mm_toPlot),"_","M.mus")
colnames(cor_t_mm_toPlot) = paste0(colnames(cor_t_mm_toPlot),"_","H.sap")

cor_t_all_toPlot = cor_t
rownames(cor_t_all_toPlot) = paste0(rownames(cor_t_all_toPlot),"_","M.mus")
colnames(cor_t_all_toPlot) = paste0(colnames(cor_t_all_toPlot),"_","H.sap")


    ## MNT added 14Apr2020: Reorder to diagonal & threshold at 0.4 for all-gene correlation === === ===
        # Start from descending - easier to manually order
        #cor_t_all_toPlot <- cor_t_all_toPlot[ ,rev(1:ncol(cor_t_all_toPlot))]
    # This is useful:
    apply(cor_t_all_toPlot, 2, which.max)
        # If want to re-order human labels (but prefer re-ordering mm labels)
        #cor_t_all_toPlot <- cor_t_all_toPlot[ ,rev(c(14,5,3,4, 7,10,12,6, 9,8,2,1, 11,13))]
    cor_t_all_toPlot <- cor_t_all_toPlot[c(14,11:13,4,3, 2,8,7,9, 6,15,5,16,1,10), ]
    # Threshold at 0.4
    range(cor_t_all_toPlot)
    cor_t_all_toPlot <- ifelse(cor_t_all_toPlot >= 0.4, 0.4, cor_t_all_toPlot)
    
    
    ## Do for other gene subsets ===
    # Human
        #cor_t_hsap_toPlot <- cor_t_hsap_toPlot[ ,rev(1:ncol(cor_t_hsap_toPlot))]
        #cor_t_hsap_toPlot <- cor_t_hsap_toPlot[ ,rev(c(14,5,3,4, 7,10,12,6, 9,8,2,1, 11,13))]
    cor_t_hsap_toPlot <- cor_t_hsap_toPlot[c(14,11:13,4,3, 2,8,7,9, 6,15,5,16,1,10), ]
    # Threshold at 0.4
    range(cor_t_hsap_toPlot)
    cor_t_hsap_toPlot <- ifelse(cor_t_hsap_toPlot >= 0.4, 0.4, cor_t_hsap_toPlot)

    # mm
        #cor_t_mm_toPlot <- cor_t_mm_toPlot[ ,rev(1:ncol(cor_t_mm_toPlot))]
        #cor_t_mm_toPlot <- cor_t_mm_toPlot[ ,rev(c(14,5,3,4, 7,10,12,6, 9,8,2,1, 11,13))]
    cor_t_mm_toPlot <- cor_t_mm_toPlot[c(14,11:13,4,3, 2,8,7,9, 6,15,5,16,1,10), ]
    # Threshold at 0.4
    range(cor_t_mm_toPlot)
    cor_t_mm_toPlot <- ifelse(cor_t_mm_toPlot >= 0.4, 0.4, cor_t_mm_toPlot)
    
    

pdf("/dcl01/lieber/ajaffe/Matt/MNT_thesis/snRNAseq/10x_pilot_FINAL/pdfs/exploration/overlap-mouse-MeA_with_LIBD-10x-Amyg_top100-or-all_Apr2020.pdf")
# Most human-specific
print(
  levelplot(
    cor_t_hsap_toPlot,
    aspect = "fill",
    at = theSeq.all,
    col.regions = my.col.all,
    ylab = "",
    xlab = "",
    scales = list(x = list(rot = 90, cex = 1), y = list(cex = 1)),
    main="Correlation of cluster-specific t's \n (top 100 genes/human (LIBD) clusters)"
  )
)
# Most mm-specific
print(
  levelplot(
    cor_t_mm_toPlot,
    aspect = "fill",
    at = theSeq.all,
    col.regions = my.col.all,
    ylab = "",
    xlab = "",
    scales = list(x = list(rot = 90, cex = 1), y = list(cex = 1)),
    main="Correlation of cluster-specific t's \n (top 100 genes/mouse MeA (UCLA) clusters)"
  )
)
# All
print(
  levelplot(
    cor_t_all_toPlot,
    aspect = "fill",
    at = theSeq.all,
    col.regions = my.col.all,
    ylab = "",
    xlab = "",
    scales = list(x = list(rot = 90, cex = 1), y = list(cex = 1)),
    main="Correlation of cluster-specific t's \n (all shared 13,444 homologs)",
    fontsize = 20
  )
)
dev.off()







### Comparison to UCLA mouse MeA with SN-LEVEL stats ==================================
  # Added MNT 14May2020 - UPDATED 22May2020 to compare to 2019 dataset
  # (previously only 2017 neuronal subclusters), now with neuronal subcluster info

# Load mouse stats
# load("/dcl01/ajaffe/data/lab/singleCell/ucla_mouse-MeA/2017Neuron/markers-stats_mouseMeA-2017-neuSubs_findMarkers-SN-LEVEL_MNTMay2020.rda", verbose=T)
#     # markers.mmMeAneu.t.1vAll
load("/dcl01/ajaffe/data/lab/singleCell/ucla_mouse-MeA/2019Cell/markers-stats_mouseMeA-2019-with-16neuSubs_findMarkers-SN-LEVEL_MNTMay2020.rda", verbose=T)
    # markers.mmMeA.t.1vAll

# Load mouse SCE
# load("/dcl01/ajaffe/data/lab/singleCell/ucla_mouse-MeA/2017Neuron/SCE_mouse-MeA-2017_neuronalSubclusters_HVGs_MNT.rda", verbose=T)
#     # sce.amy.mm17hvgs
load("/dcl01/ajaffe/data/lab/singleCell/ucla_mouse-MeA/2019Cell/SCE_mouse-MeA_downstream-processing_MNT.rda", verbose=T)
    # sce.amy.mm, chosen.hvgs.amy.mm

## Calculate and add t-statistic (= std.logFC * sqrt(N)) for mouse clusters
#      and fix row order to the first entry "Astrocyte"
fixTo <- rownames(markers.mmMeA.t.1vAll[[1]])
for(x in names(markers.mmMeA.t.1vAll)){
  markers.mmMeA.t.1vAll[[x]]$t.stat <- markers.mmMeA.t.1vAll[[x]]$std.logFC * sqrt(ncol(sce.amy.mm))
  markers.mmMeA.t.1vAll[[x]] <- markers.mmMeA.t.1vAll[[x]][fixTo, ]
}

# Pull out the t's
ts.mmMeA <- sapply(markers.mmMeA.t.1vAll, function(x){x$t.stat})
rownames(ts.mmMeA) <- fixTo



## Human t stats subset/re-ordering ===
# Bring in human stats; create t's
load("/dcl01/lieber/ajaffe/Matt/MNT_thesis/snRNAseq/10x_pilot_FINAL/rdas/markers-stats_Amyg-n2_findMarkers-SN-LEVEL_MNTMay2020.rda", verbose=T)
    # markers.amy.t.1vAll, markers.amy.t.design, markers.amy.wilcox.block
    rm(markers.amy.t.design, markers.amy.wilcox.block)

# Need to add t's with N nuclei used in constrasts
load("/dcl01/lieber/ajaffe/Matt/MNT_thesis/snRNAseq/10x_pilot_FINAL/rdas/regionSpecific_Amyg-n2_cleaned-combined_SCE_MNTFeb2020.rda", verbose=T)
    #sce.amy, chosen.hvgs.amy, pc.choice.amy, clusterRefTab.amy, ref.sampleInfo
    rm(chosen.hvgs.amy, pc.choice.amy, clusterRefTab.amy,ref.sampleInfo)

# First drop "Ambig.lowNtrxts" (50 nuclei)
sce.amy <- sce.amy[ ,sce.amy$cellType.split != "Ambig.lowNtrxts"]
sce.amy$cellType.split <- droplevels(sce.amy$cellType.split)

## As above, calculate and add t-statistic (= std.logFC * sqrt(N)) from contrasts
#      and fix row order to the first entry "Astro"
fixTo <- rownames(markers.amy.t.1vAll[["Astro"]])

for(s in names(markers.amy.t.1vAll)){
  markers.amy.t.1vAll[[s]]$t.stat <- markers.amy.t.1vAll[[s]]$std.logFC * sqrt(ncol(sce.amy))
  markers.amy.t.1vAll[[s]] <- markers.amy.t.1vAll[[s]][fixTo, ]
}

# Pull out the t's
ts.amy <- sapply(markers.amy.t.1vAll, function(x){x$t.stat})
rownames(ts.amy) <- fixTo



## Bring in HomoloGene.ID info to subset/match order
# load("/dcl01/ajaffe/data/lab/singleCell/ucla_mouse-MeA/2019Cell/SCE_mm-MeA-PBd_w_matchingHsap-Amyg-PBd_HomoloGene.IDs_MNT.rda",
#      verbose=T)
#     # sce.mm.PBsub, sce.hsap.PBsub, Readme
# 
# table(rowData(sce.mm.PBsub)$HomoloGene.ID == rowData(sce.hsap.PBsub)$HomoloGene.ID)  # all TRUE - dope
# # (see above - these are the intersecting homologs)
# 
# ## However!
# table(rownames(ts.mmMeA) %in% rownames(sce.mm.PBsub)) # not all - so will need to get union
# rm(sce.mm.PBsub, sce.hsap.PBsub, Readme)

## HomoloGene.ID for all human genes ====
    hom = read.delim("http://www.informatics.jax.org/downloads/reports/HOM_AllOrganism.rpt",
                     as.is=TRUE)
    
    hom_hs <- hom[hom$Common.Organism.Name == "human", ]
    # of 19,124 entries
    
    # First Add EntrezID for human
    hs.entrezIds <- mapIds(org.Hs.eg.db, keys=rowData(sce.amy)$ID, 
                           column="ENTREZID", keytype="ENSEMBL")
    # "'select()' returned 1:many mapping between keys and columns"
    table(!is.na(hs.entrezIds))
        # 22,818 valid entries (remember this is already subsetted for those non-zero genes only)
    
    # Add to rowData
    rowData(sce.amy) <- cbind(rowData(sce.amy), hs.entrezIds)
    
    # Now how many in JAX db?
    table(rowData(sce.amy)$hs.entrezIds %in% hom_hs$EntrezGene.ID)
        # 18,865
    table(rowData(sce.amy)$Symbol %in% hom_hs$Symbol)
        # 18,472 - not a bad difference
    
          # So for mapping === === ===
          # human.entrez > HomoloGene.ID < mm.Symbol
          #                ^ filter SCE's on this
    
    # Human (by Entrez)
    rowData(sce.amy)$HomoloGene.ID <- hom_hs$HomoloGene.ID[match(rowData(sce.amy)$hs.entrezIds,
                                                                    hom_hs$EntrezGene.ID)]
    # end chunk ====


# Intersection?
table(rowData(sce.amy.mm)$HomoloGene.ID %in% rowData(sce.amy)$HomoloGene.ID)
    # FALSE  TRUE
    #   665 13845


# First give [human] ts.amy rownames their respective EnsemblID
    #   (have to use the full sce bc rownames(sce.hsap.PBsub) is EnsemblID and we uniquified the $Symbol)
rownames(ts.amy) <- rowData(sce.amy)$ID[match(rownames(ts.amy), rownames(sce.amy))]
# Then to HomoloGene.ID
rownames(ts.amy) <- rowData(sce.amy)$HomoloGene.ID[match(rownames(ts.amy), rowData(sce.amy)$ID)]
    # Btw half are NA
    table(is.na(rownames(ts.amy)))
        # FALSE  TRUE
        # 17261 11203
    
# So subset for those with HomoloGene.ID
ts.amy <- ts.amy[!is.na(rownames(ts.amy)), ]



# Mouse - can just go to HomoloGene.ID
rownames(ts.mmMeA) <- rowData(sce.amy.mm)$HomoloGene.ID[match(rownames(ts.mmMeA), rownames(sce.amy.mm))]

# Intersecting?
table(rownames(ts.mmMeA) %in% rownames(ts.amy))
    # FALSE  TRUE
    #   985 13525   - so we'll be running correlation across these genes

# Subset and match order
ts.mmMeA <- ts.mmMeA[rownames(ts.mmMeA) %in% rownames(ts.amy), ]
ts.amy <- ts.amy[rownames(ts.mmMeA), ]

cor_t_amy <- cor(ts.amy, ts.mmMeA)
rownames(cor_t_amy) = paste0(rownames(cor_t_amy),"_","H")
colnames(cor_t_amy) = paste0(colnames(cor_t_amy),"_","M")
range(cor_t_amy)
    #[1] -0.2203968  0.5023080      (previously {-0.2557751, 0.2577207} on only 2017 neuronal subsets)

### Heatmap - typically use levelplot (e.g. below), but will want pheatmap bc can cluster cols/rows
theSeq.all = seq(-.6, .6, by = 0.01)
my.col.all <- colorRampPalette(brewer.pal(7, "BrBG"))(length(theSeq.all)-1)

# Re-order mouse labels - move EN/MG/MU to after neuronal subclusters
cor_t_amy <- cor_t_amy[ ,c(1, 5,13:20,6:12, 3,2,4, 21,23,22)]

# #pdf("/dcl01/lieber/ajaffe/Matt/MNT_thesis/snRNAseq/10x_pilot_FINAL/pdfs/exploration/HongLab-UCLA_mmMeA/overlap-mouseMeA-2017-neuSubs_with_LIBD-10x-AMY_SN-LEVEL-stats_May2020.pdf")
# pdf("/dcl01/lieber/ajaffe/Matt/MNT_thesis/snRNAseq/10x_pilot_FINAL/pdfs/exploration/HongLab-UCLA_mmMeA/overlap-mouseMeA-2019-fullSubclusters_with_LIBD-10x-AMY_SN-LEVEL-stats_May2020.pdf")
# pheatmap(cor_t_amy,
#          color=my.col.all,
#          cluster_cols=F, cluster_rows=F,
#          breaks=theSeq.all,
#          fontsize=11, fontsize_row=15, fontsize_col=12,
#          #main="Correlation of cluster-specific t's for mouse MeA neuronal subclusters \n (Wu et al., Neuron 2017)")
#          main="Correlation of cluster-specific t's to mouse MeA \n complete subclusters (Chen-Hu-Wu et al., Cell 2019)")
# # Version with mouse glial cell types 'missing' in LIBD data dropped:
# pheatmap(cor_t_amy_sub,
#          color=my.col.all,
#          cluster_cols=F, cluster_rows=F,
#          breaks=theSeq.all,
#          fontsize=11.5, fontsize_row=15, fontsize_col=13.5,
#          main="Correlation of cluster-specific t's to mouse MeA \n complete subclusters (Chen-Hu-Wu et al., Cell 2019)")
# 
# dev.off()


## Version with mouse glial cell types 'missing' in LIBD data dropped:
cor_t_amy_sub <- cor_t_amy[ ,-which(colnames(cor_t_amy) %in% c("EN_M", "MU_M", "OPC.OL_M"))]
    ## Actually just print as second page to the above - will probably get some suggested edits



## Iteration with top N spp:subcluster-specific genes: ========
 #   Added MNT 25May2020
 #   -> Basically just run through line 488, under ("Subset and match order")

# Save the ts matrices to reduce work next time
Readme <- "These t-statistic matrices are subsetted and matched for shared 'HomoloGene.ID', so `cor()` can simply be run or other gene subsets applied first."
save(ts.amy, ts.mmMeA, Readme, file="rdas/zTsMats_libd-AMY_and_ucla-mouseMeA-2019Cell_sharedGenes_25May2020.rda")


# # Have to remove the markers objects bc the rows have been fixed  (actually don't need to lol)
# rm(markers.amy.t.1vAll, markers.mmMeA.t.1vAll)
# 
# # Re-load them
# load("/dcl01/lieber/ajaffe/Matt/MNT_thesis/snRNAseq/10x_pilot_FINAL/rdas/markers-stats_Amyg-n2_findMarkers-SN-LEVEL_MNTMay2020.rda", verbose=T)
#     # markers.amy.t.1vAll, markers.amy.t.design, markers.amy.wilcox.block
#     rm(markers.amy.t.design, markers.amy.wilcox.block)
# 
# load("/dcl01/ajaffe/data/lab/singleCell/ucla_mouse-MeA/2019Cell/markers-stats_mouseMeA-2019-with-16neuSubs_findMarkers-SN-LEVEL_MNTMay2020.rda", verbose=T)
#     # markers.mmMeA.t.1vAll
#     
    
    
## On just hsap cluster-specific homologous genes ===
hsap_specific_indices = mapply(function(t) {
  oo = order(t, decreasing = TRUE)[1:100]
  },
as.data.frame(ts.amy)
)
hsap_ind = unique(as.numeric(hsap_specific_indices))
length(hsap_ind)  # so of 1200 (100 x 12 cellType.split), 919 unique

cor_t_hsap = cor(ts.amy[hsap_ind, ],
                 ts.mmMeA[hsap_ind, ])
range(cor_t_hsap)
    #[1] -0.2738376  0.6612352


## On just mouse cluster-specific homologous genes ===
mouse_specific_indices = mapply(function(t) {
  oo = order(t, decreasing = TRUE)[1:100]
},
as.data.frame(ts.mmMeA)
)
mouse_ind = unique(as.numeric(mouse_specific_indices))
length(mouse_ind)  # so of 2300 (100 x 23 subCluster), 1543 unique

cor_t_mouse = cor(ts.amy[mouse_ind, ],
                 ts.mmMeA[mouse_ind, ])
range(cor_t_mouse)
    # [1] -0.2731605  0.6113445

## UPDATED heatmap:
theSeq.all = seq(-.65, .65, by = 0.01)
my.col.all <- colorRampPalette(brewer.pal(7, "BrBG"))(length(theSeq.all)-1)

# Re-order mouse labels - move EN/MG/MU to after neuronal subclusters
cor_t_hsap <- cor_t_hsap[ ,c(1, 5,13:20,6:12, 3,2,4, 21,23,22)]
    # Then treshold this one to 0.65 max (max is 0.6612)
    cor_t_hsap <- ifelse(cor_t_hsap >= 0.65, 0.65, cor_t_hsap)
    # (and)
    cor_t_amy_sub <- cor_t_amy[ ,-which(colnames(cor_t_amy) %in% c("EN_M", "MU_M", "OPC.OL_M"))]
cor_t_mouse <- cor_t_mouse[ ,c(1, 5,13:20,6:12, 3,2,4, 21,23,22)]

#pdf("/dcl01/lieber/ajaffe/Matt/MNT_thesis/snRNAseq/10x_pilot_FINAL/pdfs/exploration/HongLab-UCLA_mmMeA/overlap-mouseMeA-2019-fullSubclusters_with_LIBD-10x-AMY_SN-LEVEL-stats_May2020.pdf")
    # or
    pdf("/dcl01/lieber/ajaffe/Matt/MNT_thesis/snRNAseq/10x_pilot_FINAL/pdfs/exploration/HongLab-UCLA_mmMeA/overlap-mouseMeA-2019-fullSubclusters_with_LIBD-10x-AMY_SN-LEVEL-stats_numbersPrinted_May2020.pdf")
pheatmap(cor_t_amy,
         color=my.col.all,
         cluster_cols=F, cluster_rows=F,
         breaks=theSeq.all,
         fontsize=11, fontsize_row=15, fontsize_col=12,
            display_numbers=T, number_format="%.2f", fontsize_number=6.5,
         main="Correlation of cluster-specific t's to mouse MeA \n complete subclusters (Chen-Hu-Wu et al., Cell 2019)")
# Version with mouse glial cell types 'missing' in LIBD data dropped:
pheatmap(cor_t_amy_sub,
         color=my.col.all,
         cluster_cols=F, cluster_rows=F,
         breaks=theSeq.all,
         fontsize=11.5, fontsize_row=15, fontsize_col=13.5,
            display_numbers=T, number_format="%.2f", fontsize_number=6.5,
         main="Correlation of cluster-specific t's to mouse MeA \n complete subclusters (Chen-Hu-Wu et al., Cell 2019)")
# On human-specific genes (slightly thresholded)
pheatmap(cor_t_hsap,
         color=my.col.all,
         cluster_cols=F, cluster_rows=F,
         breaks=theSeq.all,
         fontsize=11.5, fontsize_row=15, fontsize_col=13.5,
            display_numbers=T, number_format="%.2f", fontsize_number=6.5,
         main="Correlation of top-100 cluster-specific t's to \n (Chen-Hu-Wu et al., Cell 2019) subclusters")
# On mm-MeA-specific genes
pheatmap(cor_t_mouse,
         color=my.col.all,
         cluster_cols=F, cluster_rows=F,
         breaks=theSeq.all,
         fontsize=11.5, fontsize_row=15, fontsize_col=13.5,
            display_numbers=T, number_format="%.2f", fontsize_number=6.5,
         main="Correlation of LIBD-AMY subclusters to \n (Chen-Hu-Wu et al., Cell 2019) top-100 subcluster t's")
dev.off()



## Intersecting some of the top markers =====================
load("/dcl01/lieber/ajaffe/Matt/MNT_thesis/snRNAseq/10x_pilot_FINAL/rdas/markers-stats_Amyg-n2_findMarkers-SN-LEVEL_MNTMay2020.rda", verbose=T)
    # markers.amy.t.1vAll, markers.amy.t.design, markers.amy.wilcox.block
    rm(markers.amy.t.design, markers.amy.wilcox.block)

# Take top 100
markerList.t.hsap <- lapply(markers.amy.t.1vAll, function(x){
  rownames(x)[x$log.FDR < log10(1e-6)]
  }
)
genes.top100.hsap <- lapply(markerList.t.hsap, function(x){head(x, n=100)})


load("/dcl01/ajaffe/data/lab/singleCell/ucla_mouse-MeA/2019Cell/markers-stats_mouseMeA-2019-with-16neuSubs_findMarkers-SN-LEVEL_MNTMay2020.rda", verbose=T)
    # markers.mmMeA.t.1vAll

# Just `toupper()` it
markerList.t.mm <- lapply(markers.mmMeA.t.1vAll, function(x){
  rownames(x)[x$log.FDR < log10(1e-6)]
  }
)
genes.top100.mm <- lapply(markerList.t.mm, function(x){toupper(head(x, n=100))})
genes.top100.mm <- sapply(genes.top100.mm, cbind)

## sapply
sapply(genes.top100.hsap, function(x){
  apply(genes.top100.mm,2,function(y){length(intersect(x,y))})
})
    #        Astro Excit.1 Excit.2 Excit.3 Inhib.1 Inhib.2 Inhib.3 Inhib.4 Inhib.5 Micro Oligo OPC
    # AS        20       0       1       0       0       1       0       0       1     0     0   1
    # EN         2       1       1       0       1       2       1       0       0     0     0   2
    # MG         0       0       0       1       0       0       0       0       0    19     0   0
    # MU         2       1       0       1       0       0       1       1       0     0     0   0
    # N.1        1       4       2       0      14       8       3       4       9     0     1   1
    # N.10       0       6       1       4       7       7       2       0       6     0     0   0
    # N.11       1      10       5       2       8       3       4       6       8     0     0   4
    # N.12       2       7       4       3       7       5       2       3       5     0     2   2
    # N.13       1       2       1       3       1       1       0       0       5     1     0   1
    # N.14       0       7       2       4       9       6       0       4       7     1     1   2
    # N.15       0       7       1       6       0       1       1       0       1     0     0   1
    # N.16       1       3       4       1       7       3       3       6       4     0     0   4
    # N.2        2       6       2       1       9       5       2       3       6     0     0   3
    # N.3        2       3       1       4       0       3       0       0       2     0     0   0
    # N.4        2       5       3       1      10       7       3      10       6     1     1   3
    # N.5        0       4       3       2       4       4       1       2       5     0     0   2
    # N.6        1       2       3       0      13      10       6       8       9     0     3   2
    # N.7        0       4      10       1       1       3       1       2       2     0     0   1
    # N.8        1       7       4       4       6       6       2       3      19     1     1   3
    # N.9        0       3       1       1      10       5       2       5       4     0     0   1
    # OL         0       0       2       0       0       0       0       0       0     0    19   0
    # OPC        0       0       0       0       0       1       0       0       0     0     0  26
    # OPC.OL     0       0       0       1       0       0       0       0       1     0     5   7

  
  
## Amonst top 40 ===
genes.top40.hsap <- lapply(markerList.t.hsap, function(x){head(x, n=40)})

genes.top40.mm <- lapply(markerList.t.mm, function(x){toupper(head(x, n=40))})
genes.top40.mm <- sapply(genes.top40.mm, cbind)

sapply(genes.top40.hsap, function(x){
  apply(genes.top40.mm,2,function(y){length(intersect(x,y))})
})
    #       Astro Excit.1 Excit.2 Excit.3 Inhib.1 Inhib.2 Inhib.3 Inhib.4 Inhib.5 Micro Oligo OPC
    # AS         7       0       0       0       0       0       0       0       0     0     0   0
    # EN         1       0       0       0       0       0       0       0       0     0     0   0
    # MG         0       0       0       0       0       0       0       0       0     4     0   0
    # MU         0       0       0       0       0       0       0       0       0     0     0   0
    # N.1        0       0       1       0       1       0       0       0       0     0     0   0
    # N.10       0       0       0       0       1       2       0       0       2     0     0   0
    # N.11       0       4       0       0       2       0       0       2       0     0     0   1
    # N.12       1       2       2       0       0       1       0       0       2     0     0   1
    # N.13       0       0       0       1       0       0       0       0       1     0     0   0
    # N.14       0       2       0       1       0       1       0       0       1     1     0   0
    # N.15       0       3       0       0       0       0       0       0       1     0     0   0
    # N.16       0       1       1       0       0       1       0       0       1     0     0   2
    # N.2        0       1       1       0       1       0       0       0       1     0     0   0
    # N.3        0       1       0       0       0       2       0       0       0     0     0   0
    # N.4        0       1       1       0       3       3       0       1       0     0     0   1
    # N.5        0       0       0       0       1       0       0       0       0     0     0   1
    # N.6        0       1       0       0       2       2       0       0       0     0     0   0
    # N.7        0       0       2       0       0       1       0       1       0     0     0   0
    # N.8        0       1       0       0       1       1       1       2       1     0     0   0
    # N.9        0       0       0       0       0       1       0       1       1     0     0   0
    # OL         0       0       1       0       0       0       0       0       0     0     7   0
    # OPC        0       0       0       0       0       0       0       0       0     0     0  10
    # OPC.OL     0       0       0       0       0       0       0       0       0     0     1   1

# Inhib.5 : N.8 genes ==
  intersect(genes.top40.hsap[["Inhib.5"]], genes.top100.mm[ ,"N.8"])
      # [1] "NPFFR2" "SV2C"   "OTOF"   "GRM8"   "OLFM3"  "FOXP2"

  # round(ts.mmMeA["49202", ],3)  # (Tll1 - looking because a highlighted gene in text)
  #     # AS      EN      MG      MU     N.1    N.10    N.11    N.12    N.13    N.14    N.15    N.16
  #     # -5.939  -5.932  -6.699   1.698   8.835   2.691 107.521  -5.323  20.345  86.122  -5.484  -5.423
  #     # N.2     N.3     N.4     N.5     N.6     N.7     N.8     N.9      OL     OPC  OPC.OL
  #     # 13.117  -5.297  33.339  16.283  -6.203  -5.520 108.310  22.783  -5.886  -4.273  -5.318
  # 
  plotExpression(sce.amy.mm, exprs_values="logcounts", x="subCluster", colour_by="subCluster", features="Tll1")
  #     # ahh nothing but a few outliers
  
  sce.amy.mm.sub <- sce.amy.mm[ ,grep("N.", sce.amy.mm$subCluster)]
  sce.amy.mm.sub$subCluster <- droplevels(sce.amy.mm.sub$subCluster)
  plotExpression(sce.amy.mm.sub, exprs_values="logcounts", x="subCluster", colour_by="subCluster",
                 features=c("Npffr2","Sv2c","Otof","Grm8","Olfm3","Foxp2"))
      # Actually nothing suuuper convicing - mostly outlier.  These just happen to have _more_ lol
  
  # N.8 top genes include Pcdh8 & Lamp5
  plotExpression(sce.amy.mm.sub, exprs_values="logcounts", x="subCluster", colour_by="subCluster",
                 features=c("Pcdh8","Lamp5"))

  # N.12 reported marker genes (reported in supplementals "mmc2.xlsx" with paper)
  plotExpression(sce.amy.mm.sub, exprs_values="logcounts", x="subCluster", colour_by="subCluster",
                 features=c("Eomes","Dsp","Nhlh2","Samd3","Trpc3","Cdhr1","Lhx1"))
      # Oh six of these were of the top 10 from my own test and plotted lol.  Well good.
  
  
# (and btw) ===
table(sce.amy$cellType.split, sce.amy$donor)
    #                 Br5161 Br5212
    # Ambig.lowNtrxts     34     16
    # Astro              489    363
    # Excit.1            141    193
    # Excit.2              0     40
    # Excit.3              0     55
    # Inhib.1             16    155
    # Inhib.2             33     76
    # Inhib.3             11     24
    # Inhib.4             24      0
    # Inhib.5             85     13
    # Micro              425    339
    # Oligo             1697   1776
    # OPC                335    292

# Glucocorticoid receptors? (in relation to TLL1, as per https://doi.org/10.1016/j.molbrainres.2005.09.016)
plotExpression(sce.amy, exprs_values="logcounts", x="cellType.split", colour_by="cellType.split",
               features=c("NR3C1","NR3C2")) + stat_summary(fun.y = median, fun.ymin = median, fun.ymax = median,
                                                          geom = "crossbar", width = 0.3,
                                                          colour=rep(tableau20[1:12], 2)) +
  theme(axis.text.x = element_text(angle = 90, hjust = 1), plot.title = element_text(size = 25))
    # No particular high/specific expression in Inhib.5



### FINAL GRANT VERSION ===
  # Remove EN, MU, OPC.OL, N.12 & N.15
load("rdas/zTsMats_libd-AMY_and_ucla-mouseMeA-2019Cell_sharedGenes_25May2020.rda", verbose=T)
    # ts.amy, ts.mmMeA, Readme


cor_t_amy <- cor(ts.amy, ts.mmMeA)
rownames(cor_t_amy) = paste0(rownames(cor_t_amy),"_","H")
colnames(cor_t_amy) = paste0(colnames(cor_t_amy),"_","M")

# Re-order mouse labels - move EN/MG/MU to after neuronal subclusters
cor_t_amy <- cor_t_amy[ ,c(1, 5,13:20,6:12, 3,2,4, 21,23,22)]
# Remove those selected
cor_t_amy_sub <- cor_t_amy[ ,-which(colnames(cor_t_amy) %in% c("EN_M", "MU_M", "OPC.OL_M",
                                                               "N.12_M", "N.15_M"))]
range(cor_t_amy_sub)
    #[1] -0.2203968  0.5023080  --> Threshold to 0.5

cor_t_amy_sub <- ifelse(cor_t_amy_sub >= 0.5, 0.5, cor_t_amy_sub)

### Heatmap - typically use levelplot (e.g. below), but will want pheatmap bc can cluster cols/rows
theSeq.all = seq(-.5, .5, by = 0.01)
my.col.all <- colorRampPalette(brewer.pal(7, "BrBG"))(length(theSeq.all)-1)

pdf("/dcl01/lieber/ajaffe/Matt/MNT_thesis/snRNAseq/10x_pilot_FINAL/pdfs/exploration/HongLab-UCLA_mmMeA/overlap-mouseMeA-2019-fullSubclusters_with_LIBD-10x-AMY_SN-LEVEL-stats_FINAL_May2020.pdf",width=8)
pheatmap(cor_t_amy_sub,
         color=my.col.all,
         cluster_cols=F, cluster_rows=F,
         angle_col=90,
         breaks=theSeq.all,
         fontsize=11.5, fontsize_row=17, fontsize_col=15,
         legend_breaks=c(seq(-0.5,0.5,by=0.25)),
         main="Correlation of cluster-specific t's to mouse MeA \n subclusters (Chen-Hu-Wu et al., Cell 2019)")
dev.off()





## For supplement: Print top markers for 'Inhib.5' & corresponding in MeA 'N.8' === ===
# (load AMY SCE - already done in session)

# Prep mouse MeA
load("/dcl01/ajaffe/data/lab/singleCell/ucla_mouse-MeA/2019Cell/SCE_mouse-MeA_downstream-processing_MNT.rda", verbose=T)
    # sce.amy.mm, chosen.hvgs.amy.mm

sce.amy.mm.sub <- sce.amy.mm[ ,grep("N.", sce.amy.mm$subCluster)]
sce.amy.mm.sub$subCluster <- droplevels(sce.amy.mm.sub$subCluster)

genes2print <- c("Npffr2", "Tll1", "Grm8", "Foxp2")

pdf("pdfs/pubFigures/suppFig_AMY-vs-MeA_topInhib.5markers_MNTSep2020.pdf", height=2.5, width=5)
# Human AMY
print(
  plotExpression(sce.amy, exprs_values = "logcounts", features=toupper(genes2print),
                 x="cellType.split", colour_by="cellType.split", point_alpha=0.5, point_size=1.0, ncol=4,
                 add_legend=F) + stat_summary(fun.y = median, fun.ymin = median, fun.ymax = median,
                                              geom = "crossbar", width = 0.3,
                                              colour=rep(tableau20[1:12], length(genes2print))) +
    xlab("") +
    theme(axis.text.x = element_text(angle = 90, hjust = 1, size = 9.5),
          axis.title.y = element_text(angle = 90, size = 10),
          panel.grid.major=element_line(colour="grey95", size=0.8),
          panel.grid.minor=element_line(colour="grey95", size=0.4))
)

# mouse MeA
print(
  plotExpression(sce.amy.mm.sub, exprs_values = "logcounts", features=genes2print,
                 x="subCluster", colour_by="subCluster", point_alpha=0.5, point_size=1.0, ncol=4,
                 add_legend=F) + stat_summary(fun.y = median, fun.ymin = median, fun.ymax = median,
                                              geom = "crossbar", width = 0.3,
                                              colour=rep(tableau20[1:16], length(genes2print))) +
    xlab("") +
    theme(axis.text.x = element_text(angle = 90, hjust = 1, size = 9.5),
          axis.title.y = element_text(angle = 90, size = 10),
          panel.grid.major=element_line(colour="grey95", size=0.8),
          panel.grid.minor=element_line(colour="grey95", size=0.4))
)
dev.off()


## Heatmap version ===
# Take more overlapping, from above exploration
genes2print <- c("Npffr2", "Tll1", "Grm8", "Foxp2", "Sv2c", "Olfm3")

pdf("pdfs/pubFigures/suppFig_AMY-vs-MeA_topInhib.5markers_heatmap_MNTSep2020.pdf", width=5, height=5)
dat <- assay(sce.amy, "logcounts")
cell.idx <- splitit(sce.amy$cellType.split)
current_dat <- do.call(cbind, lapply(cell.idx, function(ii) rowMeans(dat[toupper(genes2print), ii])))
pheatmap(current_dat, cluster_rows = FALSE, cluster_cols = FALSE, breaks = seq(0.02, 4.0, length.out = 101),
         color = colorRampPalette(RColorBrewer::brewer.pal(n = 7, name = "BuGn"))(100),
         fontsize_row = 18, fontsize_col=16)

dat <- assay(sce.amy.mm.sub, "logcounts")
cell.idx <- splitit(sce.amy.mm.sub$subCluster)
current_dat <- do.call(cbind, lapply(cell.idx, function(ii) rowMeans(dat[genes2print, ii])))
pheatmap(current_dat, cluster_rows = FALSE, cluster_cols = FALSE, breaks = seq(0.02, 1, length.out = 101),
         color = colorRampPalette(RColorBrewer::brewer.pal(n = 7, name = "BuGn"))(100),
         fontsize_row = 16, fontsize_col=16)
dev.off()



