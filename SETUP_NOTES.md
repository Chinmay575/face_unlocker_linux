# Setup Notes

## Files Not Included in Repository

The following files are not tracked in git and need to be obtained separately:

### 1. AI Model (Required)
- **File**: `models/arcfaceresnet100-8.onnx`
- **Purpose**: Face recognition model for generating embeddings
- **Download from**: [ONNX Model Zoo](https://github.com/onnx/models/tree/main/validated/vision/body_analysis/arcface)
- **Action**: Create `models/` directory and place the model file there

### 2. User Enrollment Data (Generated)
- **Directory**: `faceunlock/`
- **Files**: `*.npy` (e.g., `chinmay.npy`)
- **Purpose**: Stores enrolled users' face embeddings
- **Action**: These are automatically generated when you run `sudo faceunlock-enroll <username>`

### 3. Compiled PAM Module (Built)
- **File**: `pam_faceunlock.so`
- **Purpose**: PAM authentication module
- **Action**: Automatically compiled during installation (`./install.sh`) or manually with `make`

### 4. Python Cache (Auto-generated)
- **Directory**: `__pycache__/`
- **Purpose**: Python bytecode cache
- **Action**: Automatically created by Python, no action needed

## Before Installation

1. **Download the AI model**:
   ```bash
   mkdir -p models/
   # Download arcfaceresnet100-8.onnx to models/ directory
   ```

2. **Run the installer**:
   ```bash
   sudo ./install.sh
   ```

3. **Enroll users**:
   ```bash
   sudo faceunlock-enroll <username>
   ```

## .gitignore Strategy

The `.gitignore` file excludes:
- ✅ Build artifacts (`*.so`, `*.o`, `__pycache__/`)
- ✅ AI models (`models/` - too large for git)
- ✅ User data (`faceunlock/*.npy` - contains biometric data)
- ✅ Virtual environments (`venv/`, `env/`)
- ✅ IDE/editor files (`.vscode/`, `.idea/`, `*.swp`)
- ✅ Log files (`*.log`)

This keeps the repository clean and focused on source code only.
