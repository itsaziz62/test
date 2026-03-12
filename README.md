# Installation Guide

Setup guide for the Seismic Data Processing Pipeline. Choose your platform:

| Platform | Method | Time |
|----------|--------|------|
| [**Ubuntu 20.04**](#option-a--ubuntu-2004) | Native Miniconda | ~20 min |
| [**Windows 10/11**](#option-b--windows-1011) | WSL 2 + Docker | ~30 min |

---

## Option A — Ubuntu 20.04

> One command installs everything: system deps, Miniconda, and all conda environments.

### Prerequisites

- Ubuntu 20.04 (fresh or existing)
- Internet connection
- (Optional) NVIDIA GPU with driver >= 535

### Step 1 — Clone the repositories

Open a terminal:

```bash
cd ~/Documents

# Clone the pipeline
git clone <repo-url> Automation

# Clone EQTransformer source (required for detection step)
git clone https://github.com/smousavi05/EQTransformer.git EQTransformer-master
```

### Step 2 — Run the setup script

```bash
cd ~/Documents/Automation
bash 0_Installation/setup.sh
```

This single command will:

1. Install system packages (`git`, `curl`, `wget`, `build-essential`)
2. Install Docker
3. Check for NVIDIA GPU
4. Download and install Miniconda
5. Create all five conda environments:

| # | Environment | Python | Purpose |
|---|-------------|--------|---------|
| 1 | `obspy` | 3.11 | Download, trim, resample, split |
| 2 | `eqt2` | 3.8.15 | EQTransformer (TF 2.5 + CUDA 11.2 + cuDNN 8.1) |
| 3 | `foconet` | 3.11 | FocoNet focal mechanism |
| 4 | `pyocto` | 3.11 | PyOcto associator |
| 5 | `eqcorrscan` | 3.11 | EQcorrscan template matching |

6. Verify all environments

> **Install a single env only:**
> ```bash
> bash 0_Installation/setup.sh --env obspy
> ```

### Step 3 — Verify

```bash
conda activate obspy
python pipeline.py --list
```

You should see all available pipeline steps. Setup is complete.

---

## Option B — Windows 10/11

> Uses WSL 2 + Docker Desktop. All environments run inside a container.

### Prerequisites

| Requirement | How to check |
|-------------|-------------|
| Windows 10 version 2004+ (Build 19041) or Windows 11 | `winver` in Run dialog |
| Virtualization enabled in BIOS (Intel VT-x / AMD-V) | Task Manager → Performance → CPU → "Virtualization: **Enabled**" |

> **If Virtualization is Disabled:** Restart PC → enter BIOS (usually `F2`, `F12`, or `Del` during boot) → find Intel VT-x or AMD-V under CPU/Advanced settings → Enable → Save & Exit.

### Step 1 — Enable WSL and Virtual Machine Platform

Open **PowerShell as Administrator** (right-click Start → "Windows Terminal (Admin)"):

```powershell
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
```

**Restart your PC.**

### Step 2 — Install Ubuntu on WSL

Open **PowerShell** again:

```powershell
wsl --set-default-version 2
wsl --install -d Ubuntu-20.04
```

Wait for download to complete. It will ask you to create a **username** and **password** — enter anything you like (this is your Linux user).

> **Verify it works:** Open Start Menu → search "Ubuntu-20.04" → open it. You should see a bash prompt.

### Step 3 — Install Docker Desktop

1. Download [Docker Desktop for Windows](https://www.docker.com/products/docker-desktop/)
2. Run the installer — check **"Use WSL 2 instead of Hyper-V"** when prompted
3. After install, open Docker Desktop
4. Go to **Settings → Resources → WSL Integration**
5. Toggle ON for **Ubuntu-20.04**
6. Click **Apply & Restart**

> **Verify it works:** Open Ubuntu terminal and run:
> ```bash
> docker --version
> ```

### Step 4 — Clone the repositories

Inside the **Ubuntu-20.04** terminal:

```bash
cd ~/Documents

# Clone the pipeline
git clone <repo-url> Automation

# Clone EQTransformer source
git clone https://github.com/smousavi05/EQTransformer.git EQTransformer-master

# Copy EQTransformer into the project (Docker needs it inside the build context)
cp -r EQTransformer-master Automation/EQTransformer-master
```

### Step 5 — Build and run

```bash
cd ~/Documents/Automation/0_Installation
docker compose up
```

This single command will:
1. Build a Docker image with Ubuntu 20.04 + CUDA 11.2 + Miniconda
2. Create all five conda environments inside the container
3. Mount your local `data/`, `Output/`, `config/`, `Model/` folders as volumes
4. Start the pipeline in interactive mode

> First build takes ~15-20 minutes (downloading packages). Subsequent runs are instant.

### Step 5b — With GPU (optional)

If you have an NVIDIA GPU:

1. Install the [latest NVIDIA driver for Windows](https://www.nvidia.com/Download/index.aspx) (the Windows driver is enough — **do NOT install CUDA inside WSL**)
2. Install the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)

Then run:

```bash
docker compose --profile gpu up
```

### Step 6 — Verify

The container starts the pipeline menu automatically. You should see:

```
======================================================================
PIPELINE
======================================================================

Menu:
  1. Download Waveforms
  2. Resample Waveform
  3. trim
  4. Split Channel
  5. EQTransformer
  0. Exit
======================================================================
```

Setup is complete.

---

## After Installation

### Running the pipeline

**Ubuntu (native):**
```bash
conda activate obspy
python pipeline.py              # interactive menu
python pipeline.py download     # run specific step
```

For the EQTransformer step:
```bash
conda activate eqt2
python pipeline.py eqt
```

**Windows (Docker):**
```bash
cd ~/Documents/Automation/0_Installation
docker compose up               # starts interactive menu
```

### Where are my files?

All input/output folders are shared between host and container:

| Folder | Contents |
|--------|----------|
| `data/raw/` | Downloaded waveforms |
| `data/stations.json` | Station metadata |
| `Output/Trim/` | Trimmed event windows |
| `Output/Resample/` | Resampled waveforms |
| `Output/EQT/detections/` | EQTransformer picks |
| `config/config.yaml` | All pipeline settings |

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `wsl --install` fails | Make sure Virtualization is enabled in BIOS |
| `docker: command not found` in WSL | Open Docker Desktop → Settings → WSL Integration → enable Ubuntu-20.04 |
| `docker compose up` permission denied | Run `sudo usermod -aG docker $USER` then restart terminal |
| GPU not detected in container | Install Windows NVIDIA driver (not Linux). Check with `nvidia-smi` in WSL |
| `setup.sh` fails on conda | Delete `~/miniconda3` and re-run `bash 0_Installation/setup.sh` |
| TensorFlow version mismatch in eqt2 | Run `bash 0_Installation/setup.sh --env eqt` to rebuild |
