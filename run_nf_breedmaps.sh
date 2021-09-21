#!/bin/bash

#SBATCH -A snic2021-22-622
#SBATCH --error=wkihara.err
#SBATCH --output=wkihara.out
#SBATCH -n 8
#SBATCH --time=24:00:00


#$ -N phan_mapping
#$ -M wangoru.kihara@slu.se
#$ -m seab
#$ -cwd 
#$ -l h_rt=24:0:0,h_vmem=5G
#$ -j y
#$ -pe smp 24
#$ -e wkihara.log
#$ -o wkihara.log

echo "Starting the pipeline"
# echo "Initialize and activate the existing conda environment"
# conda init bash
conda activate /proj/nobackup/breedmap/newSV
which fastp

~/scripts/nextflow run main.nf
