include { SNP_DISTS } from '../../modules/local/snp_dists.nf'
include { IQTREE    } from '../../modules/local/iqtree.nf'

//
// Cohort-level surveillance: SNP distances + optional phylogeny.
// Expects a pre-built multi-sample alignment (placeholder input for v1).
//
workflow RESISTANCE_PHYLO {
    take:
    alignment

    main:
    ch_versions = Channel.empty()

    SNP_DISTS ( alignment )
    IQTREE ( alignment )

    ch_versions = ch_versions.mix( SNP_DISTS.out.versions.first() )

    emit:
    matrix   = SNP_DISTS.out.matrix
    versions = ch_versions
}
