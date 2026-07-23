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

Validated on four public isolates spanning three MTBC species, two hosts, and
three continents. All calls are from a single pipeline run; raw output is in
[`rd_test/validation_4species.tsv`](rd_test/validation_4species.tsv).

| Isolate | Host / origin | RD-Analyzer *(legacy)* | **RD_REGIONS** *(this pipeline)* | TB-Profiler | SNP-IT | Consensus |
|---|---|---|---|---|---|---|
| [`SRR9157804`](https://www.ncbi.nlm.nih.gov/sra/SRR9157804) | *Bos taurus*, India | ❌ *M. caprae* | ✅ ***M. orygis*** | *M. orygis* | *M. orygis* | *M. orygis* (full) |
| [`SRR23445127`](https://www.ncbi.nlm.nih.gov/sra/SRR23445127) | *Homo sapiens*, Canada | ❌ *M. caprae* | ✅ ***M. orygis*** | *M. orygis* | *M. orygis* | *M. orygis* (full) |
| [`ERR016861`](https://www.ebi.ac.uk/ena/browser/view/ERR016861) | *M. bovis* | ✅ *M. bovis* | ✅ ***M. bovis*** | *M. bovis* | *M. bovis* | *M. bovis* (full) |
| [`DRR019437`](https://www.ncbi.nlm.nih.gov/sra/DRR019437) | *Homo sapiens*, Japan | ✅ *M. tuberculosis* | ✅ ***M. tuberculosis*** | *M. tuberculosis* | *M. tuberculosis* | *M. tuberculosis* (full) |

**RD_REGIONS: 4/4. RD-Analyzer: 3/4 — wrong only on *M. orygis*.**

That asymmetry is the point. RD-Analyzer is not a broken tool: it calls
*M. bovis* and *M. tuberculosis* correctly. It fails on *M. orygis* specifically,
because its 30-region panel contains **no orygis marker** — so it silently
reports the nearest species it is able to name. Both orygis isolates, from
different hosts and continents, fail the same way.

Replacing it with a coverage-based caller over the curated RDscan panel
(Bespiatykh et al. 2021) resolves this: `RD_REGIONS` interrogates the
orygis-specific regions **RD301** and **RD315** directly, with *M. caprae*
(RD305) and *M. bovis* (RD4, RDbovis) as explicit exclusions.

> This is the pipeline's reason for existing: an emerging zoonotic agent can be
> confidently mis-called by a tool that simply has no name for it, and the error
> is invisible without a second, methodologically independent signal.

**RD_REGIONS: 4/4. RD-Analyzer: 3/4 — wrong only on *M. orygis*.**

That asymmetry is the point. RD-Analyzer is not a broken tool: it calls
*M. bovis* and *M. tuberculosis* correctly. It fails on *M. orygis* specifically,
because its 30-region panel contains **no orygis marker** — so it silently
reports the nearest species it is able to name. Both orygis isolates, from
different hosts and continents, fail the same way.

Replacing it with a coverage-based caller over the curated RDscan panel
(Bespiatykh et al. 2021) resolves this: `RD_REGIONS` interrogates the
orygis-specific regions **RD301** and **RD315** directly, with *M. caprae*
(RD305) and *M. bovis* (RD4, RDbovis) as explicit exclusions.

> This is the pipeline's reason for existing: an emerging zoonotic agent can be
> confidently mis-called by a tool that simply has no name for it, and the error
> is invisible without a second, methodologically independent signal.

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
- [x] TB-Profiler containerised (Singularity) and validated on real data
- [x] Host/date/location metadata carried through to the consensus output
- [x] Mixed human + animal cohort
- [x] **RD-Analyzer replaced** by `RD_REGIONS`, a coverage-based caller over the
      curated RDscan panel (Bespiatykh et al. 2021) — validated 4/4 across
      *M. orygis*, *M. bovis*, and *M. tuberculosis*
- [ ] Cohort phylogeny: masked SNP alignment → `snp-dists` → IQ-TREE, with
      published transmission thresholds (3–14 SNPs animal, 0–6 SNPs single-source)
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
