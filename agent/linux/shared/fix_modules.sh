#!/bin/bash
cp -rf --remove-destination /vagrant/modules/* /etc/puppetlabs/code/environments/production/modules/
simp environment fix production
puppetserver ca clean --certname console.simp-ee.test
