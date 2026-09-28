#!/usr/bin/env python3
"""
Load and validate template manifests (<template>/template.yaml).

A top-level directory is a template when it contains template.yaml. Schema:

    description: str            required
    tags: [str]                 required, at least one
    entrypoint: path            required, relative to the template directory;
                                published as `config` in index.yaml
    type: str                   optional, default "script"; one of TYPES
    hidden: bool                optional; loaded and validated, left out of index.yaml
    env:                        optional; variables the entrypoint reads.
      - name: str               PUBLIC_IP is always set by onctl, don't list it.
        required: bool          optional, default false
        description: str        required
    files:                      optional; other files in the template worth listing
      - path: path              required, relative to the template directory
        type: str               optional, default "script"
        description: str        required
        env: [...]              optional, same shape as above

Every script-like file in a template directory (SCRIPT_EXTENSIONS) must be
either the entrypoint or listed under `files`, so nothing ships undocumented.

Run directly to validate all manifests: python3 .github/scripts/manifest.py
"""

import os
import sys

import yaml

MANIFEST = 'template.yaml'
TYPES = {
    'script': 'shell script run on the VM (onctl -a)',
    'cloud-init': 'cloud-init config (onctl -i)',
    'ansible': 'Ansible playbook',
    'manifest': 'Kubernetes manifest, applied with kubectl',
    'local': 'script run on your machine, not on the VM',
}
SCRIPT_EXTENSIONS = ('.sh', '.yaml', '.yml', '.config', '.toml', '.json')

TEMPLATE_KEYS = {'description', 'tags', 'entrypoint', 'type', 'hidden', 'env', 'files'}
FILE_KEYS = {'path', 'type', 'description', 'env'}
ENV_KEYS = {'name', 'required', 'description'}


class ManifestError(Exception):
    pass


def _check_keys(obj, allowed, required, where):
    if not isinstance(obj, dict):
        raise ManifestError(f"{where}: must be a mapping")
    unknown = set(obj) - allowed
    if unknown:
        raise ManifestError(f"{where}: unknown key(s) {sorted(unknown)}; allowed: {sorted(allowed)}")
    missing = [k for k in required if k not in obj]
    if missing:
        raise ManifestError(f"{where}: missing required key(s) {missing}")


def _check_str(value, where):
    if not isinstance(value, str) or not value.strip():
        raise ManifestError(f"{where}: must be a non-empty string")


def _check_type(value, where):
    if value not in TYPES:
        raise ManifestError(f"{where}: unknown type {value!r}; allowed: {sorted(TYPES)}")


def _check_path(template_dir, rel, where):
    _check_str(rel, where)
    full = os.path.normpath(os.path.join(template_dir, rel))
    if not full.startswith(template_dir + os.sep) or not os.path.isfile(full):
        raise ManifestError(f"{where}: file not found in {template_dir}/: {rel}")
    return os.path.relpath(full, template_dir)


def _check_env(env, where):
    if not isinstance(env, list):
        raise ManifestError(f"{where}: must be a list")
    names = set()
    for i, var in enumerate(env):
        w = f"{where}[{i}]"
        _check_keys(var, ENV_KEYS, ['name', 'description'], w)
        _check_str(var['name'], f"{w}.name")
        _check_str(var['description'], f"{w}.description")
        if var['name'] == 'PUBLIC_IP':
            raise ManifestError(f"{w}: PUBLIC_IP is always set by onctl, don't list it")
        if var['name'] in names:
            raise ManifestError(f"{w}: duplicate variable {var['name']}")
        names.add(var['name'])
        if not isinstance(var.get('required', False), bool):
            raise ManifestError(f"{w}.required: must be true or false")


def _script_files(template_dir):
    for root, dirs, files in os.walk(template_dir):
        dirs[:] = [d for d in dirs if not d.startswith('.')]
        for f in files:
            path = os.path.relpath(os.path.join(root, f), template_dir)
            if path != MANIFEST and f.endswith(SCRIPT_EXTENSIONS):
                yield path


def load_manifest(template_dir):
    """Return the validated manifest of one template directory."""
    where = f"{template_dir}/{MANIFEST}"
    try:
        with open(os.path.join(template_dir, MANIFEST), encoding='utf-8') as f:
            data = yaml.safe_load(f)
    except yaml.YAMLError as e:
        raise ManifestError(f"{where}: invalid YAML: {e}")

    _check_keys(data, TEMPLATE_KEYS, ['description', 'tags', 'entrypoint'], where)
    _check_str(data['description'], f"{where}: description")
    tags = data['tags']
    if not isinstance(tags, list) or not tags or not all(isinstance(t, str) and t for t in tags):
        raise ManifestError(f"{where}: tags must be a non-empty list of strings")
    data['entrypoint'] = _check_path(template_dir, data['entrypoint'], f"{where}: entrypoint")
    _check_type(data.setdefault('type', 'script'), f"{where}: type")
    if not isinstance(data.setdefault('hidden', False), bool):
        raise ManifestError(f"{where}: hidden must be true or false")
    if 'env' in data:
        _check_env(data['env'], f"{where}: env")

    listed = {data['entrypoint']}
    files = data.get('files', [])
    if not isinstance(files, list):
        raise ManifestError(f"{where}: files must be a list")
    for i, entry in enumerate(files):
        w = f"{where}: files[{i}]"
        _check_keys(entry, FILE_KEYS, ['path', 'description'], w)
        entry['path'] = _check_path(template_dir, entry['path'], f"{w}.path")
        _check_str(entry['description'], f"{w}.description")
        _check_type(entry.setdefault('type', 'script'), f"{w}.type")
        if 'env' in entry:
            _check_env(entry['env'], f"{w}.env")
        if entry['path'] in listed:
            raise ManifestError(f"{w}: {entry['path']} is listed twice")
        listed.add(entry['path'])

    unlisted = sorted(set(_script_files(template_dir)) - listed)
    if unlisted:
        raise ManifestError(f"{where}: not the entrypoint and not under `files`: {', '.join(unlisted)}")
    return data


def load_all(root='.'):
    """Return {template name: manifest} for every top-level directory.

    Every non-hidden top-level directory must be a template, so a new
    directory without a manifest fails loudly instead of being skipped.
    """
    manifests, errors = {}, []
    for name in sorted(os.listdir(root)):
        path = os.path.join(root, name)
        if not os.path.isdir(path) or name.startswith('.'):
            continue
        if not os.path.isfile(os.path.join(path, MANIFEST)):
            errors.append(f"{name}/: missing {MANIFEST} (see .github/scripts/manifest.py)")
            continue
        try:
            manifests[name] = load_manifest(os.path.relpath(path))
        except ManifestError as e:
            errors.append(str(e))
    if errors:
        raise ManifestError("\n".join(errors))
    return manifests


if __name__ == '__main__':
    try:
        found = load_all()
    except ManifestError as e:
        for line in str(e).splitlines():
            print(f"::error::{line}")
        sys.exit(1)
    print(f"{len(found)} template manifests are valid")
