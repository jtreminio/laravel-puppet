Made by Juan Treminio over a few hour period. The Vagrantfile is about 5x as large as I would like it,
but it works for what it's made for.

If you want to make your own box, go to my other project, [https://puphpet.com](PuPHPet).

Quick box to meet Taylor Otwell's requirements:

Vagrant Box:
------------
* PHP 5.5
* XDebug - php5-xdebug
* Curl - curl / php5-curl
* APCu - php5-apcu
* Memcached - php5-memcached
* Redis - redis-server
* Redis Commander - https://github.com/nearinfinity/redis-commander
* MySQL (Able to be accessed from host via Sequel Pro / Navicat)
* Postgres (Able to be accessed from host via Navicat)
* Beanstalkd - beanstalkd
* Beanstalkd Console - https://github.com/ptrofimov/beanstalk_console
* Grunt - http://gruntjs.com/
* Would be nice: Python Fabric - http://docs.fabfile.org/en/1.8/
    * not done, not familiar with Python or Fabric :(
* Relatively easy addition of any PECL module (mailparse, etc.)...

Using Puppet Librarian, sources listed at `puppet/Puppetfile`.

Using Hiera for most of the customization. The file is located at `puppet/hieradata/common.yaml`

Dotfiles are copied into the VM on every `up` or `provision` or `reload`. Copy/paste/symlink your dotfiles to
`files/dot`. I have some sample ones in there already.
