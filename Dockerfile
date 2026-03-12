# ==========================================================================
# Seismic Pipeline — Docker image (all conda envs pre-built)
# For Windows users via WSL + Docker Desktop
#
# Build:  docker compose build
# Run:    docker compose up
# ==========================================================================

FROM nvidia/cuda:11.2.2-cudnn8-runtime-ubuntu20.04

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# ── System deps ───────────────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
        git curl wget build-essential ca-certificates \
        libgl1-mesa-glx libglib2.0-0 libsm6 libxext6 libxrender1 \
    && rm -rf /var/lib/apt/lists/*

# ── Miniconda ─────────────────────────────────────────────────────────────────
ENV CONDA_DIR=/opt/miniconda3
RUN wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh \
    && bash /tmp/miniconda.sh -b -p $CONDA_DIR \
    && rm /tmp/miniconda.sh
ENV PATH="$CONDA_DIR/bin:$PATH"
RUN conda init bash && conda config --set auto_activate_base false

# ── Accept Conda Terms of Service ─────────────────────────────────────────────
RUN conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main \
    && conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r

# ── Env: obspy (Python 3.11) ─────────────────────────────────────────────────
RUN conda create -n obspy python=3.11 -y \
    && conda run -n obspy pip install --no-cache-dir -q \
        obspy==1.4.2 pandas geopandas folium cartopy seaborn \
        shapely openpyxl pyyaml lxml numexpr h5py

# ── Env: EQT (Python 3.8 + TF 2.5 + CUDA 11.2) ────────────────────────────
# Split into steps to avoid dependency conflicts

# Step 1: create env
RUN conda create -n EQT python=3.8.15 -y

# Step 2: CUDA via conda-forge
RUN conda install -n EQT -c conda-forge cudatoolkit=11.2 cudnn=8.1 -y

# Step 3: tensorflow + strictly pinned core deps
RUN conda run -n EQT pip install --no-cache-dir \
        tensorflow==2.5.0 \
        numpy==1.19.5 \
        scipy==1.6.2 \
        h5py==3.1.0 \
        typing-extensions==3.7.4 \
        six==1.15.0

# Step 4: remaining packages
RUN conda run -n EQT pip install --no-cache-dir \
        pillow==8.4.0 \
        matplotlib==3.5.2 \
        pandas==1.4.3 \
        tqdm==4.64.0 \
        ipython==7.34.0 \
        ipykernel==5.5.6 \
        sqlalchemy==1.4.52

# Step 5: obspy (separate — has heavy deps)
RUN conda run -n EQT pip install --no-cache-dir obspy==1.3.0

# Step 6: eqtransformer without deps to avoid conflicts
RUN conda run -n EQT pip install --no-cache-dir eqtransformer --no-deps

# ── Env: foconet (Python 3.11) ───────────────────────────────────────────────
RUN conda create -n foconet python=3.11 -y \
    && conda run -n foconet pip install --no-cache-dir -q \
        torch obspy pyrocko scikit-learn pyyaml lxml

# ── Env: pyocto (Python 3.11) ────────────────────────────────────────────────
RUN conda create -n pyocto python=3.11 -y \
    && conda run -n pyocto pip install --no-cache-dir -q \
        pyocto pandas pyproj matplotlib

# ── Env: eqcorrscan (Python 3.10 — 3.11 has pkg-resources issue) ─────────────
RUN conda create -n eqcorrscan python=3.10 -y
RUN conda run -n eqcorrscan pip install --no-cache-dir "setuptools<65" "pip<23"
RUN conda run -n eqcorrscan pip install --no-cache-dir \
        eqcorrscan obspy pandas matplotlib

# ── Project files ─────────────────────────────────────────────────────────────
WORKDIR /app
COPY . /app

# Install EQTransformer from source if present
RUN if [ -d /app/EQTransformer-master ]; then \
        conda run -n EQT pip install -e /app/EQTransformer-master --no-deps \
        && echo "[OK] EQTransformer installed from source"; \
    else \
        echo "[!!] EQTransformer-master not found — skipping local install"; \
    fi

# ── Verify TF ────────────────────────────────────────────────────────────────
RUN conda run -n EQT python -c \
    "import tensorflow as tf; print(f'[OK] TensorFlow {tf.__version__}')" \
    2>/dev/null || echo "[!!] TensorFlow import failed"

# ── Default: start pipeline in interactive mode ──────────────────────────────
SHELL ["/bin/bash", "-c"]
CMD ["conda", "run", "--no-capture-output", "-n", "obspy", "python", "pipeline.py"]
