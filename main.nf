#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    mtbc-speciation-nf
    A Nextflow DSL2 pipeline for zoonotic TB genomic surveillance with
    full Mycobacterium tuberculosis complex (MTBC) speciation.
    Github: https://github.com/hailsgav1/mtbc-speciation-nf
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

nextflow.enable.dsl = 2

include { MTBC_SPECIATION } from './workflows/mtbc_speciation.nf'

workflow {
    MTBC_SPECIATION ()
}

workflow.onComplete {
    def where = "${params.outdir}/speciation/consensus/"
    println ( workflow.success
        ? "Done. Consensus species calls are in ${where}"
        : "Pipeline failed - see .nextflow.log for details" )
}
