# Automated Index Generation

This repository uses GitHub Actions to automatically generate the `index.yaml` file based on the directory structure and available script files.

## How it works

The automation consists of two main components:

### 1. GitHub Workflow (`.github/workflows/generate-index.yml`)

The workflow automatically runs when:
- Scripts or configuration files are added/modified (`*.sh`, `*.yaml`, `*.yml`, `*.config`, `*.toml`)
- README.md files are updated
- The workflow or generation scripts are modified
- Manually triggered via `workflow_dispatch`

**Branch Protection Handling:**
- If branch protection is enabled, the workflow creates a pull request with the updated `index.yaml`
- If no branch protection, it commits directly to the target branch
- This ensures compatibility with different repository protection levels

### 2. Python Scripts

#### `generate_index.py`
- Scans all directories in the repository root
- Identifies configuration scripts and files
- Extracts descriptions from README.md files when available
- Generates tags based on directory names and technology patterns
- Creates the `index.yaml` file with proper structure

#### `validate_index.py`
- Validates the generated `index.yaml` file for proper YAML syntax
- Checks required fields are present
- Verifies referenced config files exist
- Ensures no duplicate template names

## Template Configuration

The generator includes predefined configurations for known templates:

```python
TEMPLATE_CONFIGS = {
    'k3s': {
        'preferred_script': 'k3s-server.sh',
        'description': 'Deploys a K3s server instance.',
        'tags': ['k3s', 'kubernetes', 'server']
    },
    # ... more configurations
}
```

## Adding New Templates

To add a new template directory:

1. Create a directory with your template name
2. Add at least one script file (`.sh`, `.yaml`, `.yml`, `.config`, `.toml`)
3. Optionally add a `README.md` with description
4. The automation will automatically detect and add it to `index.yaml`

## Supported File Types

The generator looks for these configuration file types:
- Shell scripts (`.sh`)
- YAML files (`.yaml`, `.yml`)
- Configuration files (`.config`)
- TOML files (`.toml`)
- JSON files (`.json`)

## Preferred Script Selection

The generator selects configuration files in this order:
1. Predefined preferred script (if configured)
2. Common names: `install.sh`, `setup.sh`, `deploy.sh`, `main.sh`
3. Directory-named script: `{directory_name}.sh`
4. First `.sh` file found
5. First file of other supported types

## Excluded Directories

These directories are automatically excluded:
- `.git`, `.github`, `.trunk`
- `environments`, `helm-harbor`, `ngrok-operator`
- `test`, `__pycache__`

## Manual Generation

To manually generate the index.yaml locally:

```bash
python .github/scripts/generate_index.py
python .github/scripts/validate_index.py
```

## Customization

To customize the generation for your templates:

1. Add your template configuration to `TEMPLATE_CONFIGS` in `generate_index.py`
2. Specify preferred script file, description, and tags
3. The automation will use your custom configuration

Example:
```python
'my-template': {
    'preferred_script': 'custom-setup.sh',
    'description': 'My custom template description.',
    'tags': ['custom', 'template', 'automation']
}
```
