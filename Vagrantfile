# -*- mode: ruby -*-
# vi: set ft=ruby :

# Using vagrant as a testing platform, since I need a full VM
# to test CAC login.
Vagrant.configure("2") do |config|
  config.vm.define "ubuntu22" do |cfg|
    cfg.vm.box = "alvistack/ubuntu-22.04"
    cfg.vm.hostname = "ubuntu22"

    cfg.vm.provider "vmware_desktop" do |v, override|
      v.gui = true
      v.vmx["displayname"] = "ubuntu22"
      v.memory = "4096"
    end

    cfg.vm.provider "virtualbox" do |vb, override|
      vb.gui = true
      vb.name = "ubuntu22"
      vb.memory = "4096"
      vb.customize ["modifyvm", :id, "--memory", 4096]
    end

    cfg.vm.provision "shell", inline: 'apt-get update', privileged: true
    cfg.vm.provision "shell", inline: 'apt-get update', privileged: true
    cfg.vm.provision "shell", inline: 'sudo apt install -y tasksel', privileged: true
    cfg.vm.provision "shell", inline: 'sudo tasksel install ubuntu-desktop', privileged: true
    cfg.vm.provision "shell", inline: 'reboot', privileged: true
    cfg.vm.provision "shell", inline: 'sudo systemctl set-default graphical.target', privileged: true
    cfg.vm.provision "shell", inline: 'sudo bash -c "$(wget https://raw.githubusercontent.com/jdjaxon/linux_cac/main/cac_setup.sh -O -)"', privileged: true
  end
end
