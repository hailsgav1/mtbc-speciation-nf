#!/usr/bin/env python3
"""
Reconcile independent MTBC species signals into one consensus call.

Inputs
------
--rd          RD-Analyzer output (legacy; shown for comparison, NOT voted)
--rd_regions  Curated RD-panel classifier (Bespiatykh 2021) — species_call line
--tbprofiler  TB-Profiler results.json (lineage / sub-lineage -> family)
--snpit       SNP-IT output (SNP-barcode species/lineage call)

The consensus vote uses RD_REGIONS + TB-Profiler + SNP-IT. Legacy RD-Analyzer
is reported in its own column for before/after comparison but does not vote,
since it lacks an M. orygis marker and systematically mis-calls it as M. caprae.
Where signals disagree, we surface the disagreement rather than silently
picking one.
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
    """Read ONLY the species_call line the RD-Analyzer module appends.
    RD-Analyzer abbreviates M. tuberculosis as 'Mtb:' (e.g. 'Mtb: East Asian -
    Lineage 2.2.1'), which carries no species substring, so map it explicitly."""
    try:
        with open(path) as fh:
            for line in fh:
                if line.lower().startswith("species_call"):
                    parts = line.rstrip("\n").split("\t")
                    if len(parts) < 2:
                        return "unknown"
                    raw = parts[1].strip()
                    if raw.lower().startswith("mtb"):
                        return "Mycobacterium_tuberculosis"
                    return normalise(raw)
    except OSError:
        pass
    return "unknown"


def parse_rd_regions(path):
    """Read the RD_REGIONS classifier output: line 2, column 2 is the call."""
    try:
        with open(path) as fh:
            lines = [l for l in fh if l.strip() and not l.startswith("#")]
        if len(lines) >= 2:
            cols = lines[1].rstrip("\n").split("\t")
            if len(cols) >= 2:
                return normalise(cols[1])
    except OSError:
        pass
    return "unknown"


def parse_tbprofiler(path):
    """Read TB-Profiler JSON.

    Animal-adapted members carry a species name in the 'family' field
    (e.g. 'M.orygis', 'M.bovis'). Human M. tuberculosis does NOT: it is
    reported as a numbered lineage (lineage1-9) with a geographic family
    ('East-Asian', 'Euro-American'). So a numbered lineage with no animal
    family means M. tuberculosis sensu stricto."""
    try:
        with open(path) as fh:
            data = json.load(fh)
    except (OSError, json.JSONDecodeError):
        return "unknown"

    numbered_lineage = False
    lineages = data.get("lineage") or data.get("sublin") or []

    if isinstance(lineages, list):
        for entry in lineages:
            if not isinstance(entry, dict):
                continue
            call = normalise(entry.get("family") or "")
            if call != "unknown":
                return call
            lin = str(entry.get("lineage") or entry.get("lin") or "")
            if re.match(r"^lineage\d", lin, re.I):
                numbered_lineage = True

    for field in ("sublin", "main_lineage", "lineage"):
        val = data.get(field)
        if not val:
            continue
        call = normalise(str(val))
        if call != "unknown":
            return call
        if re.match(r"^lineage\d", str(val), re.I):
            numbered_lineage = True

    if numbered_lineage:
        return "Mycobacterium_tuberculosis"
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
    ap.add_argument("--rd_regions", required=True)
    ap.add_argument("--tbprofiler", required=True)
    ap.add_argument("--snpit", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--host", default="NA")
    ap.add_argument("--date", default="NA")
    ap.add_argument("--country", default="NA")
    ap.add_argument("--location", default="NA")
    args = ap.parse_args()

    rd_call    = parse_rd(args.rd)
    rdreg_call = parse_rd_regions(args.rd_regions)
    tbp_call   = parse_tbprofiler(args.tbprofiler)
    snpit_call = parse_snpit(args.snpit)

    consensus, agreement = reconcile([rdreg_call, tbp_call, snpit_call])

    header = ["sample", "host", "collection_date", "country", "location",
              "rd_analyzer_call", "rd_regions_call", "tbprofiler_call",
              "snpit_call", "consensus", "agreement"]
    row = [args.sample, args.host, args.date, args.country, args.location,
           rd_call, rdreg_call, tbp_call, snpit_call, consensus, agreement]

    with open(args.out, "w") as fh:
        fh.write("\t".join(header) + "\n")
        fh.write("\t".join(row) + "\n")

    if agreement == "conflict":
        print(f"[WARN] {args.sample}: species calls disagree "
              f"(RD-regions={rdreg_call}, TB-Profiler={tbp_call}, SNP-IT={snpit_call}). "
              f"Manual review recommended.")


if __name__ == "__main__":
    main()
