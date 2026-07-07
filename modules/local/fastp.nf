process FASTP {
    tag "$meta.id"
    label 'process_medium'
    publishDir "${params.outdir}/fastp", mode: params.publish_dir_mode

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*.trim.fastq.gz"), emit: reads
    tuple val(meta), path("*.json")         , emit: json
    path "versions.yml"                     , emit: versions

    script:
    def r1 = reads[0]
    def r2 = reads[1]
    """
    fastp \\
        --in1 ${r1} --in2 ${r2} \\
        --out1 ${meta.id}_1.trim.fastq.gz \\
        --out2 ${meta.id}_2.trim.fastq.gz \\
        --json ${meta.id}.fastp.json \\
        --thread $task.cpus \\
        --detect_adapter_for_pe

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        fastp: \$(fastp --version 2>&1 | sed -e 's/fastp //g')
    END_VERSIONS
    """

    stub:
    """
    echo | gzip > ${meta.id}_1.trim.fastq.gz
    echo | gzip > ${meta.id}_2.trim.fastq.gz
    touch ${meta.id}.fastp.json
    touch versions.yml
    """
}
