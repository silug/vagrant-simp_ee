# @summary Check the status of puppetserver
# @param targets The targets to run on
plan simp_ee::check_puppetserver (
  TargetSpec $targets,
) {
  $service_results = run_task(
    'service',
    $targets,
    'Check puppetserver status',
    '_catch_errors' => true,
    'action'        => 'status',
    'name'          => 'puppetserver',
  )

  if $service_results.any |$result| { $result.value['status'] =~ /ActiveState=failed/ } {
    $failed_targets = $service_results.reduce([]) |$memo, $result| {
      if $result.value['status'] =~ /ActiveState=failed/ {
        $memo + [ $result.target ]
      } else {
        $memo
      }
    }

    fail_plan("Failed to start puppetserver on ${failed_targets}")
  }

  return $service_results
}
