class apic_gbp::aim_neutron_config(
  $apic_system_id,
  $node_role,
  $sync_db,
) {

  package { 'cisco_apic_ml2_package':
    ensure => $package_ensure,
    name   => 'neutron-ml2-driver-apic',
  }

  package { 'openstack-neutron-gbp':
    ensure => $package_ensure,
  }

  $use_lldp_discovery = hiera('neutron::plugins::apic_gbp::use_lldp_discovery')
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

     $keystone_auth_url = hiera('keystone::endpoint::admin_url')
     $keystone_admin_username = 'admin'
     $keystone_admin_password = hiera('keystone::roles::admin::password')
     neutron_config {
       'DEFAULT/apic_system_id':                  value => $apic_system_id;
       'DEFAULT/core_plugin':                     value => 'ml2plus';
       'DEFAULT/service_plugins':                 value => 'group_policy,servicechain,apic_aim_l3';
       'apic_aim_auth/auth_plugin':               value => 'v3password';
       'apic_aim_auth/auth_url':                  value => "$keystone_auth_url/v3";
       'apic_aim_auth/username':                  value => $keystone_admin_username;
       'apic_aim_auth/password':                  value => $keystone_admin_password;
       'apic_aim_auth/user_domain_name':          value => 'default';
       'apic_aim_auth/project_domain_name':       value => 'default';
       'apic_aim_auth/project_name':              value => 'admin';
       'group_policy/policy_drivers':             value => 'aim_mapping';
       'group_policy/extension_drivers':          value => 'aim_extension,proxy_group,apic_allowed_vm_name,apic_segmentation_label';
       'oslo_policy/policy_file':                 value => '/etc/group-based-policy/policy.d/merged-policy.json';
     }
   
     neutron_dhcp_agent_config {
       'DEFAULT/enable_isolated_metadata':        value => True;
     }

     $optimized_metadata = hiera('neutron::plugins::apic_gbp::optimized_metadata')

     neutron_plugin_ml2 {
       'ml2/type_drivers': value => "opflex,local,flat,vlan,gre,vxlan";
       'ml2/tenant_network_types': value => "opflex";
       'ml2/mechanism_drivers': value => "apic_aim";
       'ml2/extension_drivers': value => "apic_aim,port_security";
       'ml2_apic_aim/enable_optimized_metadata': value => $optimized_metadata;
     }

     #merge policy files
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
  }

}
