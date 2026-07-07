process BCFTOOLS_CALL {
    tag "$meta.id"
    label 'process_medium'
    publishDir "${params.outdir}/variants", mode: params.publish_dir_mode

    input:
    tuple val(meta), path(bam), path(bai)
    path reference

    output:
    tuple val(meta), path("*.vcf.gz"), emit: vcf
    path "versions.yml"              , emit: versions

    script:
    """
    bcftools mpileup -f ${reference} ${bam} \\
        | bcftools call -mv -Oz -o ${meta.id}.vcf.gz
    bcftools index ${meta.id}.vcf.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bcftools: \$(bcftools --version | head -n1 | sed 's/bcftools //')
    END_VERSIONS
    """

    stub:
    """
    echo | gzip > ${meta.id}.vcf.gz
    touch versions.yml
    """
}
