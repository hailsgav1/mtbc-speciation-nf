include { BWA_MEM       } from '../../modules/local/bwa_mem.nf'
include { BCFTOOLS_CALL } from '../../modules/local/bcftools_call.nf'

workflow MAP_AND_CALL {
    take:
    reads
    reference

    main:
    ch_versions = Channel.empty()

    BWA_MEM ( reads, reference )
    BCFTOOLS_CALL ( BWA_MEM.out.bam, reference )

    ch_versions = ch_versions.mix( BWA_MEM.out.versions.first() )
    ch_versions = ch_versions.mix( BCFTOOLS_CALL.out.versions.first() )

    emit:
    bam      = BWA_MEM.out.bam
    vcf      = BCFTOOLS_CALL.out.vcf
    versions = ch_versions
}
