class neutron::plugins::ml2::cisco::apic_ml2 (
  $apic_system_id,
  $node_role,
  $vni_ranges               = '100:1000',
  $apic_hosts               = '192.168.0.1',
  $apic_username            = 'admin',
  $apic_password            = 'password',
  $encap_mode               = 'vxlan',
  $apic_entity_profile      = 'openstack_aep',
  $apic_provision_infra     = false,
  $apic_provision_hostlinks = false,
  $use_lldp_discovery       = true,
  $package_ensure           = 'present',
  $sync_db                  = false,
  $apic_l3out              = '',
) {

  include ::neutron::params
  $neutron_service_name = $::neutron::params::server_service

  #Neutron_config<||>     ~> Service<| title == 'neutron-server' |>
  #Neutron_plugin_ml2<||> ~> Service<| title == 'neutron-server' |>

  package { 'cisco_apic_ml2_package':
    ensure => $package_ensure,
    name   => $::neutron::params::cisco_apic_ml2_package,
  }

  #if $node_role == "controller" {
  #   $ns_ensure = 'running'
  #   $ns_enabled = true
  #} else {
  #   $ns_ensure = 'stopped'
  #   $ns_enabled = false
  #}
  #if ! defined(Service["neutron-server"]) { 
  #   service { "neutron-server":
  #     name       => $neutron_service_name,
  #     ensure     => $ns_ensure,
  #     enable     => $ns_enabled,
  #     hasstatus  => true,
  #     hasrestart => true,
  #     start      => '/usr/bin/systemctl start neutron-server && /usr/bin/sleep 5',
  #   }
  #}

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
         #notify      => Service["neutron-server"],
         require     => Package['cisco_apic_ml2_package'],
         #refreshonly => true,
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
    'DEFAULT/service_plugins':                     value => 'cisco_apic_l3';
    'DEFAULT/apic_system_id':                      value => $apic_system_id;
  }

  neutron_dhcp_agent_config {
    'DEFAULT/enable_isolated_metadata':             value => True;
  }

  neutron_plugin_ml2 {
    'ml2/mechanism_drivers':                       value => 'cisco_apic_ml2';
    'ml2/tenant_network_types':                    value => 'opflex';
    'ml2/type_drivers':                            value => 'opflex';
    'ml2_cisco_apic/vni_ranges':                   value => $vni_ranges;
    'ml2_cisco_apic/apic_hosts':                   value => $apic_hosts;
    'ml2_cisco_apic/apic_username':                value => $apic_username;
    'ml2_cisco_apic/apic_password':                value => $apic_password;
    'ml2_cisco_apic/encap_mode':                   value => $encap_mode;
    'ml2_cisco_apic/apic_entity_profile':          value => $apic_entity_profile;
    'ml2_cisco_apic/apic_provision_infra':         value => $apic_provision_infra;
    'ml2_cisco_apic/apic_provision_hostlinks':     value => $apic_provision_hostlinks;
  }

  define populate_extnet {
    $pair = split($name, ':')
    $net = $pair[0]
    $epg = $pair[1]
    neutron_plugin_ml2 {
      "apic_external_network:$net/external_epg":   value => $epg;
      "apic_external_network:$net/preexisting":   value => True;
    }
  }
  
  $earr = split($apic_l3out, ',')
  populate_extnet{$earr:;}
}

