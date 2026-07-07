process RD_ANALYZER {
    tag "$meta.id"
    label 'process_medium'
    publishDir "${params.outdir}/speciation/rd_analyzer", mode: params.publish_dir_mode

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*.rd.txt"), emit: rd
    path "versions.yml"              , emit: versions

    script:
    // RD-Analyzer detects Regions of Difference (presence/absence) to place an
    // isolate within the MTBC. e.g. M. orygis is confirmed by absence of
    // RD7/RD8/RD9/RD10 with presence of RD1/RD4.
    """
    RD-Analyzer.py -o ${meta.id} ${reads} || true
    if [ ! -f ${meta.id}.rd.txt ]; then
        echo "sample\t${meta.id}" > ${meta.id}.rd.txt
        echo "note\tRD-Analyzer produced no output; check install" >> ${meta.id}.rd.txt
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        rd-analyzer: "0.4"
    END_VERSIONS
    """

    stub:
    """
    printf 'sample\t%s\nspecies_call\tMycobacterium_orygis\nRD1\tpresent\nRD4\tpresent\nRD9\tabsent\n' "${meta.id}" > ${meta.id}.rd.txt
    touch versions.yml
    """
}
