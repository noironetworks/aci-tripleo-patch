class apic_gbp::service_restart(
  $ml2 = false,
) {

      exec {'restart-neutron-server':
         command => "/usr/bin/systemctl restart  neutron-server",
      }

      exec {'restart-neutron-dhcpagent':
         command => "/usr/bin/systemctl restart neutron-dhcp-agent",
         require => Exec['restart-neutron-server'],
      }

      exec {'restart-httpd':
         command => "/usr/bin/systemctl restart httpd",
      }
      
      exec {'restart-heat-engine':
            command => "/usr/bin/systemctl restart openstack-heat-engine",
      }
      exec {'restart-heat-api':
            command => "/usr/bin/systemctl restart openstack-heat-api",
      }

      exec {'disable_openvswitch_plugin':
        command  => "/usr/bin/systemctl disable neutron-openvswitch-agent",
      }

      exec {'delete_openvswitch_plugin':
        command  => "/usr/bin/systemctl stop neutron-openvswitch-agent",
      }
}
