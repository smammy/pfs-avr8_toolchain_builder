# -*- mode: ruby -*-
# vi: set ft=ruby :

# default host cpu/ram values, in case we can't determine from OS
host_cpus = 1
host_ram = 4096

# use this portion of host ram for guest
guest_ram_frac = 0.25

# clamp guest memory in this range
guest_ram_min = 512
guest_ram_max = 1024

# get host cpu/ram values from OS (platform-specific)
host = RbConfig::CONFIG['host_os']
if host =~ /darwin/
  host_cpus = `sysctl -n hw.physicalcpu`.to_i
  host_ram = `sysctl -n hw.memsize`.to_i / 1024 / 1024
elsif host =~ /linux/
  host_cpus = `nproc`.to_i
  host_ram = `awk '/^MemTotal:/{print $2}' /proc/meminfo`.to_i / 1024
elsif host =~ /w32/
  require 'win32ole'
  WIN32OLE.connect('winmgmts://').ExecQuery('select * from Win32_ComputerSystem').each do |wmi_obj|
    wmi_obj.properties_.each do |prop|
      case prop.name
      when 'NumberOfLogicalProcessors'
        host_cpus = prop.value.to_i
      when 'TotalPhysicalMemory'
        host_ram = prop.value.to_i / 1024 / 1024
      end
    end
  end
end

# check if usb2 and usb3 are supported
ehci_available = `VBoxManage list extpacks`.include?('USB 2.0')
xhci_available = `VBoxManage list extpacks`.include?('USB 3.0')

Vagrant.configure(2) do |config|
  config.vm.box = 'bento/ubuntu-16.04'
  config.vm.provider 'virtualbox' do |vb|
    vb.cpus = host_cpus
    vb.memory = [guest_ram_min, (host_ram*guest_ram_frac).to_int, guest_ram_max].sort[1]
    vb.customize ['modifyvm', :id, '--ioapic',  'on'] if host_cpus > 1
    vb.customize ['modifyvm', :id, '--usb',     'on']
    vb.customize ['modifyvm', :id, '--usbehci', 'on'] if ehci_available
    vb.customize ['modifyvm', :id, '--usbxhci', 'on'] if xhci_available
    
    # Fix time syncing
    vb.customize ['guestproperty', 'set', :id, '/VirtualBox/GuestAdd/VBoxService/--timesync-interval',       10000]
    vb.customize ['guestproperty', 'set', :id, '/VirtualBox/GuestAdd/VBoxService/--timesync-min-adjust',       100]
    vb.customize ['guestproperty', 'set', :id, '/VirtualBox/GuestAdd/VBoxService/--timesync-set-on-restore',     1]
    vb.customize ['guestproperty', 'set', :id, '/VirtualBox/GuestAdd/VBoxService/--timesync-set-threshold',   1000]
  end
  
  # Use Ansible to provision
  config.vm.provision 'ansible_local' do |ansible|
    ansible.playbook = 'provision/playbook.yml'
    #ansible.verbose = 'vvv'
  end
  
  # Cache downloaded files
  if Vagrant.has_plugin?('vagrant-cachier')
    config.cache.scope = :box
    config.cache.enable :generic, {
      "wget" => { cache_dir: "/var/cache/wget" },
    }
  end
  
end
