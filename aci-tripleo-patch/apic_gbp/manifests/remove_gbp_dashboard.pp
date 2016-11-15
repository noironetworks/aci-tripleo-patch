class apic_gbp::remove_gbp_dashboard(

) {
    package {"remove_gbp_dashboard":
      name   => "openstack-dashboard-gbp",
      ensure => "absent",
    }
    
    package {"remove_gbp_heat":
      name   => "openstack-heat-gbp",
      ensure => "absent",
    }
}
