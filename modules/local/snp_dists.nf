process SNP_DISTS {
    tag "cohort"
    label 'process_low'
    publishDir "${params.outdir}/surveillance", mode: params.publish_dir_mode

    input:
    path alignment

    output:
    path "snp_distance_matrix.tsv", emit: matrix
    path "versions.yml"           , emit: versions

    script:
    """
    snp-dists ${alignment} > snp_distance_matrix.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        snp-dists: \$(snp-dists -v | sed 's/snp-dists //')
    END_VERSIONS
    """

    stub:
    """
    printf 'snp-dists\tsampleA\tsampleB\nsampleA\t0\t12\nsampleB\t12\t0\n' > snp_distance_matrix.tsv
    touch versions.yml
    """
}
