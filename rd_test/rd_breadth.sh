#!/usr/bin/env bash
# RD presence/absence by coverage breadth over Bespiatykh et al. 2021 RD panel.
# Usage: rd_breadth.sh <bam> <rd.bed> [depth_cutoff] [samtools_path]
set -euo pipefail
BAM="$1"; BED="$2"; CUT="${3:-14}"; ST="${4:-samtools}"
printf "region\tpass\ttotal\tfraction\n"
while read -r chrom start end name; do
    "$ST" depth -a -r "${chrom}:$((start+1))-${end}" "$BAM" \
    | awk -v n="$name" -v cut="$CUT" '
        {tot++; if($3>=cut) pass++}
        END{printf "%s\t%d\t%d\t%.3f\n", n, pass+0, tot+0, (tot>0)?(pass+0)/tot:0}'
done < "$BED"
