class apic_gbp::compute(
  $optimized_metadata = true,
) {
  
  if $optimized_metadata {

    include ::neutron::params

    if ! defined(Service["neutron-opflex-agent"]) {
       service {'neutron-opflex-agent':
         ensure => 'running',
         enable => 'true',
       }
    }

    class {'neutron':}

    class {'neutron::agents::metadata':
      auth_password    => hiera('neutron::agents::metadata::auth_password'),
      shared_secret    => hiera('neutron_metadata_proxy_shared_secret'),
      auth_tenant      => hiera('neutron::agents::metadata::auth_tenant'),
      auth_url         => hiera('nova::network::neutron::neutron_admin_auth_url'),
      metadata_ip      => hiera('neutron_host'),
      metadata_workers => 4,
      notify           => Service['neutron-opflex-agent'],
    }
  }

}
