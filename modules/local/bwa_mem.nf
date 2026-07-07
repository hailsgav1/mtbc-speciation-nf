process BWA_MEM {
    tag "$meta.id"
    label 'process_high'
    publishDir "${params.outdir}/alignment", mode: params.publish_dir_mode

    input:
    tuple val(meta), path(reads)
    path reference

    output:
    tuple val(meta), path("*.sorted.bam"), path("*.sorted.bam.bai"), emit: bam
    path "versions.yml"                                            , emit: versions

    script:
    """
    if [ ! -f ${reference}.bwt ]; then bwa index ${reference}; fi
    bwa mem -t $task.cpus -R "@RG\\tID:${meta.id}\\tSM:${meta.id}\\tPL:ILLUMINA" \\
        ${reference} ${reads} | samtools sort -@ $task.cpus -o ${meta.id}.sorted.bam -
    samtools index ${meta.id}.sorted.bam

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bwa: \$(bwa 2>&1 | grep Version | sed 's/Version: //')
        samtools: \$(samtools --version | head -n1 | sed 's/samtools //')
    END_VERSIONS
    """

    stub:
    """
    touch ${meta.id}.sorted.bam
    touch ${meta.id}.sorted.bam.bai
    touch versions.yml
    """
}
