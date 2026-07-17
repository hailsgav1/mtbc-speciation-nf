# RD coverage-breadth proof-of-method

Prototype for the RD-Analyzer replacement (roadmap step 4).

`RD.bed` is the curated MTBC Regions of Difference panel from RDscan
(Bespiatykh et al. 2021, mSphere, doi:10.1128/mSphere.00535-21),
https://github.com/dbespiatykh/RDscan — used under CC BY 4.0.
`RD_regions.bed` is the same, filtered to NC_000962.3 (H37Rv) intervals.

`rd_breadth.sh` reports, per RD, the fraction of positions at or above a
depth cutoff. Breadth is used rather than mean depth because nested/overlapping
annotations make means misleading.

## Result: SRR9157804 (M. orygis, dairy cattle, Chennai)
- RDoryx_1 absent (1/9562 positions covered) -> M. orygis
- RD7/RD9/RD10/RD8 absent -> animal-adapted
- RD4, RDbovis, N-RD25bov/cap, RDcap_Spain1/3 present -> NOT bovis/caprae
- RD1mic, RDpin, RD2seal present -> NOT microti/pinnipedii

RD-Analyzer called this isolate M. caprae; its 30-RD panel contains no
orygis marker. This panel does.

## Known issue
Overlapping annotations produce phantom partial signals (e.g. RD-sur1 = 0.444
is exactly RDoryx_1's deletion bleeding through a containing interval).
The module must interpret a validated non-overlapping diagnostic subset.
