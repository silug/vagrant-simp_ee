# @summary Run "simp bootstrap"
#
# @example
#   include simp_ee::bootstrap
class simp_ee::bootstrap {
  exec { 'rm -f /root/.simp/simp_bootstrap_start_lock':
    path        => '/bin:/usr/bin',
    refreshonly => true,
  }
  -> exec { 'simp bootstrap -r -w 10':
    path        => '/bin:/usr/bin',
    environment => [
      'USER=root',
      'HOME=/root',
    ],
    refreshonly => true,
    timeout     => 0,
    # tries       => 2,
    logoutput   => true,
  }
  -> exec { 'puppet agent -t':
    path        => '/opt/puppetlabs/bin:/bin:/usr/bin',
    environment => [
      'USER=root',
      'HOME=/root',
    ],
    refreshonly => true,
    timeout     => 0,
    # tries       => 2,
    logoutput   => true,
    returns     => [0, 2],
  }
}
