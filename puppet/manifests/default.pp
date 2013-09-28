$php_values = hiera('php')
$apache_values = hiera('apache')
$xdebug_values = hiera('xdebug')
$mysql_values = hiera('mysql')
$postgresql_values = hiera('postgresql')
$redis_values = hiera('redis')
$beanstalkd_values = hiera('beanstalkd')

group { 'puppet': ensure => present }
Exec { path => [ '/bin/', '/sbin/', '/usr/bin/', '/usr/sbin/' ] }
File { owner => 0, group => 0, mode => 0644 }

class { 'apt': }

Class['::apt::update'] -> Package <|
    title != 'python-software-properties'
and title != 'software-properties-common'
|>

apt::source { 'packages.dotdeb.org':
  location          => 'http://packages.dotdeb.org',
  release           => $lsbdistcodename,
  repos             => 'all',
  required_packages => 'debian-keyring debian-archive-keyring',
  key               => '89DF5277',
  key_server        => 'keys.gnupg.net',
  include_src       => true
}

if $php_values['install_php55'] {
  apt::source { 'packages.dotdeb.org-php55':
    location          => 'http://packages.dotdeb.org',
    release           => 'wheezy-php55',
    repos             => 'all',
    required_packages => 'debian-keyring debian-archive-keyring',
    key               => '89DF5277',
    key_server        => 'keys.gnupg.net',
    include_src       => true
  }
}

package { ['build-essential', 'vim-nox', 'wget', 'git-core', 'python-pip', 'checkinstall' ]:
  ensure  => 'installed',
}

if !defined(Package['curl']) {
  package { 'curl':
    ensure => 'present',
  }
}

exec { 'dotfiles':
  cwd     => '/home/vagrant',
  command => "cp -r /vagrant/files/dot/.[a-zA-Z0-9]* /home/vagrant/",
  onlyif  => "test -d /vagrant/files/dot",
}

file { '/var/www':
  ensure  => 'directory'
}

class { 'apache':
  servername    => $apache_values['servername'],
  default_vhost => false,
  mpm_module    => 'prefork',
  require       => [
    Apt::Source['packages.dotdeb.org'],
    File['/var/www']
  ],
}

create_resources(apache::vhost, $apache_values['vhosts'])

define apache_mod {
  class { "apache::mod::${name}": }
}

apache_mod { $apache_values['mods']:; }

class { 'php':
  service       => 'httpd',
  module_prefix => '',
  require       => Package['httpd'],
}

class { 'php::devel':
  require => Class['php'],
}

if $php_values['install_pear'] {
  class { 'php::pear':
    require => Class['php'],
  }
}

define php_mod {
  php::module { $name: }
}

php_mod { $php_values['mods']:; }

define php_pecl_mod {
  php::pecl::module { $name:
    use_package => false,
  }
}

php_pecl_mod { $php_values['pecl_mods']:; }

class { 'composer':
  require => Package['php5', 'curl'],
}

class { 'xdebug':
  service => 'httpd',
}

puphpet::ini { 'xdebug':
  value   => $xdebug_values,
  ini     => '/etc/php5/mods-available/zzz_xdebug.ini',
  notify  => Service['httpd'],
  require => Class['php'],
}

file { '/etc/php5/cli/conf.d/zzz_xdebug.ini':
  target  => '/etc/php5/mods-available/zzz_xdebug.ini',
  ensure  => link,
  require => Puphpet::Ini['xdebug']
}

file { '/etc/php5/apache2/conf.d/zzz_xdebug.ini':
  target  => '/etc/php5/mods-available/zzz_xdebug.ini',
  ensure  => link,
  require => Puphpet::Ini['xdebug']
}

if !defined(File['/usr/bin/xdebug']) {
  file { '/usr/bin/xdebug':
    ensure => 'present',
    mode   => '+X',
    source => 'puppet:///modules/xdebug/cli_alias.erb'
  }
}

puphpet::ini { 'php':
  value   => $php_values['ini'],
  ini     => '/etc/php5/mods-available/zzz_php.ini',
  notify  => Service['httpd'],
  require => Class['php'],
}

file { '/etc/php5/cli/conf.d/zzz_php.ini':
  target  => '/etc/php5/mods-available/zzz_php.ini',
  ensure  => link,
  require => Puphpet::Ini['php']
}

file { '/etc/php5/apache2/conf.d/zzz_php.ini':
  target  => '/etc/php5/mods-available/zzz_php.ini',
  ensure  => link,
  require => Puphpet::Ini['php']
}

class { 'mysql::server':
  root_password => $mysql_values['root_password'],
  require       => Class['apache'],
}

create_resources(mysql::db, $mysql_values['dbs'])

class { 'postgresql::server': }

define postgresql_server_db (
  $user,
  $password,
  $encoding   = $postgresql::server::encoding,
  $locale     = $postgresql::server::locale,
  $grant      = 'ALL',
  $tablespace = undef,
  $istemplate = false
) {
  $dbname = $name

  postgresql::server::db{ 'laravel4':
    user       => $user,
    password   => postgresql_password($password, $dbname),
    encoding   => $encoding,
    locale     => $locale,
    grant      => $grant,
    tablespace => $tablespace,
    istemplate => $istemplate
  }
}

create_resources(postgresql_server_db, $postgresql_values['dbs'])

class { 'nodejs':
  version      => 'v0.10.17',
  make_install => false,
  with_npm     => false,
}

define install_node_npm() {
  wget::fetch { "npm-download-${node_version}":
    source             => 'https://npmjs.org/install.sh',
    nocheckcertificate => true,
    destination        => '/tmp/install.sh',
  }

  exec { "npm-install-${node_version}":
    command     => 'sh install.sh',
    path        => '/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin',
    cwd         => '/tmp',
    user        => 'root',
    environment => 'clean=yes',
    unless      => 'which npm',
    require     => [
      Wget::Fetch["npm-download-${node_version}"],
      Package['curl'],
    ],
  }

  file { "${node_target_dir}/npm":
    target  => '/usr/local/bin/npm',
    ensure  => link,
    require => Exec["npm-install-${node_version}"],
  }
}

install_node_npm{ 'default':
  require => Class['nodejs']
}

class { 'redis':
  conf_port => $redis_values['conf_port'],
  conf_bind => $redis_values['conf_bind'],
}

package { 'redis-commander':
  provider => npm
}

class {'beanstalkd' :
  listen_addr => $beanstalkd_values['listen_addr'],
  listen_port => $beanstalkd_values['listen_port'],
}

git::repo{ 'beanstalk_console':
  path    => '/var/www/beanstalk_console',
  source  => 'git://github.com/ptrofimov/beanstalk_console.git',
  require => Class['beanstalkd']
}

apache::vhost { 'beanstalk_console.dev':
  servername    => 'beanstalk_console.dev',
  serveraliases => ['www.beanstalk_console.dev',],
  docroot       => '/var/www/beanstalk_console/public',
  port          => '80',
  override      => ['All',],
  require => Git::Repo['beanstalk_console']
}

package { 'grunt-cli':
  provider => npm
}
