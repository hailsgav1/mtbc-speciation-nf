# Output

```
results/
├── fastqc/                      raw-read QC
├── fastp/                       trimming reports
├── alignment/                   sorted BAMs
├── variants/                    per-sample VCFs
├── speciation/
│   ├── rd_analyzer/             Regions of Difference calls
│   ├── tbprofiler/              lineage + drug-resistance
│   ├── snpit/                   SNP-barcode calls
│   └── consensus/              *.consensus.tsv  <- the headline result
├── surveillance/                SNP-distance matrix, optional tree
└── multiqc/                     aggregate HTML report
```

The key file is `speciation/consensus/<sample>.consensus.tsv`, with columns:
`sample, rd_call, tbprofiler_call, snpit_call, consensus, agreement`.
An `agreement` of `conflict` means the three tools disagreed — review manually.
