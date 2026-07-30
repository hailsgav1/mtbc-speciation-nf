#!/usr/bin/env python3
"""
Classify an MTBC isolate from Region-of-Difference coverage breadth.

Reads a BAM, computes the fraction of each RD interval covered at >= a
per-sample relative depth cutoff (10% of median genome depth), then applies a
curated diagnostic panel to call the species.

Panel and reliability notes are from Bespiatykh et al. 2021 (mSphere,
doi:10.1128/mSphere.00535-21):
  * RD301 and RD315 are unique to M. orygis
  * RD305 is specific to M. caprae
  * RD7/RD8/RD9/RD10 mark the animal-adapted clade
  * RDoryx_1 is deliberately NOT used: deleted in only 25/32 orygis and prone
    to false coverage (part of the region relocates elsewhere in the genome)
  * Nested/overlapping and repeat/IS-associated RDs are not interpreted
"""
import argparse
import subprocess
import sys

# fraction-covered threshold below which a region is "deleted/absent"
ABSENT_MAX = 0.10   # <=10% of positions covered -> absent
PRESENT_MIN = 0.90  # >=90% -> present
# (values between are treated as ambiguous for that region)

DIAGNOSTIC = ["RD7", "RD8", "RD9", "RD10",   # animal-adapted gate
              "RD301", "RD315",              # orygis-specific
              "RD305",                       # caprae-specific
              "RD4", "RDbovis",              # bovis discriminators
              "N-RD25bov/cap",               # bovis/caprae branch
              "RD1mic", "RDpin", "RD2seal"]  # microti / pinnipedii exclusions


def region_breadth(bam, chrom, start, end, cutoff, samtools):
    """Fraction of positions in [start,end) with depth >= cutoff."""
    reg = f"{chrom}:{start+1}-{end}"
    p = subprocess.run([samtools, "depth", "-a", "-r", reg, bam],
                       capture_output=True, text=True)
    tot = passed = 0
    for line in p.stdout.splitlines():
        cols = line.split("\t")
        if len(cols) < 3:
            continue
        tot += 1
        if int(cols[2]) >= cutoff:
            passed += 1
    return (passed / tot) if tot else 0.0


def median_depth(bam, samtools):
    """Rough median genome depth from samtools depth (sampled)."""
    p = subprocess.run([samtools, "depth", "-a", bam],
                       capture_output=True, text=True)
    depths = [int(l.split("\t")[2]) for l in p.stdout.splitlines()
              if len(l.split("\t")) >= 3]
    if not depths:
        return 0
    depths.sort()
    return depths[len(depths) // 2]


def classify(frac):
    """Apply the diagnostic panel. `frac` maps region name -> fraction covered."""
    def absent(r):  return frac.get(r, 1.0) <= ABSENT_MAX
    def present(r): return frac.get(r, 0.0) >= PRESENT_MIN

    animal = absent("RD9") and absent("RD7") and absent("RD8") and absent("RD10")

    if not animal:
        return "Mycobacterium_tuberculosis", "not animal-adapted (RD7/9 present)"

    if absent("RD301") and absent("RD315"):
        if present("RD305") and present("RD4") and present("RDbovis"):
            return "Mycobacterium_orygis", "RD301+RD315 deleted; RD305/RD4/RDbovis intact"
        return "Mycobacterium_orygis", "RD301+RD315 deleted"

    if absent("RD305"):
        return "Mycobacterium_caprae", "RD305 deleted"

    if absent("RD4") or absent("RDbovis"):
        return "Mycobacterium_bovis", "RD4/RDbovis deleted"

    if absent("RD1mic"):
        return "Mycobacterium_microti", "RD1mic deleted"

    return "MTBC_animal_unresolved", "animal-adapted; no species marker matched"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--bam", required=True)
    ap.add_argument("--bed", required=True)
    ap.add_argument("--sample", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--samtools", default="samtools")
    args = ap.parse_args()

    med = median_depth(args.bam, args.samtools)
    cutoff = max(3, int(med * 0.10))   # floor of 3 so ultra-low sites still count

    frac = {}
    with open(args.bed) as fh:
        for line in fh:
            if line.startswith("#") or not line.strip():
                continue
            c = line.split("\t")
            if len(c) < 4:
                continue
            chrom, start, end, name = c[0], int(c[1]), int(c[2]), c[3].strip()
            if name in DIAGNOSTIC:
                frac[name] = region_breadth(args.bam, chrom, start, end,
                                            cutoff, args.samtools)

    call, reason = classify(frac)

    with open(args.out, "w") as out:
        out.write("sample\tspecies_call\tmedian_depth\tcutoff\treason\n")
        out.write(f"{args.sample}\t{call}\t{med}\t{cutoff}\t{reason}\n")
        out.write("# region\tfraction_covered\n")
        for r in DIAGNOSTIC:
            out.write(f"# {r}\t{frac.get(r, float('nan')):.3f}\n")

    print(f"{args.sample}: {call} ({reason}) [median depth {med}, cutoff {cutoff}]",
          file=sys.stderr)


if __name__ == "__main__":
    main()
