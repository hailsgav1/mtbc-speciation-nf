process SNPIT {
    tag "$meta.id"
    label 'process_low'
    publishDir "${params.outdir}/speciation/snpit", mode: params.publish_dir_mode

    input:
    tuple val(meta), path(vcf)

    output:
    tuple val(meta), path("*.snpit.txt"), emit: snpit
    path "versions.yml"                 , emit: versions

    script:
    // SNP-IT assigns MTBC lineage/species from a whole-genome SNP barcode,
    // giving an independent second opinion to reconcile with RD-Analyzer.
    // Command is snpit-run.py; -i takes a VCF aligned to H37Rv (NC000962).
    """
    snpit-run.py -i ${vcf} -o ${meta.id}.snpit.txt || \\
        echo "${meta.id}\tunknown\tNA" > ${meta.id}.snpit.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        snpit: "1.1"
    END_VERSIONS
    """

    stub:
    """
    printf '%s\tMycobacterium_orygis\t0.98\n' "${meta.id}" > ${meta.id}.snpit.txt
    touch versions.yml
    """
}
