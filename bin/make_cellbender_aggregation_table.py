#!/usr/bin/env python3
"""
Given a sample sheet as input to the pipeline, and a list of all
metrics summary outputs from cellranger, output a new sample sheet
with some added columns from the metrics summary to help with
the aggregation step later.
"""
import argparse
import csv
import re
import sys
from typing import Tuple

metrics_summary_filename_re = re.compile(r"metrics_summary.(\S*).csv")


def dict_csv_reader_type(filename: str) -> csv.DictReader:
    """Opens a csv.DictReader given a filename."""
    return csv.DictReader(open(filename, "r"))


def metrics_summary_type(filename: str) -> Tuple[str, csv.DictReader]:
    """
    Given the filename of a metrics_summary.{id}.csv output from
    CellRanger, output the tuple
        (id, csv.DictReader(open(metrics_summary.{id}.csv)))
    to help find the right file later.
    """
    filename_match = metrics_summary_filename_re.match(filename)
    if not filename_match:
        raise Exception(
            f"filename {filename} does not match format 'metrics_summary.*.csv'"
        )

    return (filename_match.group(1), dict_csv_reader_type(filename))


def parse_args():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "sample_sheet",
        type=dict_csv_reader_type,
        help="sample sheet csv, same format as pipeline input",
    )
    parser.add_argument(
        "metrics_summaries",
        type=metrics_summary_type,
        nargs="+",
        help="all metrics summaries outputs from cellranger",
    )
    return parser.parse_args()


def main():
    args = parse_args()

    metrics_summaries_dict = dict(args.metrics_summaries)

    output_keys = list(args.sample_sheet.fieldnames) + ["num_cells", "confident_pct"]
    dict_writer = csv.DictWriter(sys.stdout, output_keys)
    dict_writer.writeheader()

    for sample_entry in args.sample_sheet:
        sample_metrics = next(metrics_summaries_dict[sample_entry["sample_id"]])
        sample_entry["num_cells"] = int(
            sample_metrics["Estimated Number of Cells"].replace(",", "")
        )
        sample_entry["confident_pct"] = float(
            sample_metrics["Reads Mapped Confidently to Transcriptome"][:-1]
        )
        dict_writer.writerow(sample_entry)


if __name__ == "__main__":
    main()
