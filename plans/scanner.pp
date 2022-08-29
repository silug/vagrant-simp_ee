# @summary Configure simp_scanner Puppet module
# @param token The SIMP Console registration token
# @param msi_pkg URL of the scanner MSI
# @param rpm_pkg URL of the scanner RPM
# @param targets The targets to run on
# @param collector A collector URL to override the default
# @param extra_config Additional scanner collector configuration
plan simp_ee::scanner (
  String     $token,
  Variant[
    Stdlib::HTTPUrl,
    Stdlib::HTTPSUrl
  ]          $msi_pkg,
  Variant[
    Stdlib::HTTPUrl,
    Stdlib::HTTPSUrl
  ]          $rpm_pkg,
  Variant[
    Undef,
    Stdlib::HTTPUrl,
    Stdlib::HTTPSUrl
  ]          $collector = undef,
  TargetSpec $targets   = 'all',
  Hash       $extra_config = {},
) {
  apply_prep($targets)

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

  if $puppet.empty or $console.empty {
    fail_plan("Failed to determine puppet (${puppet}) and console (${console}) nodes.")
  }

  $_collector = $collector.then |$x| { $x }.lest || { "http://${$console[0].facts['fqdn']}:6468/collector/default" }

  apply(
    $puppet,
    '_description' => 'Classify nodes'
  ) {
    ['RedHat', 'windows'].each |$_os| {
      file { "/etc/puppetlabs/code/environments/production/data/os/${_os}":
        ensure => directory,
        owner  => 'root',
        group  => 'puppet',
        mode   => '0750',
      }
      -> file { "/etc/puppetlabs/code/environments/production/data/os/${_os}/scanner.yaml":
        ensure  => file,
        owner   => 'root',
        group   => 'puppet',
        mode    => '0640',
        content => epp('simp_ee/scanner.yaml.epp', {
            'collector'      => $_collector,
            'token'          => $token,
            'extra_config'   => $extra_config,
            'abilities'      => [
              # FIXME - Disabled until we are configuring the assessor (#7)
              # 'ciscat',
              $_os ? {
                'windows' => 'jscat',
                default   => 'openscap',
              },
            ],
            'package_source' => $_os ? {
              'windows' => $msi_pkg,
              default   => $rpm_pkg,
            },
        }),
      }
    }
  }
}
