#!/bin/bash

# Install Puppet Agent

list_usage() {
	echo "Usage:"
	echo "Using command line parameters:"
	echo "./puppet-agent.sh "
	echo "    -i|--masterip  	  The IPv4 number of the puppet master"
	echo "    -m|--master   	  The FQDN hostname of the puppet master"
	echo ""
	echo "./puppet-agent.sh -i 192.168.0.22 -m puppetmaster.local"
	echo ""
	echo "or use env variables"
	echo ""
	echo "export MASTER=puppetmaster.localhost"
	echo "export MASTERIP=192.168.0.33"
	echo "./puppet-agent"
}

  if [[ $MASTERIP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$  && $MASTER != "" ]];
  then
  	echo "Using environmental variables"
  else
	POSITIONAL_ARGS=()
	while [[ $# -gt 0 ]]; do
	  case $1 in
	    -m|--master)
	      MASTER="$2"
	      shift
	      shift
	      ;;
	    -i|--masterip)
	      MASTERIP="$2"
	      shift
	      shift
	      ;;
	    -*|--*)
	      echo "Unknown option $1"
	      list_usage
	      exit 3
	      ;;
	    *)
	      POSITIONAL_ARGS+=("$1")
	      shift
	      ;;
	  esac
	done
	set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters
  fi

# Ensure MASTER and MASTERIP are set either via environment variables or command-line arguments
if [[ -z "$MASTER" || -z "$MASTERIP" ]]; then
	echo "Error: MASTER and MASTERIP must be specified."
	list_usage
	exit 3
fi

sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1
sudo sysctl -w net.ipv6.route.flush=1


ENVIRONMENT="production"
FIRST_8_UUID=$(uuidgen |  awk -F- '{print $1}')
HOST=$(hostname)
HOST_CERTNAME="${HOST,,}_${FIRST_8_UUID,,}"
PE_MASTER=${MASTER}
CA_SERVER=${MASTER}
P_VERSION='8'

set_hosts_file() {
	cp /etc/hosts /etc/hosts.pre_puppet
	echo -ne "${MASTERIP}\t${MASTER}\n" >> /etc/hosts
	HOST_IP=$(hostname -I | awk '{print $1}')
	echo -ne "${HOST_IP}\t$(hostname -f)\t$(hostname)\n" >> /etc/hosts
}

. /etc/os-release
case $ID in
  amzn|rocky|almalinux|rhel|ubuntu)
   set_hosts_file
   if [ "$ID" == "ubuntu" ];then
     DIST=$(lsb_release -c | awk '{print $2}')
     P_cmd='sudo puppet'
     sudo apt-get update
     sudo apt-get install curl apt-transport-https lsb-release wget
     wget https://apt.puppetlabs.com/puppet${P_VERSION}-release-${DIST}.deb
     sudo dpkg -i puppet${P_VERSION}-release-${DIST}.deb
     sudo apt-get update
     sudo apt-get install -y puppet-agent
   else
     P_cmd='/opt/puppetlabs/bin/puppet'
     VERSION=$(uname -r | sed 's/^.*\(el[0-9]\+\).*$/\1/' | cut -c 3-)
     rpm -Uvh http://yum.puppetlabs.com/puppet${VERSION}-release-el-${VERSION}.noarch.rpm
     yum -y install puppet-agent
   fi
    ;;
  *) echo "Unsupported distribution."
     exit 2
    ;;
esac

ln -s /opt/puppetlabs/bin/puppet /usr/local/bin/

if [ ! -d /etc/puppetlabs/puppet ]; then
  mkdir -p /etc/puppetlabs/puppet
fi
cat > /etc/puppetlabs/puppet/csr_attributes.yaml << YAML
extension_requests:
  pp_instance_id: $HOST_CERTNAME
  pp_hostname: $HOST_CERTNAME
YAML

$P_cmd config set server $PE_MASTER --section main
$P_cmd config set ca_server $CA_SERVER  --section main
$P_cmd config set hostname $HOST_CERTNAME --section main
$P_cmd config set certname $HOST_CERTNAME --section main
$P_cmd config set environment $ENVIRONMENT --section agent
$P_cmd agent -t

sudo sysctl -w net.ipv6.conf.all.disable_ipv6=0
sudo sysctl -w net.ipv6.conf.default.disable_ipv6=0
sudo sysctl -w net.ipv6.route.flush=0

echo -ne "\n================================================================================================"
echo  " Sign the certificate for the agent, either on the Puppet Master Console or on the command line\n"
echo  " and then run the Puppet Agent locally:--  puppet agent -t "
echo  " -- Puppet Master Console: Certificates -> Unsigned certificates ( -> Accept )"
echo  " -- Puppet Master Command Line Interface:--  puppetserver ca sign $HOST_CERTNAME"
echo -ne  "================================================================================================\n"


