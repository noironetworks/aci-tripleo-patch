class apic_gbp::aim_service(
  $node_role,
) {

 if $node_role == "controller" {
    service {'aim-aid':
        ensure => running,
        enable => true,
    }
  
    service {'aim-event-service-polling':
        ensure => running,
        enable => true,
    }
  
    service {'aim-event-service-rpc':
        ensure => running,
        enable => true,
    }
 }

}
