# @summary Unregister RHEL subscription management
# @param targets The targets to run on
plan simp_ee::rhsm_unregister (
  TargetSpec $targets,
) {
  apply_prep($targets)

  $rhel = get_targets($targets).filter |$target| {
    $target.facts['os']['name'] == 'RedHat'
  }

  unless $rhel.empty {
    run_command(
      'subscription-manager status && subscription-manager unregister || :',
      $rhel,
      'description' => 'Unregister RHEL subscription management',
    )
  }
}
