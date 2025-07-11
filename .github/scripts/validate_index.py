#!/usr/bin/env python3
"""
Validate the generated index.yaml file.
"""

import yaml
import os
import sys

def validate_index_yaml():
    """Validate the index.yaml file."""
    if not os.path.exists('index.yaml'):
        print("❌ index.yaml file not found")
        return False
    
    try:
        with open('index.yaml', 'r', encoding='utf-8') as f:
            data = yaml.safe_load(f)
    except yaml.YAMLError as e:
        print(f"❌ Invalid YAML syntax: {e}")
        return False
    except Exception as e:
        print(f"❌ Error reading index.yaml: {e}")
        return False
    
    # Validate structure
    if not isinstance(data, dict):
        print("❌ index.yaml must be a dictionary")
        return False
    
    if 'apiVersion' not in data:
        print("❌ Missing 'apiVersion' field")
        return False
    
    if 'templates' not in data:
        print("❌ Missing 'templates' field")
        return False
    
    if not isinstance(data['templates'], list):
        print("❌ 'templates' must be a list")
        return False
    
    # Validate each template
    required_fields = ['name', 'version', 'description', 'config', 'tags']
    template_names = set()
    
    for i, template in enumerate(data['templates']):
        if not isinstance(template, dict):
            print(f"❌ Template {i} must be a dictionary")
            return False
        
        # Check required fields
        for field in required_fields:
            if field not in template:
                print(f"❌ Template {i} missing required field: {field}")
                return False
        
        # Check for duplicate names
        name = template['name']
        if name in template_names:
            print(f"❌ Duplicate template name: {name}")
            return False
        template_names.add(name)
        
        # Validate config file exists
        config_path = template['config']
        if not os.path.exists(config_path):
            print(f"❌ Template '{name}': config file not found: {config_path}")
            return False
        
        # Validate tags
        if not isinstance(template['tags'], list):
            print(f"❌ Template '{name}': tags must be a list")
            return False
        
        if not template['tags']:
            print(f"⚠️  Template '{name}': no tags specified")
    
    print(f"✅ index.yaml is valid with {len(data['templates'])} templates")
    
    # Print summary
    print("\n📋 Templates summary:")
    for template in data['templates']:
        print(f"  • {template['name']}: {template['config']}")
    
    return True

if __name__ == '__main__':
    success = validate_index_yaml()
    sys.exit(0 if success else 1)
