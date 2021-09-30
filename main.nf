#!/usr/bin/env nextflow

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
additionalArgs = ""
if (params.nuclei)
    additionalArgs += " --include-introns"

// read the sample sheet and make three channels from it:
Channel
    .fromPath(params.sample_sheet)
    .splitCsv(header:true)
    .into { sampleSheet1; sampleSheet2; sampleSheet3 }
// one to extract the header from...
keys = sampleSheet1.first().keySet().value
// one to get a list of library ids from for the count process...
sampleSheet2.map { it.library_id }.set { ids }
// and one to use in the aggregate process
sampleSheet3.map { tuple(it.library_id, it) }.set { sampleSheetRows }

process cellranger_count {
    publishDir 'molecule_info'
    cpus 26
    memory '240 GB'

    input:
    val id from ids

    output:
    tuple val(id), file("molecule_info.${id}.h5") into molecule_info

    """
    cellranger count \
        --id=${id} \
        --fastqs=${params.fastqs_dir} \
        --sample=${id} \
        --transcriptome=${params.ref_dir} \
        --localcores=${task.cpus} \
        --localmem=240 \
        --disable-ui ${additionalArgs}
    ln -s \$PWD/${id}/outs/molecule_info.h5 molecule_info.${id}.h5
    """
}

// use the sample sheet and the output of the count process to make
// a new sample sheet for the aggregate process
molecule_info.join(sampleSheetRows).map {
    it[2].remove('library_id')
    values = it[2].values().join(',')
    return [it[0], it[1], values].join(',')
}.collectFile(
    name: 'molecule_info.csv',
    newLine: true,
    seed: "library_id,molecule_h5," + keys.drop(1).join(',')
).set { molecule_info_csv }

process cellranger_aggregate {
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
