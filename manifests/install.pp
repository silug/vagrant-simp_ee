# @summary Installs SIMP
#
# @param community_release URL of the SIMP Community Edition release package
# @param enterprise_release URL of the SIMP Enterprise Edition release package
# @param license_key License key for SIMP Enterprise Edition
#
# @example
#   include simp_ee::install
class simp_ee::install (
  String           $community_release    = 'https://download.simp-project.com/simp-release-community.rpm',
  String           $enterprise_release   = "https://download.simp-project.com/sicura-release-enterprise.el${facts['os']['release']['major']}.rpm",
  String           $console_release      = "https://download.simp-project.com/sicura-release-console.el${facts['os']['release']['major']}.rpm",
  Optional[String] $license_key          = undef,
  String           $release_package      = $license_key ? {
    undef   => $community_release,
    default => $enterprise_release,
  },
  String           $release_package_name = $release_package.split('/')[-1].regsubst(/(?:(?:-\d[^-]*){2}|\.el\d+)?\.rpm$/, ''),
  String           $console_release_package_name = $console_release.split('/')[-1].regsubst(/(?:(?:-\d[^-]*){2}|\.el\d+)?\.rpm$/, ''),
  Enum[
    'community',
    'enterprise'
  ]                $install_type         = $release_package_name.split('-')[-1],
  Array            $community_packages   = [
    'simp-adapter',
    'simp',
    'puppetserver',
  ],
  Array            $enterprise_packages  = [
    'simp-enterprise',
  ],
  String           $license_key_file     = '/etc/sicura/license.key',
  Optional[String] $simprelease          = undef,
  Optional[String] $simpreleasetype      = undef,
  Optional[String] $ee_simprelease       = undef,
  Optional[String] $ee_simpreleasetype   = undef,
) {
  package { $release_package_name:
    ensure => installed,
    source => $release_package,
  }

  unless $license_key =~ Undef {
    file { $license_key_file.regsubst(/\/[^\/]*$/, ''):
      ensure => directory,
      owner  => 'root',
      group  => 'root',
      mode   => '0755',
    }
    -> file { $license_key_file:
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0640',
      content => $license_key,
    }
  }

  if $simprelease {
    file { '/etc/yum/vars/simprelease':
      ensure  => file,
      content => "${simprelease}\n",
      require => Package[$release_package_name],
    }
  }

  if $simpreleasetype {
    file { '/etc/yum/vars/simpreleasetype':
      ensure  => file,
      content => "${simpreleasetype}\n",
      require => Package[$release_package_name],
    }
  }

  if $ee_simprelease {
    file { '/etc/yum/vars/ee_simprelease':
      ensure  => file,
      content => "${ee_simprelease}\n",
      require => Package[$release_package_name],
    }
  }

  if $ee_simpreleasetype {
    file { '/etc/yum/vars/ee_simpreleasetype':
      ensure  => file,
      content => "${ee_simpreleasetype}\n",
      require => Package[$release_package_name],
    }
  }

  if $install_type == 'enterprise' {
    package { $enterprise_packages + $community_packages:
      ensure  => installed,
      require => [Package[$release_package_name], File[$license_key_file]],
    }
  } else {
    package { $community_packages:
      ensure  => installed,
      require => Package[$release_package_name],
    }
  }
}
