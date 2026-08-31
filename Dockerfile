# mtbc-speciation-nf runtime image
# All pipeline tools except:
#   - TB-Profiler (runs from its own Galaxy/BioContainers image)
#   - RD-Analyzer  (legacy Python-2 comparison tool, intentionally excluded)
FROM mambaorg/micromamba:1.5.8

LABEL org.opencontainers.image.source="https://github.com/hailsgav1/mtbc-speciation-nf"
LABEL org.opencontainers.image.description="MTBC speciation + surveillance pipeline runtime"
LABEL org.opencontainers.image.licenses="MIT"

USER root

# tini for clean process handling; procps for tools that probe /proc
RUN apt-get update && apt-get install -y --no-install-recommends \
        procps tini \
    && rm -rf /var/lib/apt/lists/*

# Install the pipeline environment into the base micromamba env
COPY environment.yml /tmp/environment.yml
RUN micromamba install -y -n base -f /tmp/environment.yml \
    && micromamba clean --all --yes

# Base env prefix in the micromamba image; put its bin on PATH for all shells
ENV MAMBA_ROOT_PREFIX=/opt/conda
ENV PATH=/opt/conda/bin:$PATH

# Sanity: fail the build if key tools aren't actually on PATH
RUN bwa 2>/dev/null; samtools --version | head -1 && bcftools --version | head -1 \
    && snp-sites -V && snp-dists -v && iqtree --version | head -1 \
    && fastqc --version && fastp --version 2>&1 | head -1 && multiqc --version

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/bin/bash"]
