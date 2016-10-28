class apic_gbp::remove_gbp_dashboard(

) {
    package {"remove_gbp_dashboard":
      name   => "openstack-dashboard-gbp",
      ensure => "absent",
    }
}
