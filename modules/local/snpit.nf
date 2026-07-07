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
    """
    gzip -dc ${vcf} > ${meta.id}.vcf || cp ${vcf} ${meta.id}.vcf
    snpit --input ${meta.id}.vcf > ${meta.id}.snpit.txt || \\
        echo "${meta.id}\tunknown\tNA" > ${meta.id}.snpit.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        snpit: "1.1.0"
    END_VERSIONS
    """

    stub:
    """
    printf '%s\tMycobacterium_orygis\t0.98\n' "${meta.id}" > ${meta.id}.snpit.txt
    touch versions.yml
    """
}
