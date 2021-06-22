# @summary Enable ssh keepalives to avoid timeouts
class simp_ee::keepalive {
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
