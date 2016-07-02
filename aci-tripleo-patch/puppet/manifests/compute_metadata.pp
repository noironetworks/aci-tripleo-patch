$ctrlrs = hiera('controller_node_names')
if $hostname in $ctrlrs {
   $role = 'controller'
   $sync_db = true
} else {
   $role = 'compute'
   $sync_db = false
}
   
include ::neutron::params

if $role == "compute" {

  service { 'neutron-ovs-agent-service':
    ensure  => 'stopped',
    name    => $::neutron::params::ovs_agent_service,
    enable  => false,
  }

  class {'apic_gbp::compute':}
}

