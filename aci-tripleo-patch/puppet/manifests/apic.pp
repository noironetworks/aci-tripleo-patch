#file {'/tmp/kbk1':
#  content => "klk",
#}

$ctrlrs = hiera('controller_node_names')
if $hostname in $ctrlrs {
   $role = 'controller'
   $sync_db = true
} else {
   $role = 'compute'
   $sync_db = false
}
   
include ::neutron::params

$opflex_mechanism = hiera('cisco::apic::opflex::neutron_mechanism')

if $role == "compute" {
  service { 'neutron-ovs-agent-service':
    ensure  => 'stopped',
    name    => $::neutron::params::ovs_agent_service,
    enable  => false,
  }
}

if $opflex_mechanism == "cisco_apic_ml2" {
   class { 'neutron::plugins::ml2::cisco::apic_ml2':
     apic_domain_name => hiera('neutron::plugins::ml2::cisco::apic_ml2::apic_domain_name'),
     node_role => $role,
     sync_db => $sync_db,
   } ->
   class { 'apic_gbp::opflex_agent': }

   if $role == "controller" {
     package {"remove_gbp_dashboard":
       name   => "openstack-dashboard-gbp",
       ensure => "absent",
       notify => Service['httpd'],
     }
  
     service {"httpd":
       ensure => "running",
       enable => true,
     }
   }
  
}

if $opflex_mechanism == "apic_gbp" {
   class { 'neutron::plugins::apic_gbp':
     apic_domain_name => hiera('neutron::plugins::ml2::cisco::apic_ml2::apic_domain_name'),
     node_role => $role,
     sync_db => $sync_db,
   } ->
   class { 'apic_gbp::opflex_agent': }
}
