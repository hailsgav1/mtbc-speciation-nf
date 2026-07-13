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
    // SNP-IT assigns MTBC lineage/species from a whole-genome SNP barcode.
    // snpit-run.py needs an UNCOMPRESSED VCF aligned to H37Rv (NC000962).
    // gzip -cdf handles both .vcf.gz and plain .vcf without erroring.
    """
    gzip -cdf ${vcf} > ${meta.id}.input.vcf

    if snpit-run.py --input ${meta.id}.input.vcf > ${meta.id}.snpit.txt; then
        :
    else
        echo -e "sample\tunknown\tNA" > ${meta.id}.snpit.txt
    fi

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
