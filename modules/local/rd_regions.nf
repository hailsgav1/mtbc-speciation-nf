process RD_REGIONS {
    tag "$meta.id"
    label 'process_medium'
    publishDir "${params.outdir}/speciation/rd_regions", mode: params.publish_dir_mode

    input:
    tuple val(meta), path(bam), path(bai)
    path rd_bed

    output:
    tuple val(meta), path("*.rd_regions.tsv"), emit: rd
    path "versions.yml"                      , emit: versions

    script:
    // Coverage-breadth RD speciation over the curated Bespiatykh et al. 2021
    // panel. Classifier applies the diagnostic logic (animal gate -> orygis
    // markers RD301/RD315 -> caprae/bovis exclusions). Replaces RD-Analyzer.
    """
    rd_classify.py \\
        --bam ${bam} \\
        --bed ${rd_bed} \\
        --sample ${meta.id} \\
        --out ${meta.id}.rd_regions.tsv \\
        --samtools \$(which samtools)

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: \$(samtools --version | head -n1 | sed 's/samtools //')
        rd_panel: "Bespiatykh 2021 (RDscan)"
    END_VERSIONS
    """

    stub:
    """
    printf 'sample\tspecies_call\tmedian_depth\tcutoff\treason\n%s\tMycobacterium_orygis\t100\t10\tstub\n' "${meta.id}" > ${meta.id}.rd_regions.tsv
    touch versions.yml
    """
}
