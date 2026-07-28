process BCF_CONSENSUS {
    tag "$meta.id"
    label 'process_low'
    publishDir "${params.outdir}/phylo/consensus_fasta", mode: params.publish_dir_mode

    input:
    tuple val(meta), path(vcf)
    path reference

    output:
    path "*.consensus.fasta", emit: fasta
    path "versions.yml"     , emit: versions

    when:
    params.run_phylo

    script:
    // Build a per-sample pseudo-genome: apply this sample's variants onto the
    // H37Rv reference. The FASTA header is renamed to the sample id so the
    // downstream alignment carries sample names.
    """
    # bcftools consensus needs a bgzipped + indexed VCF
    if [ "${vcf}" != "${meta.id}.norm.vcf.gz" ]; then
        bcftools view ${vcf} -Oz -o ${meta.id}.norm.vcf.gz
        bcftools index ${meta.id}.norm.vcf.gz
    fi

    bcftools consensus -f ${reference} ${meta.id}.norm.vcf.gz > tmp.fa

    # rename the single contig header to the sample id
    echo ">${meta.id}" > ${meta.id}.consensus.fasta
    grep -v "^>" tmp.fa >> ${meta.id}.consensus.fasta

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bcftools: \$(bcftools --version | head -n1 | sed 's/bcftools //')
    END_VERSIONS
    """

    stub:
    """
    printf '>%s\nACGTACGTACGT\n' "${meta.id}" > ${meta.id}.consensus.fasta
    touch versions.yml
    """
}
