#!bin/bash
sudo rpm -Uvh https://yum.puppet.com/puppet6-release-el-7.noarch.rpm
#sudo yum update -yi
sudo yum install puppet-agent -y
sudo systemctl start puppet
sudo systemctl enable puppet
clientname=$(hostname -f)
echo $clientname
sudo echo "
[agent]
    server = puppet.qhkdp2mlxxjuneuxgfilw4tn4a.bx.internal.cloudapp.net
    certname = $clientname
    environment = production
    listen = false
    pluginsync = true
    report = true " >> /etc/puppetlabs/puppet/puppet.conf
sudo systemctl restart puppet
