#!/usr/bin/env bash
# ==========================================================================
# Seismic Pipeline - Environment Setup
# Works on: Ubuntu (native or WSL), tested on Ubuntu 20.04
#
# Usage:
#   bash setup.sh           # install everything
#   bash setup.sh --env eqt # install only one env
# ==========================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MINICONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh"
MINICONDA_DIR="$HOME/miniconda3"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[!!]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; exit 1; }
step() { echo -e "\n${GREEN}=== $1 ===${NC}\n"; }

# ==========================================================================
# Parse args
# ==========================================================================
ONLY_ENV=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --env) ONLY_ENV="$2"; shift 2 ;;
        *) echo "Unknown arg: $1"; exit 1 ;;
    esac
done

# ==========================================================================
# 1. System packages
# ==========================================================================
install_system_deps() {
    step "System Dependencies"
    sudo apt update -y
    sudo apt install -y git curl wget build-essential
    ok "System packages installed"
}

# ==========================================================================
# 2. Docker (for GPU support in WSL)
# ==========================================================================
install_docker() {
    step "Docker"
    if command -v docker &>/dev/null; then
        ok "Docker already installed: $(docker --version)"
        return
    fi
    sudo apt install -y docker.io
    sudo usermod -aG docker "$USER"
    ok "Docker installed (re-login or run 'newgrp docker' to use without sudo)"
}

# ==========================================================================
# 3. NVIDIA check
# ==========================================================================
check_gpu() {
    step "GPU Check"
    if command -v nvidia-smi &>/dev/null; then
        nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader 2>/dev/null || true
        ok "GPU detected"
    else
        warn "No GPU / nvidia-smi not found (CPU-only mode will be used) or install the nvidia drivers and CUDA toolkit for GPU support"
    fi
}

# ==========================================================================
# 4. Miniconda
# ==========================================================================
install_miniconda() {
    step "Miniconda"
    if [ -f "$MINICONDA_DIR/bin/conda" ]; then
        ok "Miniconda already installed at $MINICONDA_DIR"
        return
    fi
    echo "Downloading Miniconda..."
    wget -q "$MINICONDA_URL" -O /tmp/miniconda.sh
    bash /tmp/miniconda.sh -b -p "$MINICONDA_DIR"
    rm /tmp/miniconda.sh
    ok "Miniconda installed at $MINICONDA_DIR"
}

init_conda() {
    export PATH="$MINICONDA_DIR/bin:$PATH"
    eval "$("$MINICONDA_DIR/bin/conda" shell.bash hook)"
    conda init bash 2>/dev/null || true
}

# ==========================================================================
# 5. Conda environments
# ==========================================================================

create_env_obspy() {
    step "Environment: obspy"
    if conda env list | grep -q "^obspy "; then
        ok "obspy env already exists"
    else
        conda create -n obspy python=3.11 -y
    fi
    conda run -n obspy pip install -q \
        obspy==1.4.2 \
        pandas \
        geopandas \
        folium \
        cartopy \
        seaborn \
        shapely \
        openpyxl \
        pyyaml \
        lxml \
        numexpr \
        h5py
    ok "obspy env ready"
}

create_env_eqt() {
    step "Environment: eqt (Python 3.8 + TF 2.5 + CUDA 11.2)"
    if conda env list | grep -q "^eqt2 "; then
        ok "eqt2 env already exists"
    else
        conda create -n eqt2 python=3.8.15 -y
    fi

    # CUDA toolkit + cuDNN via conda
    conda install -n eqt2 -c conda-forge cudatoolkit=11.2 cudnn=8.1 -y

    # Pinned versions (tested on Ubuntu 20.04 + CUDA 11.2 + nvidia-driver 535)
    conda run -n eqt2 pip install -q \
        tensorflow==2.5.0 \
        numpy==1.19.5 \
        scipy==1.6.2 \
        h5py==3.1.0 \
        pillow==8.4.0 \
        matplotlib==3.5.2 \
        pandas==1.4.3 \
        tqdm==4.64.0 \
        obspy==1.3.0 \
        eqtransformer \
        typing-extensions==3.7.4 \
        six==1.15.0 \
        ipython==7.34.0 \
        ipykernel==5.5.6 \
        sqlalchemy==1.4.52

    # Register Jupyter kernel
    conda run -n eqt2 python -m ipykernel install --user --name eqt2 --display-name "EQT2" 2>/dev/null || true

    # Install EQTransformer from local source (no-deps to keep pinned versions)
    if [ -d "$HOME/Documents/EQTransformer-master" ]; then
        conda run -n eqt2 pip install -e "$HOME/Documents/EQTransformer-master" --no-deps
        ok "EQTransformer installed from local source"
    else
        warn "EQTransformer source not found at ~/Documents/EQTransformer-master"
        warn "Clone it manually: git clone https://github.com/smousavi05/EQTransformer.git"
    fi

    # Verify TensorFlow installation
    if conda run -n eqt2 python -c "import tensorflow as tf; assert tf.__version__=='2.5.0'" 2>/dev/null; then
        ok "TensorFlow 2.5.0 verified"
    else
        warn "TensorFlow version mismatch or import failed — eqt2 env may need rebuild"
    fi

    ok "eqt2 env ready"
}

create_env_foconet() {
    step "Environment: foconet"
    if conda env list | grep -q "^foconet "; then
        ok "foconet env already exists"
    else
        conda create -n foconet python=3.11 -y
    fi
    conda run -n foconet pip install -q \
        torch \
        obspy \
        pyrocko \
        scikit-learn \
        pyyaml \
        lxml
    ok "foconet env ready"
}

create_env_pyocto() {
    step "Environment: pyocto"
    if conda env list | grep -q "^pyocto "; then
        ok "pyocto env already exists"
    else
        conda create -n pyocto python=3.11 -y
    fi
    conda run -n pyocto pip install -q \
        pyocto \
        pandas \
        pyproj \
        matplotlib
    ok "pyocto env ready"
}

create_env_eqcorrscan() {
    step "Environment: eqcorrscan"
    if conda env list | grep -q "^eqcorrscan "; then
        ok "eqcorrscan env already exists"
    else
        conda create -n eqcorrscan python=3.11 -y
    fi
    conda run -n eqcorrscan pip install -q \
        eqcorrscan \
        obspy \
        pandas \
        matplotlib
    ok "eqcorrscan env ready"
}

# ==========================================================================
# 6. Verify
# ==========================================================================
verify_envs() {
    step "Verification"
    local envs=("obspy" "eqt2" "foconet" "pyocto" "eqcorrscan")
    for env in "${envs[@]}"; do
        if conda env list | grep -q "^${env} "; then
            echo -n "  $env: "
            conda run -n "$env" python --version 2>/dev/null && ok "$env" || warn "$env (python not found)"
        fi
    done
}

# ==========================================================================
# Main
# ==========================================================================
main() {
    echo ""
    echo "============================================================"
    echo " Seismic Pipeline - Environment Setup"
    echo "============================================================"
    echo ""

    install_system_deps
    install_docker
    check_gpu
    install_miniconda
    init_conda

    if [ -n "$ONLY_ENV" ]; then
        # Install only one env
        case "$ONLY_ENV" in
            obspy)      create_env_obspy ;;
            eqt)        create_env_eqt ;;
            foconet)    create_env_foconet ;;
            pyocto)     create_env_pyocto ;;
            eqcorrscan) create_env_eqcorrscan ;;
            *) fail "Unknown env: $ONLY_ENV" ;;
        esac
    else
        # Install all
        create_env_obspy
        create_env_eqt
        create_env_foconet
        create_env_pyocto
        create_env_eqcorrscan
    fi

    verify_envs

    echo ""
    echo "============================================================"
    echo " Setup Complete!"
    echo "============================================================"
    echo ""
    echo " To activate an env:  conda activate obspy"
    echo " To run pipeline:     conda activate obspy && python pipeline.py"
    echo ""
}

main
