# -*- mode: ruby -*-
# vi: set ft=ruby :

ENV['VAGRANT_EXPERIMENTAL'] = 'typed_triggers'

ip_subnet = ENV['VAGRANT_IP_SUBNET'] || '10.10.16'
domain = ENV['VAGRANT_DOMAIN'] || 'simp-ee.test'

Vagrant.configure("2") do |config|
  config.vm.synced_folder '.', '/vagrant', disabled: true

  config.vm.provider 'libvirt' do |libvirt|
    libvirt.qemu_use_session = false
  end

  config.vm.define 'puppet' do |puppet|
    puppet.vm.box = 'centos/7'
    puppet.vm.hostname = "puppet.#{domain}"
    puppet.vm.network 'private_network', ip: "#{ip_subnet}.10"

    ['virtualbox', 'libvirt'].each do |p|
      puppet.vm.provider p do |provider|
        provider.memory = '4096'
        provider.cpus = 4
      end
    end
  end

  config.vm.define 'console' do |console|
    console.vm.box = 'centos/7'
    console.vm.hostname = "console.#{domain}"
    console.vm.network 'private_network', ip: "#{ip_subnet}.11"
    console.vm.network 'forwarded_port', guest: 6468, host: 6468

    ['virtualbox', 'libvirt'].each do |p|
      console.vm.provider p do |provider|
        provider.memory = '2048'
        provider.cpus = 2
      end
    end
  end

  config.trigger.before [:up, :provision, :reload], type: :command do |trigger|
    trigger.info = 'Initializing bolt'
    trigger.run = { inline: 'bolt module install' }
  end

  config.trigger.after [:up, :provision, :reload], type: :command do |trigger|
    trigger.info = 'Running bolt plan'
    trigger.run = { inline: 'bolt plan run simp_ee --verbose --trace --stream' }
  end
end
