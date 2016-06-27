#
# Configure the Mech Driver for cisco nexus 1000v neutron plugin
#
# === Parameters
#
#[*n1kv_vsm_ip*]
#IP(s) of N1KV VSM(Virtual Supervisor Module)
#$n1kv_vsm_ip = 1.2.3.4, 5.6.7.8
#Defaults to empty
#
#[*n1kv_vsm_username*]
#Username of N1KV VSM(Virtual Supervisor Module)
#Defaults to empty
#
#[*n1kv_vsm_password*]
#Password of N1KV VSM(Virtual Supervisor Module)
#Defaults to empty
#
#[*default_policy_profile*]
# (Optional) Name of the policy profile to be associated with a port when no
# policy profile is specified during port creates.
# Default value:default-pp
# default_policy_profile = default-pp
#
#[*default_vlan_network_profile*]
# (Optional) Name of the VLAN network profile to be associated with a network.
# Default value:default-vlan-np
# default_vlan_network_profile = default-vlan-np
#
#[*default_vxlan_network_profile*]
# (Optional) Name of the VXLAN network profile to be associated with a network.
# Default value:default-vxlan-np
# default_vxlan_network_profile = default-vxlan-np
#
#[*poll_duration*]
# (Optional) Time in seconds for which the plugin polls the VSM for updates in
# policy profiles.
# Default value: 60
# poll_duration = 60
#
#[*http_pool_size*]
# (Optional) Number of threads to use to make HTTP requests to the VSM.
# Default value: 4
# http_pool_size = 4
#
#[*http_timeout*]
# (Optional) Timeout duration in seconds for the http request
# Default value: 15
# http_timeout = 15
#
#[*sync_interval*]
# (Optional) Time duration in seconds between consecutive neutron-VSM syncs
# Default value: 300, the time between two consecutive syncs is 300 seconds.
# sync_interval = 300
#
#[*max_vsm_retries*]
# (Optional) Maximum number of retry attempts for VSM REST API.
# Default value: 2, each HTTP request to VSM will be retried twice on
# failures.
# max_vsm_retries = 2
#
#[*restrict_policy_profiles*]
# (Optional) Specify whether tenants are restricted from accessing all the
# policy profiles.
# Default value: False, indicating all tenants can access all policy profiles.
# restrict_policy_profiles = False
#
#[*enable_vif_type_n1kv*]
# (Optional) If set to True, the VIF type for portbindings is set to N1KV.
# Otherwise the VIF type is set to OVS.
# Default value: False, indicating that the VIF type will be set to OVS.
# enable_vif_type_n1kv = False
#
class neutron::plugins::apic_gbp (
  $apic_domain_name,
  $node_role,
  $vni_ranges               = '100:1000',
  $apic_hosts               = '192.168.0.1',
  $apic_username            = 'admin',
  $apic_password            = 'password',
  $apic_entity_profile      = 'openstack_aep',
  $apic_provision_infra     = false,
  $apic_provision_hostlinks = false,
  $use_lldp_discovery       = true,
  $package_ensure           = 'present',
  $sync_db                  = false,
) {

  include ::neutron::params
  $neutron_service_name = $::neutron::params::server_service

  Neutron_config<||>     ~> Service<| title == 'neutron-server' |>
  Neutron_plugin_ml2<||> ~> Service<| title == 'neutron-server' |>

  package { 'cisco_apic_ml2_package':
    ensure => $package_ensure,
    name   => $::neutron::params::cisco_apic_ml2_package,
  }

  package { 'openstack-neutron-gbp':
    ensure => $package_ensure,
  }

  if $node_role == "controller" {
     $ns_ensure = 'running'
     $ns_enabled = true
  } else {
     $ns_ensure = 'stopped'
     $ns_enabled = false
  }
  if ! defined(Service["neutron-server"]) { 
     service { "neutron-server":
       name       => $neutron_service_name,
       ensure     => $ns_ensure,
       enable     => $ns_enabled,
       hasstatus  => true,
       hasrestart => true,
     }
  }

  if $use_lldp_discovery {
    $lldp_ensure = 'running'
    $lldp_enabled = true
    $host_agent_ensure = 'running'
    $host_agent_enabled = true
    $svc_agent_ensure = 'running'
    $svc_agent_enabled = true
  } else {
    $lldp_ensure = 'stopped'
    $lldp_enabled = false
    $host_agent_ensure = 'stopped'
    $host_agent_enabled = false
    $svc_agent_ensure = 'stopped'
    $svc_agent_enabled = false
  }

  service { 'lldpd':
    ensure      => $lldp_ensure,
    enable      => $lldp_enabled,
    hasstatus   => true,
    hasrestart  => true,
  }

  service { 'neutron-cisco-apic-host-agent':
    ensure      => $host_agent_ensure,
    enable      => $host_agent_enabled,
    hasstatus   => true,
    hasrestart  => true,
    require     => Package['cisco_apic_ml2_package'],
  }

  if $node_role == 'controller' {
     if $sync_db {
       exec { 'apic-ml2-db-sync':
         command     => '/bin/apic-ml2-db-manage --config-file /etc/neutron/neutron.conf upgrade head',
         logoutput   => on_failure,
         notify      => Service["neutron-server"],
         require     => Package['cisco_apic_ml2_package'],
       }
       exec { 'gbp-db-sync':
         command     => '/bin/gbp-db-manage --config-file /etc/neutron/neutron.conf upgrade head',
         logoutput   => on_failure,
         notify      => Service["neutron-server"],
         require     => Package['openstack-neutron-gbp'],
       }
     }
    
     service { 'neutron-cisco-apic-service-agent':
       ensure      => $svc_agent_ensure,
       enable      => $svc_agent_enabled,
       hasstatus   => true,
       hasrestart  => true,
       require     => Package['cisco_apic_ml2_package'],
     }
  }

  neutron_config {
    'DEFAULT/service_plugins':                     value => 'group_policy,apic_gbp_l3';
  }

  neutron_plugin_ml2 {
    'ml2/mechanism_drivers':                        value => 'apic_gbp';
    'ml2/tenant_network_types':                     value => 'opflex';
    'ml2/type_drivers':                             value => 'opflex,vlan,vxlan';
    'ml2_cisco_apic/apic_domain_name':              value => $apic_domain_name;
    'ml2_cisco_apic/vni_ranges':                    value => $vni_ranges;
    'ml2_cisco_apic/apic_hosts':                    value => $apic_hosts;
    'ml2_cisco_apic/apic_username':                 value => $apic_username;
    'ml2_cisco_apic/apic_password':                 value => $apic_password;
    'ml2_cisco_apic/apic_entity_profile':           value => $apic_entity_profile;
    'ml2_cisco_apic/apic_provision_infra':          value => $apic_provision_infra;
    'ml2_cisco_apic/apic_provision_hostlinks':      value => $apic_provision_hostlinks;
    'group_policy/policy_drivers':                  value => 'implicit_policy,apic';
    'group_policy_implicit_policy/default_ip_pool': value => '192.168.0.0/16';
  }
}

