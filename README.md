[![CI](https://github.com/hailsgav1/mtbc-speciation-nf/actions/workflows/ci.yml/badge.svg)](https://github.com/hailsgav1/mtbc-speciation-nf/actions/workflows/ci.yml)
# mtbc-speciation-nf

A Nextflow DSL2 pipeline for **zoonotic tuberculosis genomic surveillance** with
accurate speciation across the full *Mycobacterium tuberculosis* complex (MTBC).

Most TB pipelines predict drug resistance well but treat species assignment as an
afterthought — which is exactly why animal-adapted members like ***Mycobacterium
orygis*** are routinely misreported as *M. bovis* or *M. tuberculosis*. This
pipeline puts **MTBC speciation at the centre**: it calls the species from three
independent signals and reconciles them, flagging disagreements for review.

> Built as a One Health surveillance tool — the kind of workflow an animal- or
> public-health reference lab actually runs. *M. orygis* is an emerging,
> under-recognised cause of zoonotic TB, and telling it apart from *M. bovis* is
> a documented diagnostic gap.

## What it does

![MTBC speciation pipeline](docs/pipeline.svg)

1. **QC + trim** — FastQC, fastp
2. **Map + call** — bwa-mem to *M. tuberculosis* H37Rv (`NC_000962.3`), bcftools
3. **Speciate (the core)** — RD-Analyzer (Regions of Difference), TB-Profiler
   (sub-lineage + drug resistance vs the WHO catalogue), SNP-IT (SNP barcode),
   reconciled into one consensus call by `bin/speciation_summary.py`
4. **Surveillance** — SNP-distance matrix and optional IQ-TREE phylogeny
5. **Report** — MultiQC summary

## Example result

Validated on a real *M. orygis* isolate from dairy cattle (Chennai, India) —
public accession [`SRR9157804`](https://www.ncbi.nlm.nih.gov/sra/SRR9157804),
mapped to *M. tuberculosis* H37Rv (`NC_000962.3`).

| Tool | Method | Call |
|---|---|---|
| TB-Profiler | SNP barcode + WHO catalogue (containerised) | *M. orygis* (lineage La3, 100%) |
| SNP-IT | whole-genome SNP barcode | *M. orygis* (100%) |
| RD-Analyzer | Regions of Difference (legacy) | *M. caprae* |
| **Consensus** | **majority vote** | ***M. orygis*** *(agreement: conflict flagged)* |

Two independent modern methods agree on *M. orygis*, while the older
RD-based tool calls *M. caprae* — the exact animal-lineage ambiguity this
pipeline is built to surface. The consensus reports *M. orygis* by majority
**and** flags the disagreement rather than hiding it, so a reviewer sees both
the call and the uncertainty.

> This is why speciation is the core of the pipeline: a single tool can
> confidently mis-call an emerging zoonotic agent. Cross-method consensus
> catches it.

## Software environment

A hybrid strategy keeps each tool in a working environment:

- **Most processes** run from one conda env (`environment.yml`).
- **RD-Analyzer** is a legacy Python 2 tool, so it runs in its own isolated
  conda env (assigned per-process via `withName` in `conf/local.config`).
- **TB-Profiler** runs from a Galaxy/BioContainers **Singularity image**, so its
  database, Java, and snpEff are self-contained and version-matched — sidestepping
  the fragile conda database build entirely.

## Quick start

```bash
# 1. Test the wiring with no tools or data (stub run)
nextflow run . -profile test -stub-run

# 2. Build the main env, plus a Python-2 env for RD-Analyzer
conda env create -f environment.yml
conda create -n rd-analyzer-env -c bioconda -c conda-forge rd-analyzer python=2.7 -y

# 3. Fetch the reference + a real M. orygis isolate
datasets download genome accession GCF_000195955.2 --include genome
unzip -o ncbi_dataset.zip && cp ncbi_dataset/data/GCF_000195955.2/*.fna assets/H37Rv.fasta
prefetch SRR9157804 && fasterq-dump --split-files SRR9157804 -O testdata && gzip testdata/*.fastq

# 4. Run (conda for most tools, container for TB-Profiler, all wired in the local profile)
conda activate mtbc-speciation
nextflow run . -profile local \
  --input assets/samplesheet.csv \
  --reference assets/H37Rv.fasta \
  --outdir results
```

## Input

A CSV samplesheet:

```csv
sample,fastq_1,fastq_2,expected_species
orygis_cattle_IN,SRR9157804_1.fastq.gz,SRR9157804_2.fastq.gz,Mycobacterium_orygis
```

`expected_species` is optional and only used to cross-check the consensus call.

## Test data (verified public accessions)

| Species | Accession | Source |
|---|---|---|
| *M. orygis* | `SRR9157804` (PRJNA545406) | dairy cattle, Chennai, India |
| *M. orygis* (more) | `PRJNA934340`, `PRJNA785380` | human + multiple animal hosts |
| mixed MTBC | `PRJNA575883` | incl. *M. orygis*, *M. bovis* BCG, *M. tuberculosis* |
| reference | `NC_000962.3` | *M. tuberculosis* H37Rv (mapping ref) |
| reference | `NC_002945.4` / `LT708304` | *M. bovis* AF2122/97 |

For the remaining panel members, `bin/fetch_testdata.sh` documents ENA queries
(species + `ILLUMINA` + `WGS`) rather than hard-coding runs that may change.

## Profiles

| Profile | Executor | Notes |
|---|---|---|
| `test` | local | tiny bundled data, pair with `-stub-run` |
| `local` | local | conda + Singularity hybrid (validated on UA HPC) |
| `hpc` | SLURM | per-process SLURM submission |
| `cloud` | AWS Batch | **v2 stub** — see roadmap |

## Roadmap

- [x] DSL2 modular pipeline, stub-testable in CI
- [x] Full MTBC speciation with three-way consensus
- [x] TB-Profiler containerised (Singularity) and validated on real data
- [ ] **Replace RD-Analyzer** with a coverage-based RD caller using the curated
      RDscan panel (Bespiatykh et al. 2021) — proof-of-method in [`rd_test/`](rd_test/)
- [ ] Add host/date/location metadata and a mixed human + animal cohort
- [ ] Wire in the cohort phylogeny (SNP alignment → IQ-TREE)
- [ ] Microreact export (tree + metadata)
- [ ] Containerise the remaining processes and wire into CI
      (images will publish under `docker.io/biowizardhailey/mtbc-speciation-*`)
- [ ] Enable the AWS Batch profile
- [ ] `nextflow_schema.json` polish for Seqera Platform launch

## Notes and honest caveats

- Virulent *M. bovis* and rarer members (*M. caprae*, *M. africanum*) have far
  fewer public genomes than *M. tuberculosis*, so a balanced full-panel test set
  is hard — the demo set may carry a single isolate for rare species.
- RD-Analyzer's 30-region panel contains **no *M. orygis* marker**, so it calls
  this isolate *M. caprae* — it cannot report a species it has no region for.
  The curated RDscan panel does contain orygis regions (`RDoryx_1`, `RD12oryx`,
  `RDoryx_4`), and coverage analysis confirms `RDoryx_1` is cleanly deleted here
  (1/9562 positions) — see [`rd_test/`](rd_test/). This vocabulary gap is exactly
  what the pipeline exists to expose, and why RD-Analyzer is being replaced.
- Drug-resistance calls follow the WHO mutation catalogue via TB-Profiler; the
  catalogue is periodically updated, so pin the TB-Profiler DB version you use.

## License

MIT — see `LICENSE`.
