# cellranger-nf
nextflow pipeline for running cellranger

## Requirements
You must have [nextflow][nf] and [cellranger][cr] installed and in your path.
These are both very easy to install. Nextflow is a single command to download
and install, and cellranger is distributed as a tarball full of binaries, but
you have to agree to the license on their website and give them your information
to get a link.

This pipeline now supports using [CellBender][cb] to filter the CellRanger
output. If you would like to use this functionality, you will need to have
CellBender installed in a conda environment.

*N.B.* You do not need to clone this repository or otherwise download the code
in it to run the pipeline. Nextflow takes care of pulling the pipeline from git
when you run it.

## Configuration
There is a sample configuration file that works for running this pipeline on
Lewis included in this package (`nextflow.config`). If you're running this on
Lewis, you can try using the default configuration file by not doing anything.
Otherwise, copy it to the directory where you are going to run this pipeline,
and edit it to work on your cluster or other setup. See [nextflow][nf]
documentation for help with this.

CellBender is multiple orders of magnitude faster on a GPU than a CPU, so
running it on a machine with a GPU is highly recommended. The default
configuration file provides an example of how I have this configured on the
Lewis cluster, and should be reasonably simple to adapt to your cluster.

## Running
You'll need to make or download a cellranger reference first.
This pipeline does not do that for you. See cellranger documentation.

First, gather up your reference and your fastq files from the sequencer.

Next, make a sample sheet listing your samples. This will be in csv format with
a header. The only required column is `sample_id`, which gives the prefix for
that library in the fastq files. For example, if these are your files:
* `HCC1_S5_R1_001.fastq.gz`
* `HCC1_S5_R2_001.fastq.gz`
* `HCC2_S5_R1_001.fastq.gz`
* `HCC2_S5_R2_001.fastq.gz`
then you have two libraries, HCC1 and HCC2, and you should have two lines
(plus a header!) in your csv file, with `sample_id`s HCC1 and HCC2. You can also
add other columns to the csv file to use later, like sample treatment. Like so:
```
sample_id,treatment
HCC1,control
HCC2,treated
```

Then, it's a single command:
```bash
nextflow run WarrenLab/cellranger-nf -latest \
    --fastqs_dir /path/to/directory/containing/fastqs/ \
    --ref_dir /path/to/directory/containing/cellranger/reference/ \
    --sampleSheet samples.csv \
    --cellbender # only if you want to run CellBender filtering
```

Your output will appear in the current directory if everything works right.

## Output and next steps
If you did not specify the `--cellbender` option, this pipeline runs
`cellranger aggr` to aggregate the results from the different libraries. You
can take the aggregated output and load it in Seurat, scanpy, or the single-
cell processing platform of your choice.

If you did specify the `--cellbender` option, the cellbender filtered output is
unfortunately not compatible with `cellranger aggr`, so you will have to do the
aggregation yourself with the individual filtered library h5 files. The pipeline
adds some statistics to the final aggregation table that should help you do
this. My recommendation is to use these statistics to calculate the mean reads
per barcode for each library, and then regress this variable out. See
[this github issue][ghi] for more details.

[nf]: https://www.nextflow.io/
[cr]: https://support.10xgenomics.com/single-cell-gene-expression/software/downloads/latest
[cb]: https://cellbender.readthedocs.io/en/latest/
[ghi]: https://github.com/broadinstitute/CellBender/issues/46#issuecomment-563333306
