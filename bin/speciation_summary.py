#!/usr/bin/env python3
"""
Reconcile three independent MTBC species signals into one consensus call.

Inputs
------
--rd          RD-Analyzer output (has a `species_call` line we write in the module)
--tbprofiler  TB-Profiler results.json (lineage / sub-lineage -> family)
--snpit       SNP-IT output (SNP-barcode species/lineage call)

Catches the well-documented failure mode where a single tool misidentifies an
animal-adapted MTBC member (e.g. M. orygis vs M. caprae vs M. bovis). Where the
signals disagree, we surface the disagreement rather than silently picking one.
"""
import argparse
import json
import re
from collections import Counter

MTBC = {
    "orygis": "Mycobacterium_orygis",
    "caprae": "Mycobacterium_caprae",
    "bovis": "Mycobacterium_bovis",
    "africanum": "Mycobacterium_africanum",
    "microti": "Mycobacterium_microti",
    "pinnipedii": "Mycobacterium_pinnipedii",
    "canettii": "Mycobacterium_canettii",
    "tuberculosis": "Mycobacterium_tuberculosis",
}


def normalise(text):
    """Map a single call string onto a canonical MTBC member (or 'unknown').
    Order matters: check the specific animal clades before 'tuberculosis'."""
    if not text:
        return "unknown"
    t = text.lower()
    for key, canonical in MTBC.items():
        if key in t:
            return canonical
    return "unknown"


def parse_rd(path):
    """Read ONLY the species_call line the RD module appends."""
    try:
        with open(path) as fh:
            for line in fh:
                if line.lower().startswith("species_call"):
                    parts = line.rstrip("\n").split("\t")
                    return normalise(parts[1]) if len(parts) > 1 else "unknown"
    except OSError:
        pass
    return "unknown"


def parse_tbprofiler(path):
    """Read TB-Profiler JSON; prefer the explicit sub-lineage 'family' field."""
    try:
        with open(path) as fh:
            data = json.load(fh)
    except (OSError, json.JSONDecodeError):
        return "unknown"
    # TB-Profiler lineage entries carry a 'family' like 'M.orygis'
    lineages = data.get("lineage") or data.get("sublin") or []
    if isinstance(lineages, list):
        for entry in lineages:
            fam = entry.get("family") if isinstance(entry, dict) else None
            if fam:
                call = normalise(fam)
                if call != "unknown":
                    return call
    for field in ("sublin", "main_lineage", "lineage"):
        val = data.get(field)
        if val:
            call = normalise(str(val))
            if call != "unknown":
                return call
    return "unknown"


def parse_snpit(path):
    """Read SNP-IT stdout. Format is a header line + a result line whose
    'Species'/'Name' column holds the call. Parse only the data line, never
    the whole file (so a sample name can't leak a false match)."""
    try:
        with open(path) as fh:
            lines = [l.rstrip("\n") for l in fh if l.strip()]
    except OSError:
        return "unknown"
    if not lines:
        return "unknown"
    # SNP-IT prints a tab/space separated result; the species token is what we want.
    # Skip an obvious header line if present.
    data_lines = [l for l in lines if not l.lower().startswith(("sample", "#"))]
    for l in data_lines:
        call = normalise(l)
        if call != "unknown":
            return call
    return "unknown"


def reconcile(calls):
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
