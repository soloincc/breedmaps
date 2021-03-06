# Overlapping with regulatory regions
# Overlaps the precise SVs with regulatory regions(taken from ChromHMM_REPC.bed Fang et al. https://doi.org/10.1186/s12915-019-0687-8)

if (!require("tidyverse")) {
  install.packages("tidyverse")
}

if (!require("BiocManager")) {
  install.packages("BiocManager")
  BiocManager::install()
  library(BiocManager)
}
if (!require("GenomicRanges")) {
  BiocManager::install("GenomicRanges")
}

if (!require("optparse")) {
  install.packages("optparse")
}
library(optparse)
library(tidyverse)
library(GenomicRanges)


# Create inputs from the command line and save the options
options <- list(
  make_option(c("-b", "--workingDir"), help = "Base directory", default =
                "~/breedmaps/SVs_identification/"),
  make_option(c("-a", "--annDir"), help = "Annotation directory", default =
                "data/annotation/"),
  make_option(c("-r", "--reglFile"), help = "Result directory", default =
                "ChromHMM_REPC.bed"),
  make_option(c("-s", "--scriptDir"), help = "script directory", default =
                "scripts/"),
  make_option(c("-d", "--dataDir"), help = "Data directory for the filtered variants", default =
                "results/filtered_variants/"),
  make_option(c("-r", "--resultsDir"), help = "Result directory", default =
                "results/regulatory_variants/"),
  make_option(c("-f", "--functions"), help = "Function file name", default =
                "functions.R")
)


params <- parse_args(OptionParser(option_list = options))
source(paste(params$workingDir, params$scriptDir, params$functions, sep =
               ""))

######################################################################
######################################################################
######################################################################
# Load the regulatory regions from BED file. Will be named as "DATASET_"
dataset_path = paste(params$workingDir,
                     params$annDir,
                     params$reglFile,
                     sep = "")

dataset = read.table(
  file = dataset_path,
  quote = "",
  sep = "\t",
  header = F,
  stringsAsFactors = F
)
dataset_renamed = dataset %>% dplyr::rename(
  DATASET_CHROM = V1,
  DATASET_START = V2,
  DATASET_END = V3,
  BIOLOGICAL_NAME = V4
)
# Alters the CHR column to match the same format as our data
dataset_cleaned = dataset_renamed %>% dplyr::mutate(DATASET_CHROM = stringr::str_split_fixed(dataset_renamed$DATASET_CHROM, "chr", n = 2)[, 2])
dataset_range = makeGRangesFromDataFrame(
  dataset_cleaned,
  seqnames.field = "DATASET_CHROM",
  start.field = "DATASET_START",
  end.field = "DATASET_END"
)


######################################################################
######################################################################
######################################################################
# Load our data from filtering_SVs.R. This data is referred as "SV_"
path = paste(params$workingDir,
             params$dataDir,
             sep = "")
file_names = list.files(path = path, pattern = "precise_*")
all_dfs = data.frame()
for (i in 1:(length(file_names))) {
  full_path = paste(params$workingDir,
                    params$dataDir,
                    file_names[[i]],
                    sep = "")
  svs = read.table(
    file = full_path,
    quote = "",
    sep = "\t",
    header = T,
    stringsAsFactors = F
  ) %>% dplyr::rename(SV_CHROM = CHROM,
                      SV_START = POS,
                      SV_END = END)
  svs = svs %>% dplyr::rename(ID1 = ID)
  sv_range = makeGRangesFromDataFrame(
    svs,
    seqnames.field = "SV_CHROM",
    start.field = "SV_START",
    end.field = "SV_END",
  )
  # Creates an ID2 from the row number (since no ID exists in the BED file)
  dataset_cleaned$ID2 = rownames(dataset_cleaned)
  # findoverlap_datafram is imported from functions.R
  overlap = findoverlap_dataframe(sv_range, dataset_range, svs, dataset_cleaned)
  #sv_range = ID1, dataset = ID2
  overlap_cleaned = overlap %>% dplyr::rename(SV_ID = ID1) %>% dplyr::select(-ID2)
  # if (i == 1) {
  #   overlap_cleaned$File = file_names[i]
  #   all_dfs = overlap_cleaned
  # }
  # else {
  #   overlap_cleaned$File = file_names[i]
  #   all_dfs = full_join(all_dfs, overlap_cleaned)
  # }
  filt_results = paste(params$workingDir,
                       params$resultsDir,
                       "regl_",
                       file_names[[i]],
                       sep = "")
  write.table(
    x = overlap_cleaned,
    file = filt_results,
    quote = F,
    sep = "\t",
    row.names = F,
    col.names = T
  )
  
}

# all_counts = all_dfs %>% dplyr::group_by(BIOLOGICAL_NAME) %>% count()
# print(as.data.frame(all_counts))
# 
# counts = as.data.frame(all_dfs %>% dplyr::group_by(BIOLOGICAL_NAME, File) %>% count())
# print(as.data.frame(counts))
# 

