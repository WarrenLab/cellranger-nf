#!/usr/bin/env nextflow
nextflow.enable.dsl = 2

// path to a directory containing raw fastq files
params.fastqs_dir = '/path/to/fastqs'

// path to the directory containing the CellRanger
// reference
params.ref_dir = '/path/to/cellranger/ref'

// Replace this with a table of the ID's of the samples to analyze, plus any
// additional relevant information about each sample. The sample ID must be
// the first field, and the header should call this field 'library_id'. For
// example, the first few lines might look like this:
//
// library_id,treated
// C3,control
// C4,treatment
// C5,control
// C6,treatment
params.sample_sheet = 'samples.csv'
// set the --nuclei argument to include introns for nucelus preps

process crCount {
    publishDir 'molecule_info'
    cpus 26
    memory '240 GB'

    input:
    val id

    output:
    tuple val(id), file("molecule_info.${id}.h5")

    """
    cellranger count \
        --id=${id} \
        --fastqs=${fastqs_dir} \
        --sample=${id} \
        --transcriptome=${ref_dir} \
        --localcores=${task.cpus} \
        --localmem=240 \
        --disable-ui ${additionalArgs}
    ln -s \$PWD/${id}/outs/molecule_info.h5 molecule_info.${id}.h5
    """
}

process aggregate {
    publishDir 'aggregated', mode: 'copy'
    cpus 16

    input:
    file "molecule_info.csv" from molecule_info_csv

    output:
    file "aggregated/outs" into aggregated

    """
    cellranger aggr --id=aggregated --csv=molecule_info.csv
    """
}

workflow {
    additionalArgs = ""
    if (params.nuclei)
        additionalArgs += " --include-introns"
    
    fastqs_dir = file(params.fastqs_dir)
    ref_dir = file(params.ref_dir)
    
    // read the sample sheet
    sampleSheet = Channel
        .fromPath(params.sample_sheet)
        .splitCsv(header:true)
    sampleSheet.println()
    // extract the header from the sample sheet
    keys = sampleSheet.first().keySet().value
    // run the count process on a list of library IDs
    crCount(sampleSheet.map { it.library_id })

    // use the sample sheet and the output of the count process to make
    // a new sample sheet for the aggregate process
    crCount.out.join(sampleSheet.map { tuple(it.library_id, it) }).map {
        it[2].remove('library_id')
        values = it[2].values().join(',')
        return [it[0], it[1], values].join(',')
    }.collectFile(
        name: 'molecule_info.csv',
        newLine: true,
        seed: "library_id,molecule_h5," + keys.drop(1).join(',')
    ).set { molecule_info_csv }

    aggregate(molecule_info_csv)
}
