class apic_gbp::compute(
  $optimized_metadata = true,
) {

  #rabbit host is not set on compute nodes neutron.conf in newton, neutron-opflex-agent needs it
  #$rabbit_hosts = hiera('rabbitmq_node_ips', undef)
  #$rabbit_port  = hiera('neutron::rabbit_port', 5672)
  #$rabbit_endpoints = suffix(any2array(normalize_ip_for_uri($rabbit_hosts)), ":${rabbit_port}")
  #neutron_config {
  #  "oslo_messaging_rabbit/rabbit_hosts":  value=> $rabbit_endpoints;
  #}
  
  if $optimized_metadata {

    include ::neutron::params

    if ! defined(Service["neutron-opflex-agent"]) {
       service {'neutron-opflex-agent':
         ensure => 'running',
         enable => 'true',
       }
    }

    #class {'neutron':}

      #auth_password    => hiera('neutron::agents::metadata::auth_password'),
      #auth_tenant      => hiera('neutron::agents::metadata::auth_tenant'),
      #auth_url         => hiera('nova::network::neutron::neutron_auth_url'),
    class {'neutron::agents::metadata':
      shared_secret    => hiera('neutron::agents::metadata::shared_secret'),
      metadata_ip      => hiera('nova_metadata_vip'),
      metadata_workers => 4,
      notify           => Service['neutron-opflex-agent'],
    }
  }

}
