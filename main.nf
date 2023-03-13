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
params.cellbender = false

fastqs_dir = file(params.fastqs_dir)
ref_dir = file(params.ref_dir)

process CR_COUNT {
    input:
    tuple(val(id), val(expectedCells))

    output:
    tuple (val(id), path("molecule_info.${id}.h5"), emit: moleculeInfo)
    tuple (val(id), path("*.${id}.*"), emit: allFiles)

    """
    cellranger count \
        --id=${id} \
        --fastqs=${fastqs_dir} \
        --sample=${id} \
        --transcriptome=${ref_dir} \
        --localcores=${task.cpus} \
        --localmem=${(task.memory.toGiga() * 0.9).intValue()} \
        --disable-ui \
        ${expectedCells > 0 ? "--expect-cells $expectedCells" : ""}
    ln -s \$PWD/${id}/outs/molecule_info.h5 molecule_info.${id}.h5
    ln -s \$PWD/${id}/outs/raw_feature_bc_matrix.h5 raw_feature_bc_matrix.${id}.h5
    ln -s \$PWD/${id}/outs/web_summary.html web_summary.${id}.html
    ln -s \$PWD/${id}/outs/metrics_summary.csv metrics_summary.${id}.csv
    """
}

process CR_AGGREGATE {
    input:
    path("molecule_info.csv")

    output:
    path("aggregated/outs")

    """
    cellranger aggr --id=aggregated --csv=molecule_info.csv
    """
}

process GET_CR_CELLS_ESTIMATE {
    input:
    tuple val(id), path(inputFiles)

    output:
    tuple val(id), env(expectedCells)

    """
    expectedCells=\$(get_expected_cells.py metrics_summary.${id}.csv)
    """
}

process CELLBENDER {
    input:
    tuple val(id), path(inputFiles), val(expectedCells)

    output:
    path("${id}.cellbender_filtered.h5")

    """
    cellbender remove-background \
        --input raw_feature_bc_matrix.${id}.h5 \
        --output ${id}.cellbender.h5 \
        --cuda \
        --expected-cells $expectedCells
    """
}

process MAKE_AGGREGATION_TABLE {
    input:
    path(sampleSheetCsv)
    path(allMetricsSummaries)

    output:
    path("aggregation_table.csv")

    """
    make_cellbender_aggregation_table.py \
        ${sampleSheetCsv} \
        metrics_summary.*.csv \
        > aggregation_table.csv
    """
}

workflow {
    // extract the header from the sample sheet
    def keys
    new File(params.sampleSheet).withReader {
        keys = it.readLine().split(',').drop(1)
    }

    // read the sample sheet
    sampleSheet = Channel
        .fromPath(params.sampleSheet)
        .splitCsv(header:true)

    // run the count process on a list of library IDs
    if (keys.contains("cell_count")) {
        CR_COUNT(sampleSheet.map { tuple(it.sample_id, (it.cell_count as Integer)) })
    } else {
        CR_COUNT(sampleSheet.map { tuple(it.sample_id, -1) })
    }

    if (params.cellbender) {
        // if cell count estimates were given to the pipeline, use those
        if (keys.contains("cell_count")) {
            CELLBENDER(
                CR_COUNT.out.allFiles.join(
                    sampleSheet.map { tuple(it.sample_id, it.cell_count) }
                )
            )
        }

        // if no cell count estimates were given to the pipeline, use
        // CellRanger's estimates
        else {
            GET_CR_CELLS_ESTIMATE(CR_COUNT.out.allFiles)
            CELLBENDER(
                CR_COUNT.out.allFiles.join(GET_CR_CELLS_ESTIMATE.out)
            )
        }

        MAKE_AGGREGATION_TABLE(
            file(params.sampleSheet),
            CR_COUNT.out.allFiles.collect { it[1] }
        )

    } else {
        // use the sample sheet and the output of the count process to make
        // a new sample sheet for the aggregate process
        CR_COUNT.out.moleculeInfo
            .join( sampleSheet.map { tuple(it.sample_id, it) })
            .map {
                it[2].remove('sample_id')
                values = it[2].values().join(',')
                return [it[0], it[1], values].join(',') }
            .collectFile(
                name: 'molecule_info.csv',
                newLine: true,
                seed: "sample_id,molecule_h5," + keys.join(','))
            .set { moleculeInfo }

        CR_AGGREGATE(moleculeInfo)
    }
}
