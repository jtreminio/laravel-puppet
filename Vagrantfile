Vagrant.configure("2") do |config|
  config.vm.box = "wheezy64"
  config.vm.box_url = "http://puppet-vagrant-boxes.puppetlabs.com/debian-70rc1-x64-vbox4210.box"

  config.vm.network :private_network, ip: "192.168.56.101"
  config.vm.network :forwarded_port,  guest: 80, host: 8080
  config.ssh.forward_agent = true

  config.vm.provider :virtualbox do |v|
    v.customize ["modifyvm",     :id, "--natdnshostresolver1", "on"]
    v.customize ["modifyvm",     :id, "--memory", 768]
    v.customize ["modifyvm",     :id, "--name", "laravel-vm"]
    v.customize ["setextradata", :id, "VBoxInternal2/SharedFoldersEnableSymlinksCreate/v-root", "1"]
  end

  # uncomment the following and change to what you want to share
  # first folder is LOCAL to master, second is inside the VM
  #config.vm.synced_folder "~/www/", "/var/www", id: "vagrant-root" , :nfs => true

  config.vm.provision :shell, :path   => "shell/librarian-puppet-vagrant.sh"
  config.vm.provision :shell, :inline =>
    "if [[ ! -f /apt-get-run ]]; then sudo apt-get update && touch /apt-get-run; fi"

  config.vm.provision :puppet do |puppet|
    puppet.manifests_path = "puppet/manifests"
    puppet.module_path    = "puppet/modules"
    puppet.options        = ['--color']
    puppet.options        = "--hiera_config /vagrant/hiera.yaml"
  end
end
