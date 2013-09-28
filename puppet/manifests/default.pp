$php_values = hiera('php')
$apache_values = hiera('apache')
$xdebug_values = hiera('xdebug')
$mysql_values = hiera('mysql')
$postgresql_values = hiera('postgresql')

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

package { ['build-essential', 'vim-nox', 'curl', 'wget', 'git-core', 'python-pip' ]:
  ensure  => 'installed',
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

