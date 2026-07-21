//
// Parse the samplesheet into [ meta, [reads] ] channels
//
workflow INPUT_CHECK {
    take:
    samplesheet   // path to samplesheet.csv

    main:
    reads = Channel
        .fromPath(samplesheet)
        .splitCsv(header: true)
        .map { row ->
            def meta = [
                id       : row.sample,
                expected : row.expected_species ?: 'unknown',
                host     : row.host            ?: 'NA',
                date     : row.collection_date ?: 'NA',
                country  : row.country         ?: 'NA',
                location : row.location        ?: 'NA'
            ]
            def r1 = file(row.fastq_1, checkIfExists: true)
            def r2 = file(row.fastq_2, checkIfExists: true)
            return [ meta, [ r1, r2 ] ]
        }

    emit:
    reads   // [ meta, [r1, r2] ]
}
