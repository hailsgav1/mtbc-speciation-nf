process BCF_CONSENSUS {
    tag "$meta.id"
    label 'process_low'
    publishDir "${params.outdir}/phylo/consensus_fasta", mode: params.publish_dir_mode

    input:
    tuple val(meta), path(vcf)
    path reference

    output:
    tuple val(meta), path("*.consensus.fasta"), emit: fasta
    path "versions.yml"                        , emit: versions

    when:
    params.run_phylo

    script:
    // Per-sample pseudo-genome: apply this sample's variants onto H37Rv.
    // Contig name is kept as the reference name (NC_000962.3) so the mask BED
    // matches; renaming to the sample id happens after masking (SNP_ALIGN).
    """
    bcftools view ${vcf} -Oz -o norm.vcf.gz
    bcftools index norm.vcf.gz
    bcftools consensus -f ${reference} norm.vcf.gz > ${meta.id}.consensus.fasta

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bcftools: \$(bcftools --version | head -n1 | sed 's/bcftools //')
    END_VERSIONS
    """

    stub:
    """
    printf '>NC_000962.3\nACGTACGTACGT\n' > ${meta.id}.consensus.fasta
    touch versions.yml
    """
}
