class apic_gbp::opflex_restart(
) {

      exec {'restart-agent-ovs':
         command => "/sbin/service agent-ovs restart";
      }
      exec {'restart-neutron-opflex':
         command => "/sbin/service neutron-opflex-agent restart";
      }
}
