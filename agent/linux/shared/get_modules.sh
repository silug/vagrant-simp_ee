#!/bin/bash
# This script will load the necessary modules into the /vagrant/modules dir necessary for use before you run fix_modules.sh

mkdir modules
cd ./modules
git clone https://gitlab.sicura.dev/sicura/puppet/puppet-sicura_console.git sicura_console
git clone https://gitlab.sicura.dev/sicura/puppet/puppet-simp_enterprise_el.git simp_enterprise_el
git clone https://gitlab.sicura.dev/sicura/puppet/simp_enterprise_el_disa.git
git clone https://gitlab.sicura.dev/sicura/puppet/simp_enterprise_el_cis.git
git clone https://gitlab.sicura.dev/sicura/puppet/simp_enterprise_el_ssg.git
git clone https://github.com/simp/pupmod-simp-sudo.git sudo
git clone https://github.com/voxpupuli/puppet-systemd.git systemd
git clone https://github.com/simp/pupmod-simp-aide.git aide
git clone https://github.com/simp/pupmod-simp-rsyslog.git rsyslog
git clone https://github.com/simp/pupmod-simp-auditd.git auditd
git clone https://github.com/simp/pupmod-simp-tlog.git tlog
git clone https://github.com/simp/pupmod-simp-simp.git simp
git clone https://github.com/simp/pupmod-simp-pupmod.git pupmod
git clone https://github.com/simp/pupmod-simp-journald.git journald

