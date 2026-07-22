include { RD_ANALYZER         } from '../../modules/local/rd_analyzer.nf'
include { RD_REGIONS          } from '../../modules/local/rd_regions.nf'
include { TBPROFILER          } from '../../modules/local/tbprofiler.nf'
include { SNPIT               } from '../../modules/local/snpit.nf'
include { SPECIATION_SUMMARY  } from '../../modules/local/speciation_summary.nf'

//
// MTBC speciation: independent signals, reconciled.
// RD_ANALYZER (legacy, being retired) runs alongside RD_REGIONS (curated
// Bespiatykh 2021 panel) during validation so both calls appear per sample.
//
workflow SPECIATE {
    take:
    reads      // [ meta, [r1,r2] ]
    vcf        // [ meta, vcf ]
    bam        // [ meta, bam, bai ]
    rd_bed     // path to curated RD panel

    main:
    ch_versions = Channel.empty()

    RD_ANALYZER ( reads )
    RD_REGIONS  ( bam, rd_bed )
    TBPROFILER  ( reads )
    SNPIT       ( vcf )

    // join all per-sample calls on meta before reconciling
    ch_combined = RD_ANALYZER.out.rd
        .join( RD_REGIONS.out.rd )
        .join( TBPROFILER.out.json )
        .join( SNPIT.out.snpit )

    SPECIATION_SUMMARY ( ch_combined )

    ch_versions = ch_versions.mix( RD_ANALYZER.out.versions.first() )
    ch_versions = ch_versions.mix( RD_REGIONS.out.versions.first() )
    ch_versions = ch_versions.mix( TBPROFILER.out.versions.first() )
    ch_versions = ch_versions.mix( SNPIT.out.versions.first() )

    emit:
    consensus   = SPECIATION_SUMMARY.out.consensus
    tbprofiler  = TBPROFILER.out.txt
    versions    = ch_versions
}
