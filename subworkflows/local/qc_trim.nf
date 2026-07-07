include { FASTQC } from '../../modules/local/fastqc.nf'
include { FASTP  } from '../../modules/local/fastp.nf'

workflow QC_TRIM {
    take:
    reads

    main:
    ch_versions = Channel.empty()

    FASTQC ( reads )
    FASTP  ( reads )

    ch_versions = ch_versions.mix( FASTQC.out.versions.first() )
    ch_versions = ch_versions.mix( FASTP.out.versions.first() )

    emit:
    reads    = FASTP.out.reads
    fastqc   = FASTQC.out.zip
    fastp    = FASTP.out.json
    versions = ch_versions
}
