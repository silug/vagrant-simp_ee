# -*- mode: ruby -*-
# vi: set ft=ruby :

ENV['VAGRANT_EXPERIMENTAL'] = 'typed_triggers'

ip_subnet = ENV['VAGRANT_IP_SUBNET'] || '10.10.16'
domain = ENV['VAGRANT_DOMAIN'] || 'simp-ee.test'

agents = {
  'win2012r2' => { 'index' => 12, 'box' => 'devopsgroup-io/windows_server-2012r2-standard-amd64-nocm', },
  'win2016'   => { 'index' => 13, 'box' => 'peru/windows-server-2016-standard-x64-eval', 'box_version' => '20221202.01', },
  'win2019'   => { 'index' => 14, 'box' => 'gusztavvargadr/windows-server', 'box_version' => '~> 1809', },
  'centos7'   => { 'index' => 15, 'box' => 'centos/7', },
  'centos8'   => { 'index' => 16, 'box' => 'centos/stream8', },
  'oel7'      => { 'index' => 17, 'box' => 'generic/oracle7', },
  'oel8'      => { 'index' => 18, 'box' => 'generic/oracle8', },
  'rhel7'     => { 'index' => 19, 'box' => 'generic/rhel7', },
  'rhel8'     => { 'index' => 20, 'box' => 'generic/rhel8', },
  'win2022'   => { 'index' => 21, 'box' => 'gusztavvargadr/windows-server', 'box_version' => '~> 2102', },
  'rocky8'    => { 'index' => 21, 'box' => 'generic/rocky8', },
}

Vagrant.configure("2") do |config|
  console_ip = "#{ip_subnet}.11"
  console_port = '6468'
  config.vm.synced_folder './agent/linux/shared', '/vagrant'
  config.ssh.keep_alive = true

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
    console.vm.box = 'centos/stream8'
    console.vm.hostname = "console.#{domain}"
    console.vm.network 'private_network', ip: "#{ip_subnet}.11"
    console.vm.network 'forwarded_port', guest: console_port, host: console_port

    ['virtualbox', 'libvirt'].each do |p|
      console.vm.provider p do |provider|
        provider.memory = '2048'
        provider.cpus = 2
      end
    end
  end

  agents.each do |key, value|
    next unless ENV['SIMP_AGENTS'].nil? || ENV['SIMP_AGENTS'].split(%r{[\s,]+}).include?(key)

    if value['box'].nil?
      warn "VM #{key} requested but no box defined"
      next
    end

    config.vm.define key do |agent|
      agent.vm.box = value['box']
      agent.vm.box_version = value['box_version'] unless value['box_version'].nil?
      if %r{^win}.match?(key)
        agent.vm.communicator = 'winrm'
        agent.vm.hostname = key
        agent.vm.provision 'shell', inline: <<~END
          Set-ItemProperty "HKLM:\\SYSTEM\\CurrentControlSet\\Services\\Tcpip\\Parameters" -Name Domain -Value #{domain}
          Set-ItemProperty "HKLM:\\SYSTEM\\CurrentControlSet\\Services\\Tcpip\\Parameters" -Name "NV Domain" -Value #{domain}
          Set-DnsClientGlobalSetting -SuffixSearchList #{domain}
        END
      else
        agent.vm.hostname = "#{key}.#{domain}"
      end
      if %r{^oel7}.match?(key)
        agent.vm.provision 'shell', inline: <<~END
          sudo yum install -y -q oracle-epel-release-el7
        END
      end
      if %r{^oel8}.match?(key)
        agent.vm.provision 'shell', inline: <<~END
          sudo yum install -y -q oracle-epel-release-el8
        END
      end
      agent.vm.network 'private_network', ip: "#{ip_subnet}.#{value['index']}"
    end
  
  end

  config.trigger.before [:up, :provision, :reload], type: :command do |trigger|
    trigger.info = 'Initializing bolt'
    trigger.run = { inline: 'bolt module install' }
  end

  config.trigger.after [:up, :provision, :reload], type: :command do |trigger|
    trigger.info = 'Running bolt plan'
    trigger.run = {
      inline: [
        'bolt plan run simp_ee',
        ENV.key?('BOLT_VERBOSE') ? '--verbose' : '--no-verbose',
        ENV.key?('BOLT_TRACE') ? '--trace' : '',
        ENV.key?('BOLT_STREAM') ? '--stream' : '',
      ].join(' '),
    }
  end
end
