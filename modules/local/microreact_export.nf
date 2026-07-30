process MICROREACT_EXPORT {
    tag "cohort"
    label 'process_low'
    publishDir "${params.outdir}/surveillance", mode: params.publish_dir_mode

    input:
    path consensus_tsvs   // all per-sample *.consensus.tsv
    path tree             // cohort.treefile

    output:
    path "microreact_metadata.csv", emit: metadata
    path "microreact_tree.nwk"    , emit: tree
    path "versions.yml"           , emit: versions

    when:
    params.run_phylo

    script:
    // Build a Microreact-ready metadata CSV from the per-sample consensus TSVs.
    // Microreact keys rows to tree tips by an 'id' column matching the Newick
    // tip labels (which are the sample ids). Tree is copied as .nwk alongside.
    """
    python3 <<'PY'
    import csv, glob, os

    rows = []
    header = None
    for f in sorted(glob.glob("*.consensus.tsv")):
        with open(f) as fh:
            r = list(csv.reader(fh, delimiter="\\t"))
        if len(r) < 2:
            continue
        if header is None:
            header = r[0]
        rows.append(r[1])

    # rename 'sample' -> 'id' for Microreact tip matching
    out_header = ["id" if c == "sample" else c for c in header]

    with open("microreact_metadata.csv", "w", newline="") as out:
        w = csv.writer(out)
        w.writerow(out_header)
        w.writerows(rows)
    PY

    cp ${tree} microreact_tree.nwk

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //')
    END_VERSIONS
    """

    stub:
    """
    printf 'id,host,consensus\nsampleA,Homo sapiens,Mycobacterium_orygis\n' > microreact_metadata.csv
    echo "(sampleA:0.001,sampleB:0.001);" > microreact_tree.nwk
    touch versions.yml
    """
}
