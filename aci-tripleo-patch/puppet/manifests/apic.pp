
$ctrlrs = hiera('controller_node_names', '_not_there')
$use_lldp_discovery = hiera('neutron::plugins::apic_gbp::use_lldp_discovery')

if $ctrlrs != "_not_there" {
  if $hostname in $ctrlrs {
     $role = 'controller'
  } else {
     $role = 'compute'
  }

  if $role == "controller" {
     $bnid = downcase(hiera('bootstrap_nodeid', '_oops'))
     if $::hostname == $bnid {
       $pacemaker_master = true
       $sync_db = true
     } else {
       $pacemaker_master = false
       $sync_db = false
     }
  }
   
  include ::neutron::params
  
  $enable_aim = hiera('cisco::apic::enable_aim')
  $opflex_mechanism = hiera('cisco::apic::opflex::neutron_mechanism')

  if $enable_aim {
     if $role == "controller" {
        class { 'apic_gbp::aim_config':
          apic_system_id => hiera('neutron::plugins::ml2::cisco::apic_ml2::apic_system_id'),
        }
   
        class { 'apic_gbp::aim_neutron_config':
          apic_system_id => hiera('neutron::plugins::ml2::cisco::apic_ml2::apic_system_id'),
          node_role => $role,
          sync_db => $sync_db,
        }
   
        class { 'apic_gbp::aim_db':
          node_role => $role,
          sync_db => $sync_db,
          require => Class['apic_gbp::aim_neutron_config', 'apic_gbp::aim_config'],
        }
   
        class { 'apic_gbp::aim_service':
          node_role => $role,
          require => Class['apic_gbp::aim_db'],
        }
   
        if $pacemaker_master {
          class { 'apic_gbp::service_restart': 
            require => Class['apic_gbp::aim_service', 'apic_gbp::opflex_agent'],
          }
        }

        class { 'apic_gbp::opflex_agent': 
          require => Class['apic_gbp::aim_service'],
        }
   
        class {'apic_gbp::opflex_restart':
          require => Class['apic_gbp::opflex_agent'],
        }
     } else {

        if $use_lldp_discovery {
           $lldp_ensure = 'running'
           $lldp_enabled = true
           $host_agent_ensure = 'running'
           $host_agent_enabled = true
        } else {
           $lldp_ensure = 'stopped'
           $lldp_enabled = false
           $host_agent_ensure = 'stopped'
           $host_agent_enabled = false
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
        }

        class { 'apic_gbp::opflex_agent': 
        }
   
        class {'apic_gbp::opflex_restart':
          require => Class['apic_gbp::opflex_agent'],
        }
    }

  } else {
    #legacy stuff here  
     if $opflex_mechanism == "cisco_apic_ml2" {
        class { 'neutron::plugins::ml2::cisco::apic_ml2':
          apic_system_id => hiera('neutron::plugins::ml2::cisco::apic_ml2::apic_system_id'),
          node_role => $role,
          sync_db => $sync_db,
        } 
        
        class { 'apic_gbp::remove_gbp_dashboard': }
   
        if $pacemaker_master {
           class { 'apic_gbp::service_restart': 
             ml2 => true,
             require => Class['neutron::plugins::ml2::cisco::apic_ml2', 'apic_gbp::remove_gbp_dashboard', 'apic_gbp::opflex_agent'],
           }
        }

        class { 'apic_gbp::opflex_agent': 
          require => Class['neutron::plugins::ml2::cisco::apic_ml2'],
        }

        class {'apic_gbp::opflex_restart':
          require => Class['apic_gbp::opflex_agent'],
        }
  
     }

     if $opflex_mechanism == "apic_gbp" {
        class { 'neutron::plugins::apic_gbp':
          apic_system_id => hiera('neutron::plugins::ml2::cisco::apic_ml2::apic_system_id'),
          node_role => $role,
          sync_db => $sync_db,
        } 
   
        class {'apic_gbp::gbp_heat': }

        if $pacemaker_master {
          class { 'apic_gbp::service_restart': 
            require => Class['neutron::plugins::apic_gbp', 'apic_gbp::opflex_agent', 'apic_gbp::gbp_heat'],
          }
        }

        class { 'apic_gbp::opflex_agent': 
          require => Class['neutron::plugins::apic_gbp'],
        }

        class {'apic_gbp::opflex_restart':
          require => Class['apic_gbp::opflex_agent'],
        }
     }
     #end legacy stuff
  }

}
