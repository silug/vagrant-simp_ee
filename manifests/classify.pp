# @summary Classify nodes
# @param files Hiera files to manage
# @param owner User owner of managed files and directories
# @param group Group owner of managed files and directories
# @param dirmode Permissions for managed directories
# @param filemode Permissions for managed files
class simp_ee::classify (
  Array $files = [
    '/etc/puppetlabs/code/environments/production/hiera.yaml',
    '/etc/puppetlabs/code/environments/production/data/os/RedHat.yaml',
    '/etc/puppetlabs/code/environments/production/data/os/windows.yaml',
    '/etc/puppetlabs/code/environments/production/data/role/console.yaml',
    '/etc/puppetlabs/code/environments/production/data/role/puppet.yaml',
    '/etc/puppetlabs/code/environments/production/manifests/disable_postgres_dnf_module.pp',
  ],
  String[1] $owner = 'root',
  String[1] $group = 'puppet',
  String[4] $dirmode = '0750',
  String[4] $filemode = '0640',
) {
  $dirs = $files.map |$file| { dirname($file) }.unique

  file { $dirs:
    ensure => directory,
    owner  => $owner,
    group  => $group,
    mode   => $dirmode,
  }

  $files.each |$name| {
    file { $name:
      ensure  => file,
      owner   => $owner,
      group   => $group,
      mode    => $filemode,
      content => epp("simp_ee/${$name.split('/')[-1]}.epp"),
    }
  }
}
