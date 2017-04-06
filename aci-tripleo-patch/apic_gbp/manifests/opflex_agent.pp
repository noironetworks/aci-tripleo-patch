class apic_gbp::opflex_agent(
  $opflex_peer_ip = '10.0.0.30',
  $opflex_remote_ip = '10.0.0.32',
  $opflex_ovs_bridge = 'br-int',
  $opflex_apic_domain_name = '',
  $opflex_uplink_iface = '',
  $opflex_uplink_vlan = '4093',
  $opflex_encap_mode = 'vxlan',
  $opflex_log_level = 'debug2',
  $opflex_peer_port = '8009',
  $opflex_ssl_mode = 'enabled',
  $opflex_endpoint_dir = '/var/lib/opflex-agent-ovs/endpoints',
  $opflex_encap_iface = 'br-int_vxlan0',
  $opflex_remote_port = '8472',
  $opflex_virtual_router = 'true',
  $opflex_router_advertisement = 'false',
  $opflex_virtual_router_mac = '00:22:bd:f8:19:ff',
  $opflex_virtual_dhcp_enabled = 'true',
  $opflex_virtual_dhcp_mac = '00:22:bd:f8:19:ff',
  $opflex_cache_dir = '/var/lib/opflex-agent-ovs/ids',
  $opflex_target_bridge_to_patch = '',
) {

   $real_opflex_uplink_iface = "vlan${opflex_uplink_vlan}"

   define setup_dhclient_file($real_opflex_uplink_iface) {
     #$searchstr = "macaddress_${real_opflex_uplink_iface}"
     #$macaddr = inline_template("<%= scope.lookupvar(@searchstr) %>")
     #$macaddr = generate("/bin/facter macaddress_$real_opflex_uplink_iface")
     #$macaddr = generate("/bin/cat", "/sys/class/net/$real_opflex_uplink_iface/address")
  
     if($::osfamily == 'Redhat') {
       $cmdstr = "/bin/bash -c '_xyz=`/bin/cat /sys/class/net/${real_opflex_uplink_iface}/address`; printf \"send dhcp-client-identifier 01:%s;\" \$_xyz > /etc/dhcp/dhclient-${real_opflex_uplink_iface}.conf' "

       exec {'dhclient-file':
         command => $cmdstr,
       }

     } elsif($::osfamily == 'Debian') {
     }
   }
   define setup_ovs_patch_port($source_bridge, $target_bridge, $br_dependency) {
     $patch_port_from = "${source_bridge}_to_${target_bridge}"
     $patch_port_to = "${target_bridge}_to_${source_bridge}"
     file { "$patch_port_from":
       path    => "/etc/sysconfig/network-scripts/ifcfg-$patch_port_from",
       mode    => '0644',
       content => template('apic_gbp/ovs-patch-intf.erb'),
     }
     exec { "bringup_intf_${source_bridge}":
       command => "/usr/sbin/ifup $patch_port_from",
       require => [File["$patch_port_from"], Vs_bridge[$br_dependency]]
     }
   }

   package {'neutron-opflex-agent':
      ensure => installed,
   }

   if ! defined(Service["neutron-opflex-agent"]) {
     service {'neutron-opflex-agent':
        ensure => 'running',
        enable => 'true',
        #require => [Package['neutron-opflex-agent'], Service['neutron-openvswitch-agent']],
        require => [Package['neutron-opflex-agent']];
     }
   }
   
   if ($opflex_encap_mode == 'vxlan') {
     file {'agent-conf':
       path => '/etc/opflex-agent-ovs/conf.d/opflex-agent-ovs.conf',
       mode => '0644',
       content => template('apic_gbp/opflex-agent-ovs.conf.erb'),
       require => Package['agent-ovs'],
       notify => Service['agent-ovs'],
     }
   }
   elsif ($opflex_encap_mode == 'vlan') {
     if $opflex_target_bridge_to_patch != '' {
       $v_opflex_encap_iface = "${opflex_ovs_bridge}_to_${opflex_target_bridge_to_patch}"
       setup_ovs_patch_port{ 'source':
         source_bridge => $opflex_ovs_bridge,
         target_bridge => $opflex_target_bridge_to_patch,
         br_dependency => $opflex_ovs_bridge,
       }
       setup_ovs_patch_port{ 'target':
         source_bridge => $opflex_target_bridge_to_patch,
         target_bridge => $opflex_ovs_bridge,
         br_dependency => $opflex_ovs_bridge,
       }
       file {'agent-conf':
         path => '/etc/opflex-agent-ovs/conf.d/opflex-agent-ovs.conf',
         mode => '0644',
         content => template('apic_gbp/opflex-agent-ovs-vlan.conf.erb'),
         require => Package['agent-ovs'],
         notify => Service['agent-ovs'],
       }
     } else {
       $v_opflex_encap_iface = $opflex_uplink_iface
       file {'agent-conf':
         path => '/etc/opflex-agent-ovs/conf.d/opflex-agent-ovs.conf',
         mode => '0644',
         content => template('apic_gbp/opflex-agent-ovs-vlan.conf.erb'),
         require => Package['agent-ovs'],
         notify => Service['agent-ovs'],
       }
     }
   }


   $netconfig_yaml = "/tmp/opflex_netconfig_yaml"
   file {'opflex_osnetconfig_yaml':
     path  => $netconfig_yaml,
     mode  => '0644',
     content  => template('apic_gbp/osnetconfig.yaml.erb')
   }
   exec {'osnetconfig_fail':
     command  => "/bin/os-net-config -v -c $netconfig_yaml",
     returns  => [0,1],
     require  => File['opflex_osnetconfig_yaml'],
   }
   
   $intf_file = "/etc/sysconfig/network-scripts/ifcfg-$real_opflex_uplink_iface"
   exec {'disable_peerdns':
     command => "/bin/echo 'PEERDNS=no' >> $intf_file",
     require => Exec['osnetconfig_fail'],
   }

   setup_dhclient_file {'dummy':
     real_opflex_uplink_iface => $real_opflex_uplink_iface,
     require => Exec['osnetconfig_fail', 'disable_peerdns'],
   }

   exec {'toggle_iface':
     command  => "/sbin/ifdown $real_opflex_uplink_iface; sleep 15; /sbin/ifup $real_opflex_uplink_iface",
     require  => Setup_dhclient_file['dummy'], 
   }

   package {'agent-ovs':
      ensure => installed,
      require => Exec['toggle_iface'],
   }

   service {'agent-ovs':
     ensure => running,
     enable => true,
     require => [File['agent-conf'], Service['neutron-opflex-agent'], Exec['toggle_iface']],
   }

   exec {'fix_bridge_openflow_version':
      command => "/usr/bin/ovs-vsctl set bridge $opflex_ovs_bridge protocols=[]",
   }

   exec {'fix_iptables':
      command => "/usr/sbin/iptables -I INPUT -p udp -m multiport --dports 8472 -m comment --comment \"vxlan\" -m state --state NEW -j ACCEPT",
   }

   vs_bridge {$opflex_ovs_bridge:
     ensure => present,
     external_ids => "bridge-id=$opflex_ovs_bridge",
   }

   if ($opflex_encap_mode == 'vxlan') {
      exec {'add_vxlan_port':
         command => "/usr/bin/ovs-vsctl add-port $opflex_ovs_bridge $opflex_encap_iface -- set Interface $opflex_encap_iface type=vxlan options:remote_ip=flow options:key=flow options:dst_port=8472",
         unless => "/usr/bin/ovs-vsctl show | /bin/grep $opflex_encap_iface ",
         returns => [0,1,2],
         require => [File['agent-conf'], Vs_bridge[$opflex_ovs_bridge]],
      }
   }

}
