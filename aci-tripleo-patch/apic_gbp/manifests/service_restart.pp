class apic_gbp::service_restart(
  $ml2 = false,
) {

      exec {'restart-neutron-server':
         command => "/sbin/pcs resource restart  neutron-server-clone --wait=10m;/bin/sleep 30",
      }
      exec {'restart-neutron-dhcpagent':
         command => "/sbin/pcs resource restart neutron-dhcp-agent-clone --wait=2m",
         require => Exec['restart-neutron-server'],
      }
      if $ml2 {
         exec {'restart-httpd':
            command => "/sbin/pcs resource restart httpd-clone --wait=2m",
         }
      }
      
      exec {'disable_openvswitch_plugin':
        command  => "/usr/sbin/pcs resource disable neutron-openvswitch-agent-clone",
        onlyif => "/usr/sbin/pcs resource show | grep -q neutron-openvswitch-agent-clone",
      }
      exec {'delete_openvswitch_plugin':
        command  => "/usr/sbin/pcs resource delete neutron-openvswitch-agent-clone",
        onlyif => "/usr/sbin/pcs resource show | grep -q neutron-openvswitch-agent-clone",
        require => Exec['disable_openvswitch_plugin'],
      }
}
