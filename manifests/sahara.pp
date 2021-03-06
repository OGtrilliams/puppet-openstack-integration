class openstack_integration::sahara {

  include ::openstack_integration::config
  include ::openstack_integration::params

  rabbitmq_user { 'sahara':
    admin    => true,
    password => 'an_even_bigger_secret',
    provider => 'rabbitmqctl',
    require  => Class['::rabbitmq'],
  }
  rabbitmq_user_permissions { 'sahara@/':
    configure_permission => '.*',
    write_permission     => '.*',
    read_permission      => '.*',
    provider             => 'rabbitmqctl',
    require              => Class['::rabbitmq'],
  }

  class { '::sahara::db::mysql':
    password => 'sahara',
  }
  class { '::sahara::keystone::auth':
    # SSL does not seem to work in Sahara
    # https://bugs.launchpad.net/sahara/+bug/1565082
    public_url   => "http://${::openstack_integration::config::ip_for_url}:8386/v1.1/%(tenant_id)s",
    internal_url => "http://${::openstack_integration::config::ip_for_url}:8386/v1.1/%(tenant_id)s",
    admin_url    => "http://${::openstack_integration::config::ip_for_url}:8386/v1.1/%(tenant_id)s",
    password     => 'a_big_secret',
  }
  class { '::sahara':
    host                  => $::openstack_integration::config::host,
    database_connection   => 'mysql+pymysql://sahara:sahara@127.0.0.1/sahara?charset=utf8',
    default_transport_url => os_transport_url({
      'transport' => 'rabbit',
      'host'      => $::openstack_integration::config::host,
      'port'      => $::openstack_integration::config::rabbit_port,
      'username'  => 'sahara',
      'password'  => 'an_even_bigger_secret',
    }),
    rabbit_use_ssl        => $::openstack_integration::config::ssl,
    debug                 => true,
  }
  class { '::sahara::keystone::authtoken':
    password            => 'a_big_secret',
    user_domain_name    => 'Default',
    project_domain_name => 'Default',
    auth_url            => $::openstack_integration::config::keystone_admin_uri,
    auth_uri            => $::openstack_integration::config::keystone_auth_uri,
    memcached_servers   => $::openstack_integration::config::memcached_servers,
  }
  class { '::sahara::service::api':
    api_workers => 2,
  }
  class { '::sahara::service::engine': }
  class { '::sahara::client': }
  class { '::sahara::notify': }

  # for ubuntu we need saharaclient >= 0.15.0
  if $::osfamily == 'RedHat' {
    # create simple sahara templates
    sahara_node_group_template { 'master':
      ensure         => present,
      plugin         => 'vanilla',
      plugin_version => '2.7.1',
      flavor         => 'm1.micro',
      node_processes => [ 'namenode', 'resourcemanager' ],
    }

    sahara_node_group_template { 'worker':
      ensure         => present,
      plugin         => 'vanilla',
      plugin_version => '2.7.1',
      flavor         => 'm1.micro',
      node_processes => [ 'datanode', 'nodemanager' ],
    }

    sahara_cluster_template { 'cluster':
      ensure      => present,
      node_groups => [ 'master:1', 'worker:2' ]
    }

    Nova_flavor<||> -> Sahara_node_group_template<||>
    Class['::sahara::keystone::auth'] -> Sahara_node_group_template<||>
    Class['::openstack_extras::auth_file'] -> Sahara_node_group_template<||>
  }
}
