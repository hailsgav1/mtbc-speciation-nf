process IQTREE {
    tag "cohort"
    label 'process_high'
    publishDir "${params.outdir}/surveillance", mode: params.publish_dir_mode

    input:
    path alignment

    output:
    path "*.treefile", emit: tree
    path "versions.yml", emit: versions

    when:
    // only build a tree when there are enough isolates to be meaningful
    params.run_phylo

    script:
    """
    iqtree2 -s ${alignment} -m GTR+G -bb 1000 -nt AUTO -pre cohort

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        iqtree: \$(iqtree2 --version | head -n1 | sed 's/IQ-TREE multicore version //' | cut -d' ' -f1)
    END_VERSIONS
    """

    stub:
    """
    echo "(sampleA:0.001,sampleB:0.001);" > cohort.treefile
    touch versions.yml
    """
}
