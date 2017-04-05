class neutron::plugins::apic_gbp (
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
  $apic_l3out               = '',
  $apic_vpcpairs            = '',
  $optimized_dhcp           = 'true',
  $optimized_metadata       = 'true',
) {

  include ::neutron::params
  $neutron_service_name = $::neutron::params::server_service

  #Neutron_config<||>     ~> Service<| title == 'neutron-server' |>
  #Neutron_plugin_ml2<||> ~> Service<| title == 'neutron-server' |>
  #Neutron_dhcp_agent_config<||> ~> Service['neutron-dhcp-service']

  package { 'cisco_apic_ml2_package':
    ensure => $package_ensure,
    name   => $::neutron::params::cisco_apic_ml2_package,
  }

  package { 'openstack-neutron-gbp':
    ensure => $package_ensure,
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
 
  #if ! defined(Service["neutron-dhcp-service"]) {
  #   service { 'neutron-dhcp-service':
  #     ensure  => $ns_ensure,
  #     name    => $::neutron::params::dhcp_agent_service,
  #     enable  => $ns_enabled,
  #     hasstatus  => true,
  #     hasrestart => true,
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
       }
       exec { 'gbp-db-sync':
         command     => '/bin/gbp-db-manage --config-file /etc/neutron/neutron.conf upgrade head',
         logoutput   => on_failure,
         #notify      => Service["neutron-server"],
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

  $neutron_hash = loadjson('/etc/neutron/policy.json')
  $gbp_hash = loadjson('/etc/group-based-policy/policy.d/policy.json')
  $merged_hash = deep_merge($neutron_hash, $gbp_hash)

  $merged_json = inline_template("<%= @merged_hash.to_json %>")

  file {'/etc/group-based-policy/policy.d/merged-policy.json.ugly':
     content => $merged_json,
  }

  exec {'prettyprint':
     command => '/bin/cat /etc/group-based-policy/policy.d/merged-policy.json.ugly | python -m json.tool > /etc/group-based-policy/policy.d/merged-policy.json',
     require => File['/etc/group-based-policy/policy.d/merged-policy.json.ugly'],
  }

  neutron_config {
    'DEFAULT/apic_system_id':                  value => $apic_system_id;
    'DEFAULT/service_plugins':                 value => 'group_policy,servicechain,apic_gbp_l3';
    'oslo_policy/policy_file':                 value => '/etc/group-based-policy/policy.d/merged-policy.json';
  }
  
  neutron_dhcp_agent_config {
    'DEFAULT/enable_isolated_metadata':             value => True;
  }

  neutron_plugin_ml2 {
    'ml2/mechanism_drivers':                        value => 'apic_gbp';
    'ml2/tenant_network_types':                     value => 'opflex';
    'ml2/type_drivers':                             value => 'opflex,vlan,vxlan';
    'ml2_cisco_apic/vni_ranges':                    value => $vni_ranges;
    'ml2_cisco_apic/apic_hosts':                    value => $apic_hosts;
    'ml2_cisco_apic/apic_username':                 value => $apic_username;
    'ml2_cisco_apic/apic_password':                 value => $apic_password;
    'ml2_cisco_apic/encap_mode':                    value => $encap_mode;
    'ml2_cisco_apic/apic_entity_profile':           value => $apic_entity_profile;
    'ml2_cisco_apic/apic_provision_infra':          value => $apic_provision_infra;
    'ml2_cisco_apic/apic_provision_hostlinks':      value => $apic_provision_hostlinks;
    'ml2_cisco_apic/enable_optimized_dhcp':         value => $optimized_dhcp;
    'ml2_cisco_apic/enable_optimized_metadata':     value => $optimized_metadata;
    'group_policy/policy_drivers':                  value => 'implicit_policy,chain_mapping,apic';
    'group_policy_implicit_policy/default_ip_pool': value => '192.168.0.0/16';
  }

  if $apic_vpcpairs != "" {
     neutron_plugin_ml2 {
       'ml2_cisco_apic/apic_vpc_pairs':   value => $apic_vpcpairs;
     }
  }

  define populate_extnet {
    $pair = split($name, ':')
    $net = $pair[0]
    $epg = $pair[1]
    $snat = $pair[2]
    neutron_plugin_ml2 {
      "apic_external_network:$net/external_epg":   value => $epg;
      "apic_external_network:$net/preexisting":   value => True;
    }
    if $snat {
       neutron_plugin_ml2 {
         "apic_external_network:$net/host_pool_cidr": value => $snat;
       }
    }
  }

  $earr = split($apic_l3out, ',')
  populate_extnet{$earr:;}
}

