process MULTIQC {
    tag "report"
    label 'process_low'
    publishDir "${params.outdir}/multiqc", mode: params.publish_dir_mode

    input:
    path '*'

    output:
    path "multiqc_report.html", emit: report
    path "versions.yml"       , emit: versions

    script:
    """
    multiqc . -n multiqc_report.html

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        multiqc: \$(multiqc --version | sed 's/multiqc, version //')
    END_VERSIONS
    """

    stub:
    """
    echo "<html><body>MTBC speciation report (stub)</body></html>" > multiqc_report.html
    touch versions.yml
    """
}
