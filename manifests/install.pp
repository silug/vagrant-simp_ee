# @summary Installs SIMP
#
# @param community_release URL of the SIMP Community Edition release package
# @param enterprise_release URL of the Sicura Enterprise Edition release package
# @param console_release URL of the Sicura Console release package
# @param license_key License key for Sicura Enterprise Edition
# @param release_package Release package to use during installation, defaults to appropriate value based on value of license_key
# @param release_package_name Package name of the specified community or enterprise release package
# @param console_release_package_name Package name of the Console release package
# @param install_type Type of installation to perform (community or enterprise), defaults to appropriate value based on release package name
# @param community_packages List of packages to install during a Community installation
# @param enterprise_packages List of packages to install during an Enterprise installation
# @param license_key_file Full path to a valid Sicura Enteprise license file
# @param simprelease Value to inject into the simprelease YUM var
# @param simpreleasetype Value to inject into the simpreleasetype YUM var
# @param ee_simprelease Value to inject into the ee_simprelease YUM var
# @param ee_simpreleasetype Value to inject into the ee_simpreleasetype YUM var
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
    'sicura-enterprise',
    'puppetserver',
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
    file { '/etc/yum/vars/sicurarelease':
      ensure  => file,
      content => "${ee_simprelease}\n",
      require => Package[$release_package_name],
    }
  }

  if $ee_simpreleasetype == 'development' {
    ini_setting { 'ee releasetype':
      ensure  => present,
      path    => '/etc/yum.repos.d/sicura-enterprise.repo',
      section => 'sicura-enterprise',
      setting => 'baseurl',
      value   => "https://enterprise-download.simp-project.com/sicura/yum/${ee_simpreleasetype}/\$sicurarelease/el/\$releasever/\$basearch",
    }

    file { 'simp.version':
      ensure  => file,
      path    => '/etc/simp/simp.version',
      content => "${ee_simprelease.split('-')[0]}",
      require => Package[$enterprise_packages],
    }
  }

  if $install_type == 'enterprise' {
    package { $enterprise_packages:
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
