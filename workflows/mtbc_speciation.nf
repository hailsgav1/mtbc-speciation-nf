include { INPUT_CHECK   } from '../subworkflows/local/input_check.nf'
include { QC_TRIM       } from '../subworkflows/local/qc_trim.nf'
include { MAP_AND_CALL  } from '../subworkflows/local/map_and_call.nf'
include { SPECIATE      } from '../subworkflows/local/speciate.nf'
include { MULTIQC       } from '../modules/local/multiqc.nf'

workflow MTBC_SPECIATION {

    main:

    ch_versions = Channel.empty()
    reference   = file(params.reference, checkIfExists: true)

    // 1. read the samplesheet
    INPUT_CHECK ( params.input )

    // 2. QC + trim
    QC_TRIM ( INPUT_CHECK.out.reads )
    ch_versions = ch_versions.mix( QC_TRIM.out.versions )

    // 3. map to H37Rv + call variants
    MAP_AND_CALL ( QC_TRIM.out.reads, reference )
    ch_versions = ch_versions.mix( MAP_AND_CALL.out.versions )

    // 4. MTBC speciation core (RD + TB-Profiler + SNP-IT -> consensus)
    SPECIATE ( QC_TRIM.out.reads, MAP_AND_CALL.out.vcf )
    ch_versions = ch_versions.mix( SPECIATE.out.versions )

    // 5. aggregate report
    ch_multiqc = QC_TRIM.out.fastqc.map { it[1] }
        .mix( QC_TRIM.out.fastp.map { it[1] } )
        .collect()
    MULTIQC ( ch_multiqc )

    emit:
    consensus = SPECIATE.out.consensus
    report    = MULTIQC.out.report
}
