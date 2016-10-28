
$ctrlrs = hiera('controller_node_names', '_not_there')

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
  
  $opflex_mechanism = hiera('cisco::apic::opflex::neutron_mechanism')
  
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

     if $pacemaker_master {
       class { 'apic_gbp::service_restart': 
         require => Class['neutron::plugins::apic_gbp', 'apic_gbp::opflex_agent'],
       }
     }

     class { 'apic_gbp::opflex_agent': 
       require => Class['neutron::plugins::apic_gbp'],
     }

     class {'apic_gbp::opflex_restart':
       require => Class['apic_gbp::opflex_agent'],
     }
  
  
  }

}
