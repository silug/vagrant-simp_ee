# @summary Configure for simp config
#
# @example
#   include simp_ee::config
class simp_ee::config {
  file { '/root/simp_config.yaml':
    ensure  => file,
    content => epp('simp_ee/simp_config.yaml.epp'),
  }
  ~> exec { 'simp config -A /root/simp_config.yaml':
    path        => '/bin:/usr/bin',
    environment => [
      'USER=root',
      'HOME=/root',
    ],
    refreshonly => true,
  }
  -> file { '/etc/puppetlabs/code/environments/production/data/common.yaml':
    ensure  => file,
    owner   => 'root',
    group   => 'puppet',
    mode    => '0640',
    content => epp('simp_ee/common.yaml.epp', {
      user => $facts["ssh_user"],
    }),
  }

  file { '/etc/puppetlabs/puppet/autosign.conf':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => "*.${facts['domain']}\n",
  }
}
