# @summary Install SIMP Enterprise Edition
# @param targets The targets to run on
# @param license_key A SIMP EE license key
# @param ip_subnet The IP subnet range to use for the private network (the IP address with the last octet removed)
# @param simprelease SIMP release version
# @param simpreleasetype SIMP release type ("development", for example)
# @param ee_simprelease SIMP EE release version
# @param ee_simpreleasetype SIMP EE release type ("development", for example
plan simp_ee (
  TargetSpec          $targets              = 'all',
  Optional[String[1]] $license_key          = system::env('SIMP_LICENSE_KEY'),
  String[5]           $ip_subnet            = system::env('VAGRANT_IP_SUBNET') ? {
    undef   => '10.10.16',
    default => system::env('VAGRANT_IP_SUBNET'),
  },
  Optional[String[1]] $simprelease          = system::env('SIMP_RELEASE'),
  Optional[String[1]] $simpreleasetype      = system::env('SIMP_RELEASETYPE'),
  Optional[String[1]] $ee_simprelease       = system::env('SIMP_EE_RELEASE'),
  Optional[String[1]] $ee_simpreleasetype   = system::env('SIMP_EE_RELEASETYPE'),
) {
  apply_prep($targets)

  get_targets($targets).each |$target| {
    if $target.facts['role'] =~ Undef {
      case $target.facts['hostname'] {
        /^puppet/: {
          add_facts($target, { 'role' => 'puppet' })
        }
        /^console/: {
          add_facts($target, { 'role' => 'console' })
        }
        default: {}
      }
    }
  }

  $puppet = get_targets($targets).reduce([]) |$memo, $target| {
    if $target.facts['role'] == 'puppet' {
      $memo + [$target]
    } else {
      $memo
    }
  }

  $console = get_targets($targets).reduce([]) |$memo, $target| {
    if $target.facts['role'] == 'console' {
      $memo + [$target]
    } else {
      $memo
    }
  }

  $hosts = get_targets($targets).reduce({}) |$memo, $target| {
    $memo + {
      $target.facts['fqdn'] => {
        'ip' => $target.facts['networking']['interfaces'].reduce('') |$m, $v| {
          if $v[0] =~ /^[Ee]/ and $v[1]['ip'] and $v[1]['mac'] and $v[1]['ip'].regsubst(/\.[^.]+$/, '') == $ip_subnet {
            $v[1]['ip']
          } else {
            $m
          }
        },
        'host_aliases' => [
          $target.facts['hostname'],
        ],
      },
    }
  }

  apply($targets, '_description' => 'Configure hosts file and role fact') {
    $hosts.each |$key, $value| {
      host { $key:
        * => $value,
      }
    }

    if $facts['role'] {
      file { ['/etc/facter', '/etc/facter/facts.d']:
        ensure => directory,
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
      }
      -> file { '/etc/facter/facts.d/role.txt':
        ensure  => file,
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        content => "role=${facts['role']}\n",
      }
    }
  }

  # HACK - Ensure that ssh keepalives are sent to avoid timeouts.
  apply(
    $puppet,
    '_description' => 'Enable ssh keepalives',
  ) {
    sshd_config { 'ClientAliveInterval':
      ensure => present,
      value  => '10',
      notify => Service['sshd'],
    }
    sshd_config { 'ClientAliveCountMax':
      ensure => present,
      value  => '3',
      notify => Service['sshd'],
    }
    service { 'sshd':
      ensure => running,
      enable => true,
    }
  }

  $bootstrap_results = apply(
    $puppet,
    '_description'  => 'Bootstrap the SIMP server',
    # '_description'  => 'Prep the SIMP server for bootstrap',
    '_catch_errors' => true,
  ) {
    class { 'simp_ee::install':
      license_key        => $license_key,
      simprelease        => $simprelease,
      simpreleasetype    => $simpreleasetype,
      ee_simprelease     => $ee_simprelease,
      ee_simpreleasetype => $ee_simpreleasetype,
    }
    -> class { 'simp_ee::config': }
    ~> class { 'simp_ee::bootstrap': }
  }

  # FIXME - Bootstrap fails with an empty error message.
  # Ignore that and check the status of the puppetserver service.
  $bootstrap_results.each |$result| {
    if $result.report {
      out::message($result.report)
    }

    if $result.error {
      warning($result.error)
    }
  }

  # run_command('simp bootstrap -r', $puppet, 'Bootstrap the SIMP server')

  # $service_results = run_task(
  #   'service',
  #   $puppet,
  #   'Check puppetserver status',
  #   '_catch_errors' => true,
  #   'action'        => 'status',
  #   'name'          => 'puppetserver',
  # )

  # if $service_results.any |$result| { $result.value['status'] =~ /ActiveState=failed/ } {
  #   $failed_targets = $service_results.reduce([]) |$memo, $result| {
  #     if $result.value['status'] =~ /ActiveState=failed/ {
  #       $memo + [ $result.target ]
  #     } else {
  #       $memo
  #     }
  #   }
  #
  #   fail_plan("Failed to start puppetserver on ${failed_targets}")
  # }

  $fqdns = get_targets($targets).reduce([]) |$memo, $target| {
    $memo + $target.facts['fqdn']
  }

  apply(
    $puppet,
    '_description' => 'Configure FakeCA',
  ) {
    file { '/var/simp/environments/production/FakeCA/togen':
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => "${$fqdns.join("\n")}\n"
    }
    ~> exec { '/var/simp/environments/production/FakeCA/gencerts_nopass.sh':
      path        => '/bin:/usr/bin',
      cwd         => '/var/simp/environments/production/FakeCA',
      refreshonly => true,
    }
    ~> exec { 'chgrp -R puppet /var/simp/environments/production/site_files/pki_files':
      path        => '/bin:/usr/bin',
      refreshonly => true,
    }
  }

  $agents = get_targets($targets) - $puppet
  unless $agents.empty {
    $serverlist = $puppet.map |$target| { $target.facts['fqdn'] }
    unless $serverlist.empty {
      run_task(
        'puppet_conf',
        $agents,
        'action'  => 'set',
        'setting' => 'server_list',
        'value'   => $serverlist.join(','),
      )

      run_task(
        'puppet_conf',
        $agents,
        'action'  => 'set',
        'setting' => 'ca_server',
        # FIXME - This should not be hard-coded
        'value'   => $serverlist[0],
      )
    }

    run_task(
      'puppet_conf',
      $agents,
      'action'  => 'set',
      'setting' => 'ca_port',
      # FIXME - This should not be hard-coded
      'value'   => '8141',
    )
  }

  if $license_key and !$console.empty {
    apply(
      $puppet,
      '_description' => 'Classify nodes',
    ) {
      $files = [
        '/etc/puppetlabs/code/environments/production/hiera.yaml',
        '/etc/puppetlabs/code/environments/production/data/os/RedHat.yaml',
        '/etc/puppetlabs/code/environments/production/data/os/windows.yaml',
        '/etc/puppetlabs/code/environments/production/data/role/console.yaml',
        '/etc/puppetlabs/code/environments/production/data/role/puppet.yaml',
      ]

      file { [
        '/etc/puppetlabs/code/environments/production/data/os',
        '/etc/puppetlabs/code/environments/production/data/role',
      ]:
        ensure => directory,
        owner  => 'root',
        group  => 'puppet',
        mode   => '0750',
      }

      $files.each |$name| {
        file { $name:
          ensure  => file,
          owner   => 'root',
          group   => 'puppet',
          mode    => '0640',
          content => file("simp_ee/${$name.split('/')[-1]}"),
        }
      }
    }

    apply(
      $console,
      '_description' => 'Bootstrap console server',
    ) {
      file { '/etc/simp':
        ensure => directory,
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
      }
      file { '/etc/simp/license.key':
        ensure  => file,
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        content => "${license_key}\n",
      }
      -> exec { 'puppet agent -t':
        path        => '/opt/puppetlabs/bin:/bin:/usr/bin',
        environment => [
          'USER=root',
          'HOME=/root',
        ],
        logoutput   => true,
        tries       => 2,
        timeout     => 0,
        returns     => [0, 2],
      }
    }
  }

  unless ($agents - $console).empty {
    out::message('Initial Puppet agent run')
    ($agents - $console).parallelize |$target| {
      # On Windows, use the `puppet_agent::run` plan since an exec of `puppet
      # agent -t` does not appear to work correctly.
      #
      # On everything else (presumably Linux), use the exec so we can
      # automatically retry.  Also, the `puppet_agent::run` plan exits with a
      # useless error message "The Puppet run failed in an unexpected way".
      if $target.facts['os']['name'] == 'windows' {
        $pass_1 = run_plan(
          'puppet_agent::run',
          'targets'       => $target,
          '_catch_errors' => true,
        )

        $exitcode = $pass_1[0].to_data['value']['exitcode']

        if $exitcode in [0, 2] {
          $pass_1
        } elsif $exitcode == 1 {
          $logs = $pass_1[0].to_data['value']['report']['logs'].map |$log| { $log['message'] }.join("\n")
          fail_plan("Puppet exited with return value ${exitcode} on target ${target}:\n${logs}")
        } else {
          run_plan(
            'puppet_agent::run',
            'targets'       => $target,
            '_catch_errors' => false,
          )
        }
      } else {
        apply(
          $target,
          '_description' => 'Initial Puppet agent run',
        ) {
          exec { 'puppet agent -t':
            path        => '/opt/puppetlabs/bin:/bin:/usr/bin',
            environment => [
              'USER=root',
              'HOME=/root',
            ],
            logoutput   => true,
            tries       => 2,
            timeout     => 0,
            returns     => [0, 2],
          }
        }
      }
    }
  }
}
