# ADDING GENE ANNOTATION FROM ENSEMBL
# Takes the automatic annotation file from Ensembl(locally stored) and overlaps with precise SVs
# The annotation is divided into four groups since it is too computational heavy if all annotation is run at the same time.
# Keep in mind that a lot of input SVs will fill up the RAM on small computers

# There is a printed output of the count of each annotation type, calculated per file.
# Four output files per input files, e.g. filt_ann_gene_"file name".tsv

if (!require("tidyverse")) {
  install.packages("tidyverse")
}

# If installing with Biocmanager in R-Studio server, ask administrator for help
if (!require("BiocManager")) {
  install.packages("BiocManager")
  BiocManager::install()
  library(BiocManager)
}
if (!require("GenomicRanges")) {
  BiocManager::install("GenomicRanges")
}
if (!require("rtracklayer")) {
  BiocManager::install("rtracklayer")
}

if (!require("optparse")) {
  install.packages("optparse")
}
library(optparse)
library(tidyverse)
library(GenomicRanges)
library(rtracklayer)


# Create inputs from the command line and save the options
options <- list(
  make_option(c("-w", "--workingDir"), help = "Base directory", default =
                "~/breedmaps/SVs_identification/"),
  make_option(c("-a", "--annDir"), help = "Annotation directory", default =
                "data/annotation/"),
  make_option(c("-n", "--annFile"), help = "Annotation gtf file from ENSEMBL", default =
                "Bos_taurus.ARS-UCD1.2.104.gtf"),
  make_option(c("-s", "--scriptDir"), help = "Script directory", default =
                "scripts/"),
  make_option(c("-d", "--dataDir"), help = "Data directory for the filtered variants", default =
                "results/filtered_variants/"),
  make_option(c("-r", "--resultsDir"), help = "Result directory", default =
                "results/annotated_variants/"),
  make_option(c("-f", "--functions"), help = "Function file name", default =
                "functions.R")
)

params <- parse_args(OptionParser(option_list = options))
source(paste(params$workingDir, params$scriptDir, params$functions, sep =
               ""))

########################################
########################################
########################################
# Load gene info from ENSEMBL gtf file
ann_path = paste(params$workingDir, params$annDir, params$annFile, sep =
                   "")
ann_df = as.data.frame(rtracklayer::import(ann_path))
# Gene includes all Ensembl annotation (not only genes)
ann_df = ann_df %>% dplyr::rename(
  gene_chrom = seqnames,
  gene_start = start,
  gene_end = end,
  gene_width = width,
  gene_strand = strand,
  gene_type = type
)


########################################
########################################
########################################
# Set up the genomic ranges and data frames into 4 dataframes (genes, transcripts, exons and rest)
# The overlap function requires that the ID for the two overlapping data sets have ID1 or ID2 for the ID
gene_df = ann_df %>% filter(gene_type == "gene") %>% dplyr::rename(ID2 = gene_id)
gene_range = makeGRangesFromDataFrame(
  gene_df,
  seqnames.field = "gene_chrom",
  start.field = "gene_start",
  end.field = "gene_end",
  strand.field = "gene_strand"
)

tran_df = ann_df %>% filter(gene_type == "transcript") %>% dplyr::rename(ID2 = gene_id)
tran_range = makeGRangesFromDataFrame(
  tran_df,
  seqnames.field = "gene_chrom",
  start.field = "gene_start",
  end.field = "gene_end",
  strand.field = "gene_strand"
)

exon_df = ann_df %>% filter(gene_type == "exon") %>% dplyr::rename(ID2 = gene_id)
exon_range = makeGRangesFromDataFrame(
  exon_df,
  seqnames.field = "gene_chrom",
  start.field = "gene_start",
  end.field = "gene_end",
  strand.field = "gene_strand"
)

rest_df = ann_df %>% filter(gene_type != "exon") %>% filter(gene_type != "gene") %>% filter(gene_type != "transcript") %>% dplyr::rename(ID2 = gene_id)
rest_range = makeGRangesFromDataFrame(
  rest_df,
  seqnames.field = "gene_chrom",
  start.field = "gene_start",
  end.field = "gene_end",
  strand.field = "gene_strand"
)

########################################
########################################
########################################
# Load the precise SVs (output from filtering_SVs.R)
vcf_path = paste(params$workingDir, params$dataDir, sep = "")
vcf_files = list.files(path = vcf_path, pattern = "precise_*")
vcf_names = list()
df_list = list()
range_list = list()

# The printed output is the same as the counting_SV_occurence.R
print("##### ENSEMBL ANNOTATION #####")
for (i in 1:length(vcf_files)) {
  vcf_file = paste(vcf_path, vcf_files[i], sep = "")
  
  # Save the file name to be able to use it when writing results files
  name = strsplit(vcf_files, "\\.")[[i]][1]
  name = strsplit(name, "precise_")[[1]][2]
  
  df = read.table(
    file = vcf_file,
    quote = "",
    sep = "\t",
    header = T,
    stringsAsFactors = F
  )
  # Rename for use of the overlap function
  filt_var = df %>% dplyr::rename(ID1 = ID)
  # Create a GenomicRange from the precise SVs outputted from filtering_SVs.R
  vcf_range = makeGRangesFromDataFrame(
    filt_var,
    seqnames.field = "CHROM",
    start.field = "POS",
    end.field = "END",
  )
  
  # The findoverlap_dataframe is imported from functions.R
  overlap_gene = findoverlap_dataframe(vcf_range, gene_range, filt_var, gene_df) %>%
    dplyr::rename(ID = ID1, gene_id = ID2)
  overlap_tran = findoverlap_dataframe(vcf_range, tran_range, filt_var, tran_df) %>%
    dplyr::rename(ID = ID1, gene_id = ID2)
  overlap_exon = findoverlap_dataframe(vcf_range, exon_range, filt_var, exon_df) %>%
    dplyr::rename(ID = ID1, gene_id = ID2)
  overlap_rest = findoverlap_dataframe(vcf_range, rest_range, filt_var, rest_df) %>%
    dplyr::rename(ID = ID1, gene_id = ID2)
  # Prints the counts for each annotation type for each file
  print(paste("FILE: ", name ,sep=""))
  print("GENE_BIOTYPE COUNT")
  print(as.data.frame(overlap_gene %>% group_by(gene_type)%>%count()))
  print(as.data.frame(overlap_tran %>% group_by(gene_type)%>%count()))
  print(as.data.frame(overlap_exon %>% group_by(gene_type)%>%count()))
  print(as.data.frame(overlap_rest %>% group_by(gene_type)%>%count()))
  
  # Write to file (4 files)
  filt_results = paste(params$workingDir,
                       params$resultsDir,
                       "filt_ann_gene_",
                       name,
                       ".tsv",
                       sep = "")
  write.table(
    x = overlap_gene,
    file = filt_results,
    quote = F,
    sep = "\t",
    row.names = F,
    col.names = T
  )
  
  filt_results = paste(params$workingDir,
                       params$resultsDir,
                       "filt_ann_exon_",
                       name,
                       ".tsv",
                       sep = "")
  write.table(
    x = overlap_exon,
    file = filt_results,
    quote = F,
    sep = "\t",
    row.names = F,
    col.names = T
  )
  
  filt_results = paste(params$workingDir,
                       params$resultsDir,
                       "filt_ann_transcript_",
                       name,
                       ".tsv",
                       sep = "")
  write.table(
    x = overlap_tran,
    file = filt_results,
    quote = F,
    sep = "\t",
    row.names = F,
    col.names = T
  )
  filt_results = paste(params$workingDir,
                       params$resultsDir,
                       "filt_ann_rest_",
                       name,
                       ".tsv",
                       sep = "")
  write.table(
    x = overlap_rest,
    file = filt_results,
    quote = F,
    sep = "\t",
    row.names = F,
    col.names = T
  )
}
