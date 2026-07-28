process SNP_ALIGN {
    tag "cohort"
    label 'process_medium'
    publishDir "${params.outdir}/phylo", mode: params.publish_dir_mode

    input:
    path fastas       // per-sample consensus FASTAs (contig = NC_000962.3), staged as name_*.fasta
    path mask         // BED of regions to exclude (contig = NC_000962.3)

    output:
    path "core_snps.aln", emit: alignment
    path "versions.yml" , emit: versions

    when:
    params.run_phylo

    script:
    // For each sample: mask repetitive regions (while contig name still matches
    // the BED), then rename the record to the sample id. Concatenate all into a
    // whole-genome alignment and extract variable sites with snp-sites.
    """
    for fa in ${fastas}; do
        sample=\$(basename \$fa .consensus.fasta)
        bedtools maskfasta -fi \$fa -bed ${mask} -fo \${sample}.masked.fa
        # rename the single record to the sample id
        echo ">\${sample}" > \${sample}.renamed.fa
        grep -v "^>" \${sample}.masked.fa >> \${sample}.renamed.fa
    done

    cat *.renamed.fa > whole_genome.aln
    snp-sites -o core_snps.aln whole_genome.aln

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        snp-sites: \$(snp-sites -V 2>&1 | sed 's/snp-sites //')
        bedtools: \$(bedtools --version | sed 's/bedtools //')
    END_VERSIONS
    """

    stub:
    """
    printf '>sampleA\nACGT\n>sampleB\nACGA\n' > core_snps.aln
    touch versions.yml
    """
}
