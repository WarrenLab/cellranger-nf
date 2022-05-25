#!/usr/bin/env python3
"""
Get the expected number of cells from a metrics_summary.csv output
file from CellRanger. This should be doable with a simple cut command,
but unfortunately, CellRanger puts unnecessary commas and quotation
marks in its output csvs.
"""

import argparse
import csv


def dict_csv_reader_type(filename: str) -> dict[str, str]:
    """Opens a csv.DictReader given a filename."""
    with open(filename, "r") as csv_file:
        return next(csv.DictReader(csv_file))


def parse_args():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "metrics_summary",
        type=dict_csv_reader_type,
        help="metrics_summary.csv file from cellranger output",
    )
    return parser.parse_args()


def main():
    args = parse_args() 
    print(args.metrics_summary["Estimated Number of Cells"].replace(",", ""))


if __name__ == "__main__":
    main()
