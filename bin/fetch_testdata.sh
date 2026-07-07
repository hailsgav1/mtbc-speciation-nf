#!/usr/bin/env bash
#
# Pull a small, real MTBC test set from the ENA and subsample it so the
# pipeline runs in minutes. Requires: sra-tools (or curl), seqtk.
#
# Verified accessions
# -------------------
#   M. orygis (dairy cattle, Chennai, India) : SRR9157804  (BioProject PRJNA545406)
#
# Multi-species BioProjects to browse for more members:
#   PRJNA934340  - M. orygis (human + animal, Canada study)
#   PRJNA785380  - M. orygis (multiple animal hosts)
#   PRJNA575883  - mixed MTBC incl. M. orygis, M. bovis BCG, M. tuberculosis
#
# For the remaining panel members, query the ENA rather than hard-coding runs
# (deposits change). Example ENA search (species + Illumina + WGS):
#
#   https://www.ebi.ac.uk/ena/portal/api/search?result=read_run\
#     &query=tax_name(%22Mycobacterium%20caprae%22)%20AND%20\
#     instrument_platform=%22ILLUMINA%22%20AND%20library_strategy=%22WGS%22\
#     &fields=run_accession,fastq_ftp&format=tsv
#
# Reference genomes used by the pipeline:
#   M. tuberculosis H37Rv   : NC_000962.3   (default mapping reference)
#   M. bovis AF2122/97       : NC_002945.4 / LT708304
#
set -euo pipefail

OUTDIR="${1:-testdata}"
DEPTH_FRACTION="${2:-0.02}"   # subsample fraction; tune for target coverage
mkdir -p "$OUTDIR"

ACCESSIONS=(
    "SRR9157804"   # M. orygis, cattle, India
)

for acc in "${ACCESSIONS[@]}"; do
    echo ">> fetching $acc"
    if command -v fasterq-dump >/dev/null 2>&1; then
        fasterq-dump --split-files -O "$OUTDIR" "$acc"
    else
        echo "   fasterq-dump not found; skipping download for $acc" >&2
        continue
    fi
    for r in 1 2; do
        f="$OUTDIR/${acc}_${r}.fastq"
        if [ -f "$f" ]; then
            seqtk sample -s100 "$f" "$DEPTH_FRACTION" | gzip > "$OUTDIR/${acc}_${r}.sub.fastq.gz"
            rm -f "$f"
        fi
    done
done

echo ">> done. Subsampled reads are in $OUTDIR/"
echo ">> update assets/samplesheet.csv to point at these files."
