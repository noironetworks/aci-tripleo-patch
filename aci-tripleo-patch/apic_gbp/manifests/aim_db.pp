class apic_gbp::aim_db(
  $node_role,
  $sync_db,
) {

 if $node_role == "controller" {
    if $sync_db {
         exec {'aim-db-migrate':
            command => "/usr/bin/aimctl db-migration upgrade head",
          }
        
          exec {'aim-config-update':
            command => "/usr/bin/aimctl config update",
            require => Exec['aim-db-migrate'],
          }
         
          exec {'aim-create-infra':
            command => "/usr/bin/aimctl infra create",
            require => Exec['aim-config-update'],
          }
        
          exec {'aim-load-domains':
            command => "/usr/bin/aimctl manager load-domains --enforce",
            require => Exec['aim-config-update'],
          }
    }
 }
}
