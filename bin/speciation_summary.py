#!/usr/bin/env python3
"""
Reconcile three independent MTBC species signals into one consensus call.

Inputs
------
--rd          RD-Analyzer output (Regions of Difference presence/absence)
--tbprofiler  TB-Profiler results.json (lineage / sub-lineage)
--snpit       SNP-IT output (SNP-barcode lineage/species call)

The point of this step is to catch the well-documented failure mode where a
single tool misidentifies an animal-adapted MTBC member -- most notably
M. orygis being reported as M. bovis or M. tuberculosis. Where the three
signals disagree, we surface the disagreement rather than silently picking one.
"""
import argparse
import json
import os
import re
from collections import Counter

# Canonical MTBC member names we normalise everything to.
MTBC = {
    "tuberculosis": "Mycobacterium_tuberculosis",
    "bovis": "Mycobacterium_bovis",
    "orygis": "Mycobacterium_orygis",
    "caprae": "Mycobacterium_caprae",
    "africanum": "Mycobacterium_africanum",
    "microti": "Mycobacterium_microti",
    "pinnipedii": "Mycobacterium_pinnipedii",
    "canettii": "Mycobacterium_canettii",
}


def normalise(text):
    """Map a free-text call onto a canonical MTBC member (or 'unknown')."""
    if not text:
        return "unknown"
    t = text.lower()
    for key, canonical in MTBC.items():
        if key in t:
            return canonical
    return "unknown"


def parse_rd(path):
    try:
        with open(path) as fh:
            for line in fh:
                if line.lower().startswith("species_call"):
                    return normalise(line.split("\t", 1)[1])
            fh.seek(0)
            return normalise(fh.read())
    except (OSError, IndexError):
        return "unknown"


def parse_tbprofiler(path):
    try:
        with open(path) as fh:
            data = json.load(fh)
        # TB-Profiler reports sub-lineage; animal lineages carry species hints.
        for field in ("sublin", "sub_lineage", "main_lin", "lineage"):
            if field in data and data[field]:
                call = normalise(str(data[field]))
                if call != "unknown":
                    return call
        return normalise(json.dumps(data))
    except (OSError, json.JSONDecodeError):
        return "unknown"


def parse_snpit(path):
    try:
        with open(path) as fh:
            return normalise(fh.read())
    except OSError:
        return "unknown"


def reconcile(calls):
    """Majority vote across non-unknown calls; report agreement level."""
    known = [c for c in calls if c != "unknown"]
    if not known:
        return "unknown", "none"
    counts = Counter(known)
    top, n = counts.most_common(1)[0]
    if len(set(known)) == 1 and len(known) == len(calls):
        agreement = "full"
    elif n > len(known) / 2:
        agreement = "majority"
    else:
        agreement = "conflict"
    return top, agreement


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--sample", required=True)
    ap.add_argument("--rd", required=True)
    ap.add_argument("--tbprofiler", required=True)
    ap.add_argument("--snpit", required=True)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    rd_call = parse_rd(args.rd)
    tbp_call = parse_tbprofiler(args.tbprofiler)
    snpit_call = parse_snpit(args.snpit)

    consensus, agreement = reconcile([rd_call, tbp_call, snpit_call])

    header = ["sample", "rd_call", "tbprofiler_call", "snpit_call",
              "consensus", "agreement"]
    row = [args.sample, rd_call, tbp_call, snpit_call, consensus, agreement]

    with open(args.out, "w") as fh:
        fh.write("\t".join(header) + "\n")
        fh.write("\t".join(row) + "\n")

    if agreement == "conflict":
        print(f"[WARN] {args.sample}: species calls disagree "
              f"(RD={rd_call}, TB-Profiler={tbp_call}, SNP-IT={snpit_call}). "
              f"Manual review recommended.")


if __name__ == "__main__":
    main()
