process FASTQC {
    tag "$meta.id"
    label 'process_low'
    publishDir "${params.outdir}/fastqc", mode: params.publish_dir_mode

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*.html"), emit: html
    tuple val(meta), path("*.zip") , emit: zip
    path "versions.yml"            , emit: versions

    script:
    """
    fastqc --threads $task.cpus ${reads}
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        fastqc: \$(fastqc --version | sed 's/^FastQC v//')
    END_VERSIONS
    """

    stub:
    """
    touch ${meta.id}_fastqc.html
    touch ${meta.id}_fastqc.zip
    touch versions.yml
    """
}
