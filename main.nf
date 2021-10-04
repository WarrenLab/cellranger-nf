#!/usr/bin/env nextflow
nextflow.enable.dsl = 2

// path to a directory containing raw fastq files
params.fastqs_dir = '/path/to/fastqs'

// path to the directory containing the CellRanger
// reference
params.ref_dir = '/path/to/cellranger/ref'

// Replace this with a table of the ID's of the samples to analyze, plus any
// additional relevant information about each sample. The sample ID must be
// the first field, and the header should call this field 'sample_id'. For
// example, the first few lines might look like this:
//
// sample_id,treated
// C3,control
// C4,treatment
// C5,control
// C6,treatment
params.sampleSheet = 'samples.csv'
// set the --nuclei argument to include introns for nucelus preps
additionalArgs = ""
if (params.nuclei)
    additionalArgs += " --include-introns"

fastqs_dir = file(params.fastqs_dir)
ref_dir = file(params.ref_dir)

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
    file "molecule_info.csv"

    output:
    file "aggregated/outs"

    """
    cellranger aggr --id=aggregated --csv=molecule_info.csv
    """
}

workflow {
    // read the sample sheet
    sampleSheet = Channel
        .fromPath(params.sampleSheet)
        .splitCsv(header:true)
    // run the count process on a list of library IDs
    crCount(sampleSheet.map { it.sample_id })
    
    // extract the header from the sample sheet
    def keys
    new File(params.sampleSheet).withReader { 
        keys = it.readLine().split(',').drop(1)
    }

    // use the sample sheet and the output of the count process to make
    // a new sample sheet for the aggregate process
    crCount.out.join(sampleSheet.map { tuple(it.sample_id, it) }).map {
        it[2].remove('sample_id')
        values = it[2].values().join(',')
        return [it[0], it[1], values].join(',')
    }.collectFile(
        name: 'molecule_info.csv',
        newLine: true,
        seed: "sample_id,molecule_h5," + keys.join(',')
    ).set { moleculeInfo }

    aggregate(moleculeInfo)
}
