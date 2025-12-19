#!/usr/bin/env python3
"""
Generate index.yaml file based on directory structure and script files.
"""

import os
import yaml
import glob
import re
from pathlib import Path

# Define template configurations with preferred scripts and descriptions
TEMPLATE_CONFIGS = {
    'k3s': {
        'preferred_script': 'k3s-server.sh',
        'description': 'Deploys a K3s server instance.',
        'tags': ['k3s', 'kubernetes', 'server']
    },
    'docker': {
        'preferred_script': 'docker.sh',
        'description': 'Installs Docker on the VM.',
        'tags': ['docker', 'container']
    },
    'minio': {
        'preferred_script': 'docker.sh',
        'description': 'Sets up a MinIO storage server.',
        'tags': ['minio', 'storage', 's3']
    },
    'ollama': {
        'preferred_script': 'open-webui-ollama.sh',
        'description': 'Sets up Ollama with Open WebUI for AI model management.',
        'tags': ['ollama', 'ai', 'llm', 'webui']
    },
    'rke2': {
        'preferred_script': 'rke2.sh',
        'description': 'Installs and configures RKE2 Kubernetes distribution.',
        'tags': ['rke2', 'kubernetes', 'rancher']
    },
    'node': {
        'preferred_script': 'node.sh',
        'description': 'Installs Node.js using NVM (Node Version Manager).',
        'tags': ['nodejs', 'javascript', 'nvm']
    },
    'nginx': {
        'preferred_script': 'install.sh',
        'description': 'Sets up Nginx web server.',
        'tags': ['nginx', 'webserver', 'proxy']
    },
    'wireguard': {
        'preferred_script': 'vpn.sh',
        'description': 'Configures WireGuard VPN server.',
        'tags': ['wireguard', 'vpn', 'networking']
    },
    'cloud-init': {
        'preferred_script': 'ssh-443.config',
        'description': 'Provides cloud-init configuration templates.',
        'tags': ['cloud-init', 'cloud', 'initialization']
    },
    'ansible': {
        'preferred_script': 'playbooks/docker.yaml',
        'description': 'Ansible playbooks for automated configuration management.',
        'tags': ['ansible', 'automation', 'configuration']
    },
    'azure': {
        'preferred_script': 'agent-pool.sh',
        'description': 'Azure cloud deployment and configuration scripts.',
        'tags': ['azure', 'cloud', 'deployment']
    },
    'cloudflare': {
        'preferred_script': 'tunnel.sh',
        'description': 'Cloudflare tunnel and DNS configuration.',
        'tags': ['cloudflare', 'tunnel', 'dns']
    },
    'coder': {
        'preferred_script': 'init.sh',
        'description': 'Coder development environment setup.',
        'tags': ['coder', 'development', 'environment']
    },
    'frp': {
        'preferred_script': 'frpc.sh',
        'description': 'Fast Reverse Proxy (FRP) client and server setup.',
        'tags': ['frp', 'proxy', 'networking']
    },
    'harbor': {
        'preferred_script': 'harbor.sh',
        'description': 'Harbor container registry deployment.',
        'tags': ['harbor', 'registry', 'container']
    },
    'rustfs': {
        'preferred_script': 'rustfs.sh',
        'description': 'Deploys RustFS object storage using the official Docker image.',
        'tags': ['rustfs', 'object-storage', 's3']
    }
}

# Directories to exclude from template generation
EXCLUDED_DIRS = {
    '.git', '.github', '.trunk', 'environments', 'helm-harbor', 
    'ngrok-operator', 'test', '__pycache__'
}

def extract_description_from_readme(directory):
    """Extract description from README.md file in the directory."""
    readme_path = os.path.join(directory, 'README.md')
    if os.path.exists(readme_path):
        try:
            with open(readme_path, 'r', encoding='utf-8') as f:
                content = f.read()
                
            # Look for the first meaningful line after headers
            lines = content.split('\n')
            for line in lines:
                line = line.strip()
                # Skip empty lines, headers, and code blocks
                if (line and 
                    not line.startswith('#') and 
                    not line.startswith('```') and 
                    not line.startswith('`') and
                    len(line) > 20):
                    # Clean up the line
                    line = re.sub(r'\[.*?\]\(.*?\)', '', line)  # Remove markdown links
                    line = re.sub(r'\*\*.*?\*\*', '', line)    # Remove bold text
                    line = line.strip()
                    if line and len(line) > 10:
                        return line[:100] + ('...' if len(line) > 100 else '')
        except Exception as e:
            print(f"Warning: Could not read README.md in {directory}: {e}")
    return None

def find_script_files(directory):
    """Find all script files in a directory."""
    script_patterns = ['*.sh', '*.yaml', '*.yml', '*.config', '*.toml', '*.json']
    scripts = []
    
    for pattern in script_patterns:
        scripts.extend(glob.glob(os.path.join(directory, pattern)))
        scripts.extend(glob.glob(os.path.join(directory, '**', pattern), recursive=True))
    
    return [os.path.relpath(script, directory) for script in scripts]

def generate_tags_from_name(name):
    """Generate basic tags from directory name."""
    base_tags = [name.lower()]
    
    # Add common technology tags based on name patterns
    if 'k8s' in name or 'kubernetes' in name or name in ['k3s', 'rke2']:
        base_tags.append('kubernetes')
    if 'docker' in name:
        base_tags.append('container')
    if any(term in name for term in ['proxy', 'nginx', 'traefik']):
        base_tags.append('proxy')
    if any(term in name for term in ['vpn', 'wireguard']):
        base_tags.append('vpn')
    if any(term in name for term in ['cloud', 'azure', 'aws', 'gcp']):
        base_tags.append('cloud')
    
    return base_tags

def get_preferred_config_file(directory, dir_name):
    """Get the preferred configuration file for a directory."""
    scripts = find_script_files(directory)
    
    if not scripts:
        return None
    
    # Check if we have a predefined preferred script
    if dir_name in TEMPLATE_CONFIGS:
        preferred = TEMPLATE_CONFIGS[dir_name]['preferred_script']
        if preferred in scripts:
            return preferred
    
    # Common preferred script names
    preferred_names = [
        'install.sh', 'setup.sh', 'deploy.sh', 'main.sh',
        f'{dir_name}.sh', 'docker.sh', 'server.sh', 'config.yaml',
        f'{dir_name}.config', 'ssh-443.config'
    ]
    
    for preferred in preferred_names:
        if preferred in scripts:
            return preferred
    
    # If no preferred script found, return the first .sh file
    sh_scripts = [s for s in scripts if s.endswith('.sh')]
    if sh_scripts:
        return sh_scripts[0]
    
    # Try other common file types
    for ext in ['.config', '.yaml', '.yml', '.toml']:
        ext_scripts = [s for s in scripts if s.endswith(ext)]
        if ext_scripts:
            return ext_scripts[0]
    
    # Return the first script file
    return scripts[0] if scripts else None

def generate_index_yaml():
    """Generate the index.yaml file based on directory structure."""
    root_dir = '.'
    templates = []
    
    # Get all directories in the root
    for item in os.listdir(root_dir):
        item_path = os.path.join(root_dir, item)
        
        # Skip files and excluded directories
        if not os.path.isdir(item_path) or item in EXCLUDED_DIRS:
            continue
        
        # Find configuration script
        config_file = get_preferred_config_file(item_path, item)
        if not config_file:
            print(f"Warning: No script files found in {item}, skipping...")
            continue
        
        # Get template configuration
        if item in TEMPLATE_CONFIGS:
            config = TEMPLATE_CONFIGS[item]
            description = config['description']
            tags = config['tags']
        else:
            # Try to extract description from README
            description = extract_description_from_readme(item_path)
            if not description:
                description = f"Configuration and setup scripts for {item}."
            tags = generate_tags_from_name(item)
        
        template = {
            'name': item,
            'version': '1.0.0',
            'description': description,
            'config': f"{item}/{config_file}",
            'tags': tags
        }
        
        templates.append(template)
    
    # Sort templates by name
    templates.sort(key=lambda x: x['name'])
    
    # Create the index structure
    index_data = {
        'apiVersion': 'v1',
        'templates': templates
    }
    
    # Write the index.yaml file with header comment
    with open('index.yaml', 'w', encoding='utf-8') as f:
        f.write("# This file is auto-generated by .github/scripts/generate_index.py\n")
        f.write("# Do not edit manually - changes will be overwritten\n")
        f.write("# To update: modify the directory structure or run the generation script\n\n")
        yaml.dump(index_data, f, default_flow_style=False, sort_keys=False, 
                 allow_unicode=True, width=1000)
    
    print(f"Generated index.yaml with {len(templates)} templates")
    for template in templates:
        print(f"  - {template['name']}: {template['config']}")

if __name__ == '__main__':
    generate_index_yaml()
