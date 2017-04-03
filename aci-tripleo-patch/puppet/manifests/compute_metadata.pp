$ctrlrs = hiera('controller_node_names', '_not_there')

if $ctrlrs != "_not_there" {
if $hostname in $ctrlrs {
   $role = 'controller'
   $sync_db = true
} else {
   $role = 'compute'
   $sync_db = false
}
   
include ::neutron::params

if $role == "compute" {
  #rabbit host is not set on compute nodes neutron.conf in newton, neutron-opflex-agent needs it
  #cannot set in extraconfig due to duplicate declaration
  #$rabbit_hosts = hiera('rabbitmq_node_ips', undef)
  #$rabbit_port  = hiera('neutron::rabbit_port', 5672)
  #$rabbit_endpoints = suffix(any2array(normalize_ip_for_uri($rabbit_hosts)), ":${rabbit_port}")
  #neutron_config {
  #  "oslo_messaging_rabbit/rabbit_hosts":  value=> $rabbit_endpoints;
  #}

  #service { 'neutron-opflex-agent':
  #  ensure => 'started',
  #}

  service { 'neutron-ovs-agent-service':
    ensure  => 'stopped',
    name    => $::neutron::params::ovs_agent_service,
    enable  => false,
  }

  class {'apic_gbp::compute':}
}
}

