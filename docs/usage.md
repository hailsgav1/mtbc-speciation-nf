# Usage

## Samplesheet
Paired-end Illumina only in v1. Columns: `sample,fastq_1,fastq_2,expected_species`.
Paths may be absolute or relative to the launch directory.

## Running the stub
`nextflow run . -profile test -stub-run` exercises every process and channel
join without needing any bioinformatics tool installed. This is what CI runs.

## Running for real
Install the tools (or wait for the container release), then use `-profile local`
or `-profile hpc`. Provide `--reference` pointing at the H37Rv FASTA; the pipeline
indexes it on first use.

## Reference genome
Download *M. tuberculosis* H37Rv (`NC_000962.3`) and save as
`assets/H37Rv.fasta`, or pass any MTBC reference via `--reference`.
