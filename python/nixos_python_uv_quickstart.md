# Python Development on NixOS with `uv` & `direnv`

This guide summarizes how to initialize, activate, and maintain Python projects on NixOS using `uv` and `direnv`.

---

## 1. Project Directory Files

Every Python project requires two configuration files in its root directory:

### `shell.nix`
Provides Nix packages, dependencies, and dynamically exposes libraries needed by compiled C/C++ Python wheels.

```nix
{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  packages = with pkgs; [
    uv
    python3
    # Shared dynamic libraries for compiled wheels (numpy, pydantic-core, etc.)
    stdenv.cc.cc.lib
    zlib
  ];

  shellHook = ''
    export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath [
      pkgs.stdenv.cc.cc.lib
      pkgs.zlib
    ]}:$LD_LIBRARY_PATH"
  '';
}
```

### `.envrc`
Integrates with `direnv` to hook into Nix, create `.venv` if missing, and activate it.

```bash
use nix

# Auto-create venv if it does not exist
if [ ! -d ".venv" ]; then
  uv venv
fi

# Auto-activate venv
source .venv/bin/activate
```

---

## 2. Activation & Daily Workflow

### Initial Activation
Run this once inside the project root:

```bash
direnv allow
```

### Automatic Loading & Unloading
* **Entering the project:** `cd /path/to/project`  
  * `direnv` builds/loads the Nix shell cache and activates `.venv`.
* **Leaving the project:** `cd ..`  
  * All environment variables and the virtual environment automatically deactivate.

### Standard Commands (Run Inside Project)
```bash
# Add a dependency and install it
uv add requests numpy

# Or use standard pip syntax with uv speed
uv pip install -r requirements.txt

# Run Python scripts
python main.py
# or
uv run main.py
```

---

## 3. What to Remember & Troubleshooting

| Issue / Scenario | Cause | Solution |
| :--- | :--- | :--- |
| **`direnv: error .envrc is blocked`** | You modified `.envrc` or copied it from elsewhere. | Run `direnv allow`. |
| **`ImportError: lib*.so: cannot open shared object file`** | A package uses C bindings requiring a system library not in `LD_LIBRARY_PATH` (e.g., OpenCV, PostgreSQL). | Add the package (e.g., `pkgs.libGL`, `pkgs.postgresql`) to **both** `packages` and `pkgs.lib.makeLibraryPath` in `shell.nix`. |
| **Package fails to build from source (`sdist`)** | Pure C/C++ build tools are missing from the environment. | Add `pkgs.gcc`, `pkgs.gnumake`, and `pkgs.pkg-config` to `packages` in `shell.nix`. |
| **`.gitignore` best practices** | Avoid committing virtual environments and direnv build caches. | Add `.venv/` and `.direnv/` to your project's `.gitignore`. |