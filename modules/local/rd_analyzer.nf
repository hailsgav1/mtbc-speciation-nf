process RD_ANALYZER {
    tag "$meta.id"
    label 'process_medium'
    publishDir "${params.outdir}/speciation/rd_analyzer", mode: params.publish_dir_mode

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*.rd.txt"), emit: rd
    path "versions.yml"              , emit: versions

    script:
    // RD-Analyzer (Python 2) detects Regions of Difference from reads using its
    // own bundled RDs30.fasta, and writes <prefix>.result. Conda env is assigned
    // per-process in conf/local.config (withName: RD_ANALYZER), so `python` and
    // `RD-Analyzer.py` here are the env's Python 2 versions.
    def r1 = reads[0]
    def r2 = reads[1]
    """
    RD-Analyzer.py -o ${meta.id} ${r1} ${r2} || true

    # RD-Analyzer writes ${meta.id}.result; normalise it to a *.rd.txt with a
    # species_call line the summariser can parse.
    if [ -f ${meta.id}.result ]; then
        cp ${meta.id}.result ${meta.id}.rd.txt
        species=\$(grep -i "Species" ${meta.id}.result | tail -n1 | awk -F'\\t' '{print \$NF}')
        echo "species_call\t\${species}" >> ${meta.id}.rd.txt
    else
        printf 'sample\t%s\nspecies_call\tunknown\n' "${meta.id}" > ${meta.id}.rd.txt
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        rd-analyzer: "1.01"
    END_VERSIONS
    """

    stub:
    """
    printf 'sample\t%s\nspecies_call\tMycobacterium_orygis\nRD1\tpresent\nRD9\tabsent\n' "${meta.id}" > ${meta.id}.rd.txt
    touch versions.yml
    """
}
