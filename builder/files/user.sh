#!/bin/bash

echo 'vagrant' | passwd --stdin root
grep 'vagrant' /etc/passwd > /dev/null
if [ $? -ne 0 ]; then
	echo '* Creating user vagrant.'
	useradd vagrant
	echo 'vagrant' | passwd --stdin vagrant
fi
grep '^admin:' /etc/group > /dev/null || groupadd admin
usermod -G admin vagrant

#echo 'Defaults    env_keep += "SSH_AUTH_SOCK"' >> /etc/sudoers
echo '%admin ALL=NOPASSWD: ALL' >> /etc/sudoers
sed -i 's/Defaults\s*requiretty/Defaults !requiretty/' /etc/sudoers

