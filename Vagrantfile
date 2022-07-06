# -*- mode: ruby -*-
# vi: set ft=ruby :

# Using vagrant as a testing platform, since I need a full VM
# to test CAC login.
Vagrant.configure("2") do |config|
  config.vm.define "ubuntu22.04" do |cfg|
    cfg.vm.box = "fasmat/ubuntu2204-desktop"
    cfg.vm.box_version = "22.0509.1"

    #cfg.ssh.private_key_path = "~/.ssh/id_rsa"
    #cfg.ssh.forward_agent = true

    #cfg.vm.provider "vmware_desktop" do |v, override|
    #  v.gui = true
    #  v.vmx["displayname"] = "ubuntu22.04"
    #  v.memory = 4096
    #end

    cfg.vm.provider "virtualbox" do |vb, override|
      vb.name = "ubuntu22.04"
      vb.gui = true
      vb.memory = 4096
      vb.customize ["modifyvm", :id, "--vram", "256"]
    end

    # Staging VM for use with GUI.
    cfg.vm.provision "shell", inline: 'apt update'
    cfg.vm.provision "shell", inline: 'apt upgrade -y'
    cfg.vm.provision "shell", inline: 'apt install -y virtualbox-guest-utils'
    #cfg.vm.provision "shell", inline: 'wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub|sudo apt-key add -'
    cfg.vm.provision "shell", inline: 'sudo sh -c "echo \'deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main\' > /etc/apt/sources.list.d/google.list"'
    cfg.vm.provision "shell", inline: 'apt install -y firefox'
    #cfg.vm.provision "shell", inline: 'reboot'

    # Setting up VM with the CAC setup script.
    #cfg.vm.provision "shell", inline: 'sudo bash -c "$(wget https://raw.githubusercontent.com/jdjaxon/linux_cac/main/cac_setup.sh -O -)"'
  end
end
