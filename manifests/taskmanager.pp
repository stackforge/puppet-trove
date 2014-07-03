#
# Copyright (C) 2014 eNovance SAS <licensing@enovance.com>
#
# Author: Emilien Macchi <emilien.macchi@enovance.com>
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.
#
# == Class: trove::taskmanager
#
# Manages trove taskmanager package and service
#
# === Parameters:
#
# [*enabled*]
#   (optional) Whether to enable the trove-taskmanager service
#   Defaults to true
#
# [*manage_service*]
#   (optional) Whether to start/stop the service
#   Defaults to true
#
# [*ensure_package*]
#   (optional) The state of the trove taskmanager package
#   Defaults to 'present'
#
# [*verbose*]
#   (optional) Rather to log the trove api service at verbose level.
#   Default: false
#
# [*debug*]
#   (optional) Rather to log the trove api service at debug level.
#   Default: false
#
# [*log_file*]
#   (optional) The path of file used for logging
#   If set to boolean false, it will not log to any file.
#   Default: /var/log/trove/trove-taskmanager.log
#
# [*log_dir*]
#    (optional) directory to which trove logs are sent.
#    If set to boolean false, it will not log to any directory.
#    Defaults to '/var/log/trove'
#
# [*use_syslog*]
#   (optional) Use syslog for logging.
#   Defaults to false.
#
# [*log_facility*]
#   (optional) Syslog facility to receive log lines.
#   Defaults to 'LOG_USER'.
#
# [*auth_url*]
#   (optional) Authentication URL.
#   Defaults to 'http://localhost:5000/v2.0'.
#

class trove::taskmanager(
  $enabled        = true,
  $manage_service = true,
  $debug          = false,
  $verbose        = false,
  $log_file       = '/var/log/trove/trove-taskmanager.log',
  $log_dir        = '/var/log/trove',
  $use_syslog     = false,
  $log_facility   = 'LOG_USER',
  $auth_url       = 'http://localhost:5000/v2.0',
  $ensure_package = 'present'
) inherits trove {

  include trove::params

  Package[$::trove::params::taskmanager_package_name] -> Trove_taskmanager_config<||>
  Trove_taskmanager_config<||> ~> Exec['post-trove_config']
  Trove_taskmanager_config<||> ~> Service['trove-taskmanager']

  if $::trove::database_connection {
    if($::trove::database_connection =~ /mysql:\/\/\S+:\S+@\S+\/\S+/) {
      if ($::trove::mysql_module >= 2.2) {
        require 'mysql::bindings'
        require 'mysql::bindings::python'
      } else {
        require 'mysql::python'
      }
    } elsif($::trove::database_connection =~ /postgresql:\/\/\S+:\S+@\S+\/\S+/) {

    } elsif($::trove::database_connection =~ /sqlite:\/\//) {

    } else {
      fail("Invalid db connection ${::trove::database_connection}")
    }
    trove_taskmanager_config {
      'DEFAULT/sql_connection':   value => $::trove::database_connection;
      'DEFAULT/sql_idle_timeout': value => $::trove::database_idle_timeoutl;
    }
  }

  # basic service config
  trove_taskmanager_config {
    'DEFAULT/verbose':                      value => $verbose;
    'DEFAULT/debug':                        value => $debug;
    'DEFAULT/trove_auth_url':               value => $auth_url;
    'DEFAULT/nova_proxy_admin_user':        value => $::trove::nova_proxy_admin_user;
    'DEFAULT/nova_proxy_admin_pass':        value => $::trove::nova_proxy_admin_pass;
    'DEFAULT/nova_proxy_admin_tenant_name': value => $::trove::nova_proxy_admin_tenant_name;
  }

  if $::trove::rpc_backend == 'trove.openstack.common.rpc.impl_kombu' {
    # I may want to support exporting and collecting these
    trove_taskmanager_config {
      'DEFAULT/rabbit_password':     value => $::trove::rabbit_password, secret => true;
      'DEFAULT/rabbit_userid':       value => $::trove::rabbit_userid;
      'DEFAULT/rabbit_virtual_host': value => $::trove::rabbit_virtual_host;
      'DEFAULT/rabbit_use_ssl':      value => $::trove::rabbit_use_ssl;
      'DEFAULT/amqp_durable_queues': value => $::trove::amqp_durable_queues;
    }

    if $::trove::rabbit_use_ssl {
      trove_taskmanager_config {
        'DEFAULT/kombu_ssl_ca_certs': value => $::trove::kombu_ssl_ca_certs;
        'DEFAULT/kombu_ssl_certfile': value => $::trove::kombu_ssl_certfile;
        'DEFAULT/kombu_ssl_keyfile':  value => $::trove::kombu_ssl_keyfile;
        'DEFAULT/kombu_ssl_version':  value => $::trove::kombu_ssl_version;
      }
    } else {
      trove_taskmanager_config {
        'DEFAULT/kombu_ssl_ca_certs': ensure => absent;
        'DEFAULT/kombu_ssl_certfile': ensure => absent;
        'DEFAULT/kombu_ssl_keyfile':  ensure => absent;
        'DEFAULT/kombu_ssl_version':  ensure => absent;
      }
    }

    if $::trove::rabbit_hosts {
      trove_taskmanager_config { 'DEFAULT/rabbit_hosts':     value => join($::trove::rabbit_hosts, ',') }
      trove_taskmanager_config { 'DEFAULT/rabbit_ha_queues': value => true }
    } else {
      trove_taskmanager_config { 'DEFAULT/rabbit_host':      value => $::trove::rabbit_host }
      trove_taskmanager_config { 'DEFAULT/rabbit_port':      value => $::trove::rabbit_port }
      trove_taskmanager_config { 'DEFAULT/rabbit_hosts':     value => "${::trove::rabbit_host}:${::trove::rabbit_port}" }
      trove_taskmanager_config { 'DEFAULT/rabbit_ha_queues': value => false }
    }
  }

  if $::trove::rpc_backend == 'trove.openstack.common.rpc.impl_qpid' {
    trove_taskmanager_config {
      'DEFAULT/qpid_hostname':               value => $::trove::qpid_hostname;
      'DEFAULT/qpid_port':                   value => $::trove::qpid_port;
      'DEFAULT/qpid_username':               value => $::trove::qpid_username;
      'DEFAULT/qpid_password':               value => $::trove::qpid_password, secret => true;
      'DEFAULT/qpid_heartbeat':              value => $::trove::qpid_heartbeat;
      'DEFAULT/qpid_protocol':               value => $::trove::qpid_protocol;
      'DEFAULT/qpid_tcp_nodelay':            value => $::trove::qpid_tcp_nodelay;
    }
    if is_array($::trove::qpid_sasl_mechanisms) {
      trove_taskmanager_config {
        'DEFAULT/qpid_sasl_mechanisms': value => join($::trove::qpid_sasl_mechanisms, ' ');
      }
    }
  }

  # Logging
  if $log_file {
    trove_taskmanager_config {
      'DEFAULT/log_file': value  => $log_file;
    }
  } else {
    trove_taskmanager_config {
      'DEFAULT/log_file': ensure => absent;
    }
  }

  if $log_dir {
    trove_taskmanager_config {
      'DEFAULT/log_dir': value  => $log_dir;
    }
  } else {
    trove_taskmanager_config {
      'DEFAULT/log_dir': ensure => absent;
    }
  }

  # Syslog
  if $use_syslog {
    trove_taskmanager_config {
      'DEFAULT/use_syslog'          : value => true;
      'DEFAULT/syslog_log_facility' : value => $log_facility;
    }
  } else {
    trove_taskmanager_config {
      'DEFAULT/use_syslog': value => false;
    }
  }

  trove::generic_service { 'taskmanager':
    enabled        => $enabled,
    manage_service => $manage_service,
    package_name   => $::trove::params::taskmanager_package_name,
    service_name   => $::trove::params::taskmanager_service_name,
    ensure_package => $ensure_package,
  }
}
