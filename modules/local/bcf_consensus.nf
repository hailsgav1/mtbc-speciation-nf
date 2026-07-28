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
    // Per-sample pseudo-genome: apply this sample's SNPs onto H37Rv.
    // SNPs ONLY (exclude indels) so every pseudo-genome stays exactly
    // reference-length and positionally aligned — required for a valid
    // multi-sample alignment and for the mask BED coordinates to line up.
    // Contig name stays NC_000962.3; renamed to sample id later (SNP_ALIGN).
    """
    # keep only biallelic SNPs, drop indels
    bcftools view -v snps -m2 -M2 ${vcf} -Oz -o snps.vcf.gz
    bcftools index snps.vcf.gz

    bcftools consensus -f ${reference} snps.vcf.gz > ${meta.id}.consensus.fasta

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
