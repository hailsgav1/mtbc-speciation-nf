include { BCF_CONSENSUS     } from '../../modules/local/bcf_consensus.nf'
include { SNP_ALIGN         } from '../../modules/local/snp_align.nf'
include { SNP_DISTS         } from '../../modules/local/snp_dists.nf'
include { IQTREE            } from '../../modules/local/iqtree.nf'
include { MICROREACT_EXPORT } from '../../modules/local/microreact_export.nf'

//
// Cohort surveillance: per-sample pseudo-genomes -> masked core-SNP
// alignment -> pairwise SNP distances + phylogeny + Microreact export.
// Gated on params.run_phylo.
//
workflow RESISTANCE_PHYLO {
    take:
    vcfs        // channel of [ meta, vcf ] per sample
    reference   // H37Rv fasta
    mask        // masking BED (NC_000962.3 coords)
    consensus   // channel of [ meta, consensus.tsv ] per sample (for metadata)

    main:
    ch_versions = Channel.empty()

    BCF_CONSENSUS ( vcfs, reference )
    ch_versions = ch_versions.mix( BCF_CONSENSUS.out.versions.first() )

    ch_fastas = BCF_CONSENSUS.out.fasta.map { meta, fa -> fa }.collect()
    SNP_ALIGN ( ch_fastas, mask )
    ch_versions = ch_versions.mix( SNP_ALIGN.out.versions.first() )

    SNP_DISTS ( SNP_ALIGN.out.alignment )
    IQTREE    ( SNP_ALIGN.out.alignment )
    ch_versions = ch_versions.mix( SNP_DISTS.out.versions.first() )

    // Microreact bundle: tree + metadata CSV from per-sample consensus calls
    ch_meta_tsvs = consensus.map { meta, tsv -> tsv }.collect()
    MICROREACT_EXPORT ( ch_meta_tsvs, IQTREE.out.tree )

    emit:
    matrix    = SNP_DISTS.out.matrix
    alignment = SNP_ALIGN.out.alignment
    versions  = ch_versions
}
