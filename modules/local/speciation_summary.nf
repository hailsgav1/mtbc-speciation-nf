process SPECIATION_SUMMARY {
    tag "$meta.id"
    label 'process_low'
    publishDir "${params.outdir}/speciation/consensus", mode: params.publish_dir_mode

    input:
    tuple val(meta), path(rd), path(tbprofiler_json), path(snpit)

    output:
    tuple val(meta), path("*.consensus.tsv"), emit: consensus
    path "versions.yml"                     , emit: versions

    script:
    // Reconcile the three independent species signals into one confident call
    // and flag disagreements. Sample metadata is passed through to the output
    // so the consensus TSV is Microreact-ready.
    """
    speciation_summary.py \\
        --sample ${meta.id} \\
        --rd ${rd} \\
        --tbprofiler ${tbprofiler_json} \\
        --snpit ${snpit} \\
        --host '${meta.host}' \\
        --date '${meta.date}' \\
        --country '${meta.country}' \\
        --location '${meta.location}' \\
        --out ${meta.id}.consensus.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version 2>&1 | sed 's/Python //')
    END_VERSIONS
    """

    stub:
    """
    printf 'sample\thost\tcollection_date\tcountry\tlocation\trd_call\ttbprofiler_call\tsnpit_call\tconsensus\tagreement\n%s\tNA\tNA\tNA\tNA\tM.orygis\tM.orygis\tM.orygis\tMycobacterium_orygis\tfull\n' "${meta.id}" > ${meta.id}.consensus.tsv
    touch versions.yml
    """
}
