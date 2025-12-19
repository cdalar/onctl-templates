# Ansible playbooks

Use the bundled playbooks to provision software after your VM is created. The docker example installs Docker with Ansible in a single run:

```
onctl up -n ansible -a ansible/playbooks/docker.yaml
```

Add more playbooks under `ansible/playbooks/` to automate additional configuration tasks.
