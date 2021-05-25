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
  String           $enterprise_release   = 'https://download.simp-project.com/simp-release-enterprise.rpm',
  Optional[String] $license_key          = undef,
  String           $release_package      = $license_key ? {
    undef   => $community_release,
    default => $enterprise_release,
  },
  String           $release_package_name = $release_package.split('/')[-1].regsubst(/(?:(?:-\d[^-]*){2})?\.rpm$/, ''),
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
  String           $license_key_file     = '/etc/simp/license.key',
) {
  package { $release_package_name:
    ensure   => installed,
    source   => $release_package,
    provider => rpm,
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
