# @summary Install SIMP Enterprise Edition
# @param targets The targets to run on.
plan simp_ee (
  TargetSpec          $targets     = 'all',
  Optional[String[1]] $license_key = system::env('SIMP_LICENSE_KEY'),
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
          if $v[0] =~ /^e/ and $v[1]['ip'] {
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

  $bootstrap_results = apply(
    $puppet,
    '_description'  => 'Bootstrap the SIMP server',
    # '_description'  => 'Prep the SIMP server for bootstrap',
    '_catch_errors' => true,
  ) {
    class { 'simp_ee::install':
      license_key => $license_key,
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
        '/etc/puppetlabs/code/environments/production/data/RedHat.yaml',
        '/etc/puppetlabs/code/environments/production/data/windows.yaml',
        '/etc/puppetlabs/code/environments/production/data/role/console.yaml',
      ]

      file { '/etc/puppetlabs/code/environments/production/data/role':
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
        returns     => [0, 2],
      }
    }
  }
}
