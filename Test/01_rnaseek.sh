#!/bin/bash
#SBATCH -N 1
#SBATCH --ntasks=1
#SBATCH --time=48:00:00
#SBATCH --mem=64g
#SBATCH --cpus-per-task=8
#SBATCH --mail-user=nana-fatima.haruna@nih.gov
#SBATCH --mail-type=END,FAIL
#SBATCH -J rnaseek-NIAMS47
#SBATCH --gres=lscratch:200

umask 027

module purge
module load singularity snakemake

# 1. Paths
RAW_DIR="/data/NIAMS_IDSS/rawdata/NIAMS-47/20260303_LH00418_0278_A22NCCNLT3"
OUT_DIR="/data/NIAMS_IDSS/projects/NIAMS-47/2603RNAseq_A22NCCNLT3_2"
MERGED_DIR="/data/NIAMS_IDSS/rawdata/NIAMS-47/20260303_LH00418_0278_A22NCCNLT3_concat"

mkdir -p "$MERGED_DIR"

echo "Starting Concatenation at $(date)"

# 2. Concatenation Loop
# We look for L003 R1 files to identify the unique samples
for r1_l003 in "$RAW_DIR"/*_L003_R1_001.fastq.gz; do
    
    # Extract the base sample name (e.g., SampleA_S1)
    # basename removes the directory path; sed removes the lane/read suffix
    sample_name=$(basename "$r1_l003" | sed 's/_L003_R1_001.fastq.gz//')
    
    echo "Processing sample: $sample_name"

    # Verify all 8 files (4 lanes x 2 reads) exist before merging
    count=$(ls ${RAW_DIR}/${sample_name}_L00[3-6]_R[12]_001.fastq.gz 2>/dev/null | wc -l)
    
    if [ "$count" -eq 8 ]; then
        echo "  Found all 8 lanes. Merging..."
        # Merge R1 (Lanes 3,4,5,6)
        cat "${RAW_DIR}/${sample_name}"_L00[3-6]_R1_001.fastq.gz > "${MERGED_DIR}/${sample_name}_R1.fastq.gz"
        # Merge R2 (Lanes 3,4,5,6)
        cat "${RAW_DIR}/${sample_name}"_L00[3-6]_R2_001.fastq.gz > "${MERGED_DIR}/${sample_name}_R2.fastq.gz"
    else
        echo "  ERROR: Sample $sample_name only has $count files. Skipping!"
    fi
done

echo "Concatenation finished at $(date)"

# 3. RNA-seek Pipeline
# We use the merged directory as input. 
# RNA-seek will now see 2 files per sample (96 files total if you have 48 samples).
echo "Starting RNA-seek pipeline..."

/data/OpenOmics/prod/RNA-seek/v1.13.0/rna-seek run \
    --input ${MERGED_DIR}/*_R?_*.fastq.gz \
    --output "$OUT_DIR" \
    --genome hg38_48 \
    --star-2-pass-basic \
    --mode slurm \
    --sif-cache /data/OpenOmics/SIFs 

echo "Job finished at $(date)"