# cellranger-nf
nextflow pipeline for running cellranger

## Requirements
You must have [nextflow][nf] and [cellranger][cr] installed and in your path.
These are both very easy to install. Nextflow is a single command to download
and install, and cellranger is distributed as a tarball full of binaries, but
you have to agree to the license on their website and give them your information
to get a link.

## Configuration
There is a sample configuration file that works for running this pipeline on
Lewis included in this package (`nextflow.config`). If you're running this on
Lewis, you can try using the default configuration file by not doing anything.
Otherwise, copy it to the directory where you are going to run this pipeline,
and edit it to work on your cluster or other setup. See [nextflow][nf]
documentation for help with this.

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
    --nuclei # only if this is a single nucleus rather than single cell library
```

Your output will appear in the current directory if everything works right.

[nf]: https://www.nextflow.io/
[cr]: https://support.10xgenomics.com/single-cell-gene-expression/software/downloads/latest
