# @summary Install SIMP Enterprise Edition
# @param targets The targets to run on
# @param license_key A SIMP EE license key
# @param ip_subnet The IP subnet range to use for the private network (the IP address with the last octet removed)
# @param simprelease SIMP release version
# @param simpreleasetype SIMP release type ("development", for example)
# @param ee_simprelease SIMP EE release version
# @param ee_simpreleasetype SIMP EE release type ("development", for example
# @param rhsm_user Username for registering RHEL nodes with subscription management
# @param rhsm_pass Password for registering RHEL nodes with subscription management
plan simp_ee (
  TargetSpec          $targets              = 'all',
  Optional[String[1]] $license_key          = system::env('SIMP_LICENSE_KEY'),
  String[5]           $ip_subnet            = system::env('VAGRANT_IP_SUBNET') ? {
    undef   => '10.10.16',
    default => system::env('VAGRANT_IP_SUBNET'),
  },
  String[1]           $console_ip           = "${ip_subnet}.11",
  Optional[String[1]] $simprelease          = system::env('SIMP_RELEASE'),
  Optional[String[1]] $simpreleasetype      = system::env('SIMP_RELEASETYPE'),
  Optional[String[1]] $ee_simprelease       = system::env('SIMP_EE_RELEASE'),
  Optional[String[1]] $ee_simpreleasetype   = system::env('SIMP_EE_RELEASETYPE'),
  Optional[String[1]] $rhsm_user            = system::env('SIMP_RHSM_USER'),
  Optional[String[1]] $rhsm_pass            = system::env('SIMP_RHSM_PASS'),
) {
  get_targets($targets).each |$target| {
    add_facts($target, 'ssh_user' => $target.user)
  }

  apply_prep($targets)

  $rhel = get_targets($targets).filter |$target| {
    $target.facts['os']['name'] == 'RedHat'
  }

  unless $rhel.empty {
    if $rhsm_user != undef and $rhsm_pass != undef {
      run_command(
        "subscription-manager status || subscription-manager register --username='${rhsm_user}' --password='${rhsm_pass}' --auto-attach",
        $rhel,
        'description' => 'Register with RHEL subscription management',
      )
    } else {
      out::message("RHEL nodes ${rhel} found, but no subscription-manager username/password defined.\nyum may not be functional.")
    }
  }

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

  $hosts = get_targets($targets).reduce( {}) |$memo, $target| {
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
          if $target.facts['role'] == 'console' {
            'sicura-console-collector'
          },
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
    get_targets($targets).filter |$target| { $target.facts['kernel'] != 'windows' },
    '_description' => 'Enable ssh keepalives',
  ) {
    include simp_ee::keepalive
  }

  $bootstrap_results = apply(
    $puppet,
    '_description'  => 'Bootstrap the SIMP server',
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

  run_plan('simp_ee::check_puppetserver', $puppet)

  apply(
    $puppet,
    '_description'  => 'Classify nodes',
  ) {
    class { 'simp_ee::install':
      license_key        => $license_key,
      simprelease        => $simprelease,
      simpreleasetype    => $simpreleasetype,
      ee_simprelease     => $ee_simprelease,
      ee_simpreleasetype => $ee_simpreleasetype,
    }
    -> class { 'simp_ee::classify': }
  }

  apply(
    $puppet,
    '_description' => 'Run puppet agent on puppet server',
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
      content => "${$fqdns.join("\n")}\n",
    }
    ~> exec { '/var/simp/environments/production/FakeCA/gencerts_nopass.sh':
      path        => '/bin:/usr/bin',
      cwd         => '/var/simp/environments/production/FakeCA',
      refreshonly => true,
      timeout     => 0,
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
      $console,
      '_description' => 'Bootstrap console server',
    ) {
      file { '/etc/sicura':
        ensure => directory,
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
      }
      -> file { '/etc/sicura/license.key':
        ensure  => file,
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        content => "${license_key}\n",
      }
      -> package { 'sicura-release-enterprise':
        ensure => installed,
        source => 'https://download.simp-project.com/sicura-release-enterprise.el7.rpm',
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
          file { '/etc/sicura':
            ensure => directory,
            owner  => 'root',
            group  => 'root',
            mode   => '0755',
          }
          -> file { '/etc/sicura/license.key':
            ensure  => file,
            owner   => 'root',
            group   => 'root',
            mode    => '0644',
            content => "${license_key}\n",
          }
          # FIXME - This is a workaround for a failure.  Puppet should be
          # installing the package, but fails for unknown reasons.  This may be
          # a bug in a particular version of the puppet-agent package.
          -> package { 'simp-release-enterprise':
            ensure => installed,
            source => "https://download.simp-project.com/sicura-release-enterprise.el${target.facts['os']['release']['major']}.rpm",
          } -> exec { 'puppet agent -t':
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
          -> exec { '/bin/bash /vagrant/provision_agent.sh':
            path        => '/vagrant:/bin:/usr/bin',
            environment => [
              'SCAN_ORG=sicura',
              'SCAN_TYPE=agent',
              "CONSOLE_IP=${console_ip}",
              'CONSOLE_PORT=6468'
            ],
            logoutput   => true,
            returns     => [0],
            }
        }
      }
    }
  }
}
