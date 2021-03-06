class openstack_integration::heat {

  include ::openstack_integration::config
  include ::openstack_integration::params

  rabbitmq_user { 'heat':
    admin    => true,
    password => 'an_even_bigger_secret',
    provider => 'rabbitmqctl',
    require  => Class['::rabbitmq'],
  }
  rabbitmq_user_permissions { 'heat@/':
    configure_permission => '.*',
    write_permission     => '.*',
    read_permission      => '.*',
    provider             => 'rabbitmqctl',
    require              => Class['::rabbitmq'],
  }
  Rabbitmq_user_permissions['heat@/'] -> Service<| tag == 'heat-service' |>

  if $::openstack_integration::config::ssl {
    openstack_integration::ssl_key { 'heat':
      require => Package['heat-common'],
    }
    $key_file = "/etc/heat/ssl/private/${::fqdn}.pem"
    $crt_file = $::openstack_integration::params::cert_path
    File[$key_file] ~> Service<| tag == 'heat-service' |>
    Exec['update-ca-certificates'] ~> Service<| tag == 'heat-service' |>
  } else {
    $key_file = undef
    $crt_file = undef
  }

  class { '::heat::keystone::authtoken':
    password            => 'a_big_secret',
    user_domain_name    => 'Default',
    project_domain_name => 'Default',
    auth_url            => $::openstack_integration::config::keystone_admin_uri,
    auth_uri            => $::openstack_integration::config::keystone_auth_uri,
    memcached_servers   => $::openstack_integration::config::memcached_servers,
  }
  class { '::heat':
    default_transport_url => os_transport_url({
      'transport' => 'rabbit',
      'host'      => $::openstack_integration::config::host,
      'port'      => $::openstack_integration::config::rabbit_port,
      'username'  => 'heat',
      'password'  => 'an_even_bigger_secret',
    }),
    rabbit_use_ssl        => $::openstack_integration::config::ssl,
    database_connection   => 'mysql+pymysql://heat:heat@127.0.0.1/heat?charset=utf8',
    debug                 => true,
  }
  class { '::heat::db::mysql':
    password => 'heat',
  }
  class { '::heat::keystone::auth':
    password                  => 'a_big_secret',
    configure_delegated_roles => true,
    public_url                => "${::openstack_integration::config::base_url}:8004/v1/%(tenant_id)s",
    internal_url              => "${::openstack_integration::config::base_url}:8004/v1/%(tenant_id)s",
    admin_url                 => "${::openstack_integration::config::base_url}:8004/v1/%(tenant_id)s",
  }
  class { '::heat::keystone::domain':
    domain_password => 'oh_my_no_secret',
  }
  class { '::heat::client': }
  class { '::heat::api':
    service_name => 'httpd',
  }
  include ::apache
  class { '::heat::wsgi::apache_api':
    bind_host => $::openstack_integration::config::host,
    ssl       => $::openstack_integration::config::ssl,
    ssl_cert  => $crt_file,
    ssl_key   => $key_file,
    workers   => 2,
  }
  class { '::heat::engine':
    auth_encryption_key           => '1234567890AZERTYUIOPMLKJHGFDSQ12',
    heat_metadata_server_url      => "${::openstack_integration::config::base_url}:8000",
    heat_waitcondition_server_url => "${::openstack_integration::config::base_url}:8000/v1/waitcondition",
    heat_watch_server_url         => "${::openstack_integration::config::base_url}:8003",
  }
  class { '::heat::api_cloudwatch':
    service_name => 'httpd',
  }
  class { '::heat::wsgi::apache_api_cloudwatch':
    bind_host => $::openstack_integration::config::host,
    ssl       => $::openstack_integration::config::ssl,
    ssl_cert  => $crt_file,
    ssl_key   => $key_file,
    workers   => 2,
  }
  class { '::heat::api_cfn':
    service_name => 'httpd',
  }
  class { '::heat::wsgi::apache_api_cfn':
    bind_host => $::openstack_integration::config::host,
    ssl       => $::openstack_integration::config::ssl,
    ssl_cert  => $crt_file,
    ssl_key   => $key_file,
    workers   => 2,
  }

}
