include { RD_ANALYZER         } from '../../modules/local/rd_analyzer.nf'
include { TBPROFILER          } from '../../modules/local/tbprofiler.nf'
include { SNPIT               } from '../../modules/local/snpit.nf'
include { SPECIATION_SUMMARY  } from '../../modules/local/speciation_summary.nf'

//
// The novel core: three independent MTBC species signals, reconciled.
//
workflow SPECIATE {
    take:
    reads      // [ meta, [r1,r2] ]
    vcf        // [ meta, vcf ]

    main:
    ch_versions = Channel.empty()

    RD_ANALYZER ( reads )
    TBPROFILER  ( reads )
    SNPIT       ( vcf )

    // join the three per-sample calls on meta before reconciling
    ch_combined = RD_ANALYZER.out.rd
        .join( TBPROFILER.out.json )
        .join( SNPIT.out.snpit )

    SPECIATION_SUMMARY ( ch_combined )

    ch_versions = ch_versions.mix( RD_ANALYZER.out.versions.first() )
    ch_versions = ch_versions.mix( TBPROFILER.out.versions.first() )
    ch_versions = ch_versions.mix( SNPIT.out.versions.first() )

    emit:
    consensus   = SPECIATION_SUMMARY.out.consensus
    tbprofiler  = TBPROFILER.out.txt
    versions    = ch_versions
}
