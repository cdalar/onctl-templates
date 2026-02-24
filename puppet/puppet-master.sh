#!/bin/bash

# Install Puppet master

PUPPET_VERSION='2025.8.0'

set_hosts_file() {
        cp /etc/hosts /etc/hosts.pre_puppet
        HOST_IP=$(hostname -I | awk '{print $1}')
        echo -e "${HOST_IP}\tpuppetmaster\tpuppet\t\n" >> /etc/hosts
        echo -e "${HOST_IP}\t$(hostname -f)\t$(hostname)\n" >> /etc/hosts
}

sysctl -w net.ipv6.conf.all.disable_ipv6=1
sysctl -w net.ipv6.conf.default.disable_ipv6=1
sysctl -w net.ipv6.route.flush=1

. /etc/os-release
case $ID in
	centos|rocky|almalinux|rhel|ubuntu)
		set_hosts_file
		mkdir /root/download ; 
		cd /root/download
		if [ "$ID" == "ubuntu" ];then
		    UB_RELEASE="ubuntu-$(lsb_release -r | awk '{print $2}')-amd64"
		    PUPPET_PATH="puppet-enterprise-$PUPPET_VERSION-${UB_RELEASE}"
		    wget "https://pm.puppetlabs.com/puppet-enterprise/$PUPPET_VERSION/$PUPPET_PATH.tar.gz"
		    sudo ln -s /opt/puppetlabs/server/apps/puppetserver/bin/puppetserver /usr/local/bin/
		else
		    EL_VERSION="$(uname -r | sed 's/^.*\(el[0-9]\+\).*$/\1/' | cut -c 3-)-x86_64"
		    PUPPET_PATH="puppet-enterprise-$PUPPET_VERSION-el-${EL_VERSION}"
		    wget "https://pm.puppetlabs.com/puppet-enterprise/$PUPPET_VERSION/$PUPPET_PATH.tar.gz"
		fi

		tar zxvf $(ls $PUPPET_PATH.tar.gz)
		cd $PUPPET_PATH
		cat > ./pe.conf << PECONF
		{
		  "console_admin_password": "LongAdmin-12"
		  "puppet_enterprise::puppet_master_host": "%{::trusted.certname}"
		  "puppet_enterprise::activity_database_name": "pe-activity"
		  "puppet_enterprise::activity_database_user": "pe-activity"
		  "puppet_enterprise::classifier_database_name": "pe-classifier"
		  "puppet_enterprise::classifier_database_user": "pe-classifier"
		  "puppet_enterprise::orchestrator_database_name": "pe-orchestrator"
		  "puppet_enterprise::orchestrator_database_user": "pe-orchestrator"
		  "puppet_enterprise::puppetdb_database_name": "pe-puppetdb"
		  "puppet_enterprise::puppetdb_database_user": "pe-puppetdb"
		  "puppet_enterprise::rbac_database_name": "pe-rbac"
		  "puppet_enterprise::rbac_database_user": "pe-rbac"
		  "pe_install::puppet_master_dnsaltnames": [
			"puppet",
			"puppetmaster"
			]
		  "puppet_enterprise::profile::master::r10k_remote": "git@bitbucket.org:example_team/puppet.git"
		  "puppet_enterprise::profile::master::r10k_private_key": "/etc/puppetlabs/puppetserver/ssh/id-control_repo.rsa"
		  "puppet_enterprise::profile::master::code_manager_auto_configure": true
		  "puppet_enterprise::profile::master::file_sync_enabled": true
		  "puppet_enterprise::profile::console::rbac_token_auth_lifetime": "1y"
		}
PECONF
		./puppet-enterprise-installer -c pe.conf
	    ;;
	    *) echo "Unsupported distribution."
	       exit 1
	    ;;
esac

# Install hiera eyaml on the Puppet Master and create eyaml keys
/opt/puppetlabs/puppet/bin/gem install hiera-eyaml
mkdir -p /etc/puppetlabs/puppet/eyaml-keys/production
/opt/puppetlabs/puppet/bin/eyaml createkeys
cp -rp keys/* /etc/puppetlabs/puppet/eyaml-keys/production/
rm -rf keys

# Set example hiera file
cat > /etc/puppetlabs/code/environments/production/hiera.yaml << EOF
---
version: 5
defaults:
  datadir: "data"
  data_hash: yaml_data
hierarchy:
  - name: "Per-node encrypted"
    path: "nodes/%{trusted.certname}.eyaml"
    lookup_key: eyaml_lookup_key
    options:
      # example using PKCS7 keys (common for eyaml)
      pkcs7_private_key: "/etc/puppetlabs/puppet/eyaml-keys/production/private_key.pk7.pem"
      pkcs7_public_key:  "/etc/puppetlabs/puppet/eyaml-keys/production/public_key.pk7.pem"
  - name: "Per-node plain YAML"
    path: "nodes/%{trusted.certname}.yaml"
  - name: "Environment encrypted"
    path: "environments/%{::environment}.eyaml"
    lookup_key: eyaml_lookup_key
    options:
      pkcs7_private_key: "/etc/puppetlabs/puppet/eyaml-keys/production/private_key.pk7.pem"
      pkcs7_public_key:  "/etc/puppetlabs/puppet/eyaml-keys/production/public_key.pk7.pem"
  - name: "Environment YAML"
    path: "environments/%{::environment}.yaml"
  - name: "Common encrypted"
    path: "common.eyaml"
    lookup_key: eyaml_lookup_key
    options:
      pkcs7_private_key: "/etc/puppetlabs/puppet/eyaml-keys/production/private_key.pk7.pem"
      pkcs7_public_key:  "/etc/puppetlabs/puppet/eyaml-keys/production/public_key.pk7.pem"
  - name: "Common YAML"
    path: "common.yaml"
EOF

sysctl -w net.ipv6.conf.all.disable_ipv6=0
sysctl -w net.ipv6.conf.default.disable_ipv6=0
sysctl -w net.ipv6.route.flush=0



## Final setup step.  Running 'puppet agent -t' twice on the primary server node.
for i in {1..2}; do sudo puppet agent -t; done


