# Python Environment Setup for JOAO_SETUP

## Problem
Modern Linux distributions (like Debian/Ubuntu) use "externally-managed" Python environments to prevent conflicts with system packages.

## Solution: Use a Virtual Environment

### Quick Setup (Recommended)

Run the automated setup script:

```bash
bash setup_environment.sh
```

This will:
1. Install `python3-venv` if needed
2. Create a virtual environment in `venv/`
3. Install all required packages from `requirements.txt`

### Manual Setup

If you prefer to set up manually:

1. **Install python3-venv** (if not already installed):
   ```bash
   sudo apt update
   sudo apt install python3-venv python3-full
   ```

2. **Create a virtual environment**:
   ```bash
   python3 -m venv venv
   ```

3. **Activate the virtual environment**:
   ```bash
   source venv/bin/activate
   ```

4. **Install required packages**:
   ```bash
   pip install -r requirements.txt
   ```

### Usage

**Every time you want to use the Python scripts**, activate the environment first:

```bash
source venv/bin/activate
```

Your prompt will change to show `(venv)` at the beginning.

Then run your Python scripts normally:
```bash
python3 script.py
```

**To deactivate** the environment when done:
```bash
deactivate
```

### Alternative: Run without activation

You can also run scripts directly without activating:
```bash
venv/bin/python script.py
```

## Installed Packages

The following packages will be installed:
- **numpy** - Numerical computing
- **pandas** - Data analysis and manipulation
- **matplotlib** - Plotting and visualization
- **scipy** - Scientific computing (MATLAB file I/O)
- **pyyaml** - YAML configuration file parsing

## System-Wide Installation (Not Recommended)

If you really want to install system-wide (may break system packages):
```bash
pip install -r requirements.txt --break-system-packages
```

⚠️ **Warning**: This is not recommended as it can conflict with system packages.

## Using pipx for individual tools

For standalone Python applications, you can use `pipx`:
```bash
sudo apt install pipx
pipx install <package-name>
```

This creates isolated environments for each application automatically.
