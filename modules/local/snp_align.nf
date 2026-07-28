process SNP_ALIGN {
    tag "cohort"
    label 'process_medium'
    publishDir "${params.outdir}/phylo", mode: params.publish_dir_mode

    input:
    path fastas       // all per-sample consensus FASTAs
    path mask         // BED of regions to exclude (PE/PPE, IS, etc.)

    output:
    path "core_snps.aln", emit: alignment
    path "versions.yml" , emit: versions

    when:
    params.run_phylo

    script:
    // Concatenate per-sample pseudo-genomes into a whole-genome alignment,
    // mask repetitive/unreliable regions, then extract variable (SNP) sites.
    // Masking is essential for MTBC: PE/PPE and IS elements produce spurious
    // variants that inflate SNP distances if left in.
    """
    # combine all per-sample pseudo-genomes into one multi-FASTA alignment
    cat ${fastas} > whole_genome.aln

    # mask: set masked positions to N across all samples using bedtools
    if [ -s "${mask}" ]; then
        bedtools maskfasta -fi whole_genome.aln -bed ${mask} -fo whole_genome.masked.aln 2>/dev/null \\
            || cp whole_genome.aln whole_genome.masked.aln
    else
        cp whole_genome.aln whole_genome.masked.aln
    fi

    # extract only variable sites -> core SNP alignment for the tree
    snp-sites -o core_snps.aln whole_genome.masked.aln

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        snp-sites: \$(snp-sites -V 2>&1 | sed 's/snp-sites //')
    END_VERSIONS
    """

    stub:
    """
    printf '>sampleA\nACGT\n>sampleB\nACGA\n' > core_snps.aln
    touch versions.yml
    """
}
