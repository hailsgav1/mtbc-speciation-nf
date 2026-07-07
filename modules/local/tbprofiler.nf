process TBPROFILER {
    tag "$meta.id"
    label 'process_high'
    publishDir "${params.outdir}/speciation/tbprofiler", mode: params.publish_dir_mode

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("results/*.results.json"), emit: json
    tuple val(meta), path("results/*.results.txt") , emit: txt
    path "versions.yml"                            , emit: versions

    script:
    // TB-Profiler calls lineage/sub-species and drug resistance against the
    // WHO mutation catalogue in a single pass.
    def r1 = reads[0]
    def r2 = reads[1]
    """
    tb-profiler profile \\
        -1 ${r1} -2 ${r2} \\
        --prefix ${meta.id} \\
        --threads $task.cpus \\
        --txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        tb-profiler: \$(tb-profiler version 2>&1 | sed 's/TBProfiler version //')
    END_VERSIONS
    """

    stub:
    """
    mkdir -p results
    echo '{"id":"${meta.id}","sublin":"La1.8.1 (M.orygis)","dr_variants":[]}' > results/${meta.id}.results.json
    echo "${meta.id}\tLa1.8.1\tSusceptible" > results/${meta.id}.results.txt
    touch versions.yml
    """
}
