class apic_gbp::aim_config(
  $apic_system_id,
) {

  $neutron_db_user     = hiera('neutron::db::mysql::user')
  $neutron_db_password = hiera('neutron::db::mysql::password')
  $neutron_db_host     = hiera('neutron::db::mysql::host')
  $neutron_db_name     = hiera('neutron::db::mysql::dbname')
  $neutron_sql_connection  = "mysql+pymysql://${neutron_db_user}:${neutron_db_password}@${neutron_db_host}/${neutron_db_name}"

  $rabbit_hosts = hiera('neutron::rabbit_hosts')
  $rabbit_host =  hiera('neutron::rabbit_host', nil)
  $rabbit_port =  hiera('neutron::rabbit_port')
  $rabbit_user =  hiera('neutron::rabbit_user')
  $rabbit_password = hiera('neutron::rabbit_password')

  $apic_hosts = hiera('neutron::plugins::ml2::cisco::apic_ml2::apic_hosts')
  $apic_username = hiera('neutron::plugins::ml2::cisco::apic_ml2::apic_username')
  $apic_password = hiera('neutron::plugins::ml2::cisco::apic_ml2::apic_password')

  $vm_domain_name = $apic_system_id
  $encap_mode = hiera('neutron::plugins::apic_gbp::encap_mode')
  $aep = hiera('neutron::plugins::apic_gbp::apic_entity_profile')
  $apic_vpc_pairs = hiera('neutron::plugins::apic_gbp::apic_vpcpairs', '')
 
  $apic_l3out = hiera('neutron::plugins::apic_gbp::apic_l3out')

  if $rabbit_hosts {
     aim_config { 
        'oslo_messaging_rabbit/rabbit_hosts':     value  => join($rabbit_hosts, ',');
      }
  } else  {
     aim_config { 
        'oslo_messaging_rabbit/rabbit_host':      value => $rabbit_host;
        'oslo_messaging_rabbit/rabbit_port':      value => $rabbit_port;
        'oslo_messaging_rabbit/rabbit_hosts':     value => "${rabbit_host}:${rabbit_port}";
     }
  }

  aim_config {
     'DEFAULT/debug':                             value => True;
     'database/connection':                       value => $neutron_sql_connection;
     'oslo_messaging_rabbit/rabbit_userid':       value => $rabbit_user;
     'oslo_messaging_rabbit/rabbit_password':     value => $rabbit_password;
     'apic/apic_hosts':                           value => $apic_hosts;
     'apic/apic_username':                        value => $apic_username;
     'apic/apic_password':                        value => $apic_password;
     'apic/apic_use_ssl':                         value => True;
     'apic/verify_ssl_certificate':               value => False;
     'apic/scope_names':                          value => False;
  }  
     #'apic_vmdom:ostack/#dummy':                        value => '';

  aimctl_config {
     'DEFAULT/apic_system_id':                    value => $apic_system_id;
     "apic_vmdom:$vm_domain_name/encap_mode":     value => $encap_mode;
     'apic/apic_entity_profile':                  value => $aep;
     'apic/scope_infra':                          value => False;
     'apic/apic_vpc_pairs':                       value => $apic_vpc_pairs;
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
       notice($nat)
       neutron_plugin_ml2 {
         "apic_external_network:$net/host_pool_cidr": value => $snat;
       }
    }
  }
  
  $earr = split($apic_l3out, ',')
  #populate_extnet{$earr:;}

#### future 
#   define add_switch_conn_to_aimctl_conf($sa) {
#       $sid = keys($sa)
#       a_s_c_t_n_c_1{$sid: swarr => $sa}
#   }
#
#   define a_s_c_t_n_c_1($swarr) {
#       $plist = $swarr[$name]
#       $local_names = regsubst($plist, '$', "-$name")
#       a_s_c_t_n_c_2 {$local_names: sid => $name}
#   }
#
#   define a_s_c_t_n_c_2($sid) {
#       $orig_name = regsubst($name, '-[0-9]+$', '')
#       $arr = split($orig_name, ':')
#       $host = $arr[0]
#       $swport = $arr[1]
#       aimctl_config {
#          "apic_switch:$sid/$host": value => $swport;
#       }
#   }
#
#   $use_lldp = hiera('neutron::plugins::apic_gbp::use_lldp_discovery')
#   $swarr = parsejson(hiera('CONFIG_APIC_CONN_JSON'))
#
#   if $use_lldp {
#   } else {
#       add_switch_conn_to_aimctl_conf{'xyz': sa => $swarr}
#   }
#
#   $extnet_arr = parsejson(hiera('CONFIG_APIC_EXTNET_JSON'))
#
#   define add_extnet_to_aimctl_conf($na) {
#      $extnets = keys($na)
#      add_extnet_def { $extnets: netarr => $na}
#   }
#   define add_extnet_def($netarr) {
#     aimctl_config {
#        "apic_external_network:$name/switch": value => $netarr[$name]['switch'];
#        "apic_external_network:$name/port": value => $netarr[$name]['port'];
#        "apic_external_network:$name/encap": value => $netarr[$name]['encap'];
#        "apic_external_network:$name/cidr_exposed": value => $netarr[$name]['cidr_exposed'];
#        "apic_external_network:$name/gateway_ip": value => $netarr[$name]['gateway_ip'];
#        "apic_external_network:$name/router_id": value => $netarr[$name]['router_id'];
#     }
#   }

#   add_extnet_to_aimctl_conf{'abc': na => $extnet_arr}

}
