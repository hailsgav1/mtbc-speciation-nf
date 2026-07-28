include { BCF_CONSENSUS } from '../../modules/local/bcf_consensus.nf'
include { SNP_ALIGN     } from '../../modules/local/snp_align.nf'
include { SNP_DISTS     } from '../../modules/local/snp_dists.nf'
include { IQTREE        } from '../../modules/local/iqtree.nf'

//
// Cohort surveillance: per-sample pseudo-genomes -> masked core-SNP
// alignment -> pairwise SNP distances + phylogeny.
// Gated on params.run_phylo (set --run_phylo to enable).
//
workflow RESISTANCE_PHYLO {
    take:
    vcfs        // channel of [ meta, vcf ] per sample
    reference   // H37Rv fasta
    mask        // masking BED (NC_000962.3 coords)

    main:
    ch_versions = Channel.empty()

    // 1. per-sample pseudo-genome (variants applied onto H37Rv)
    BCF_CONSENSUS ( vcfs, reference )
    ch_versions = ch_versions.mix( BCF_CONSENSUS.out.versions.first() )

    // 2. gather all consensus FASTAs, mask, and extract SNP sites
    ch_fastas = BCF_CONSENSUS.out.fasta.map { meta, fa -> fa }.collect()
    SNP_ALIGN ( ch_fastas, mask )
    ch_versions = ch_versions.mix( SNP_ALIGN.out.versions.first() )

    // 3. distances + tree from the core-SNP alignment
    SNP_DISTS ( SNP_ALIGN.out.alignment )
    IQTREE    ( SNP_ALIGN.out.alignment )
    ch_versions = ch_versions.mix( SNP_DISTS.out.versions.first() )

    emit:
    matrix    = SNP_DISTS.out.matrix
    alignment = SNP_ALIGN.out.alignment
    versions  = ch_versions
}
