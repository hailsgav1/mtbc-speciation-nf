# Changelog

## v0.2.0 — validated on real data
- Validated end-to-end on a real *M. orygis* isolate (SRR9157804) on HPC
- TB-Profiler now runs from a Galaxy/BioContainers Singularity image
  (self-contained database + Java + snpEff), fixing conda DB-build failures
- RD-Analyzer isolated in a dedicated Python-2 conda env via `withName`
- Fixed SNP-IT invocation (uncompressed VCF via `gzip -cdf`, `--input` flag)
- Hardened the consensus summariser: parses each tool's specific result line
  rather than scanning whole files (prevents sample-name false matches)
- Parameterised conda env paths in `conf/local.config` for portability

## v0.1.0 — initial scaffold
- DSL2 pipeline: QC → map → call → MTBC speciation → report
- Three-way consensus speciation (RD-Analyzer + TB-Profiler + SNP-IT)
- Stub blocks on every process; CI stub-runs the full DAG
- Local / HPC / cloud profiles (cloud stubbed for v2)
