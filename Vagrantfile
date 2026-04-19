# Load cluster topology and resource parameters from a separate file to keep
# this Vagrantfile free of magic numbers.
load "infrastructure/vagrant/params.rb"

# Helper: increment the last octet of an IPv4 address string by `offset`.
# Used to derive per-node IPs from a base address (e.g. "10.0.0.10" + 2 => "10.0.0.12").
def ip_offset(base, offset)
  parts = base.split(".")
  parts[-1] = (parts[-1].to_i + offset).to_s
  parts.join(".")
end

Vagrant.configure("2") do |config|
  # Base box for all VMs — bento images are minimal and well-maintained.
  config.vm.box = CLUSTER[:box]

  # Give VMs up to 10 minutes to boot before Vagrant declares a timeout.
  # Needed because VirtualBox imports can be slow on the first run.
  config.vm.boot_timeout = 600

  # ── VirtualBox provider defaults (applied to every VM) ────────────────────
  config.vm.provider "virtualbox" do |vb|
    # Redirect the virtual serial port to /dev/null (File::NULL on Windows) so
    # boot messages don't spam a host console window.
    vb.customize ["modifyvm", :id, "--uart1", "0x3F8", "4"]
    vb.customize ["modifyvm", :id, "--uartmode1", "file", File::NULL]

    # Explicitly mark the NIC cable as connected — prevents a rare race where
    # VirtualBox boots the VM before the virtual cable is attached.
    vb.customize ["modifyvm", :id, "--cableconnected1", "on"]
  end

  # ── Cloud-init ─────────────────────────────────────────────────────────────
  # Vagrant mounts this as a NoCloud ISO so cloud-init can configure the guest
  # on first boot (packages, timezone, users, etc.) without baking a custom image.
  config.vm.cloud_init do |ci|
    ci.content_type = "text/cloud-config"
    ci.path = "infrastructure/vagrant/cloud-init.yaml"
  end

  # ── Control plane nodes ────────────────────────────────────────────────────
  ctrl = CLUSTER[:control]

  (1..ctrl[:count]).each do |i|
    # Use a plain name when there is only one control node; append an index
    # when running a multi-master setup so names stay unique.
    name = ctrl[:count] == 1 ? "k3s-control" : "k3s-control-#{i}"
    ip   = ip_offset(ctrl[:ip_start], i - 1)

    config.vm.define name do |vm|
      vm.vm.hostname = name

      # Host-only network gives nodes a stable, routable IP on the host.
      # NAT (adapter 1) is added automatically by Vagrant for internet access.
      vm.vm.network "private_network", ip: ip

      vm.vm.provider "virtualbox" do |vb|
        vb.name   = name
        vb.cpus   = ctrl[:cpus]
        vb.memory = ctrl[:memory]

        # Group all cluster VMs under one folder in the VirtualBox GUI.
        vb.customize ["modifyvm", :id, "--groups", CLUSTER[:vb_group]]
      end
    end
  end

  # ── Worker nodes ──────────────────────────────────────────────────────────
  wrk = CLUSTER[:workers]

  (1..wrk[:count]).each do |i|
    name = "k3s-worker-#{i}"
    ip   = ip_offset(wrk[:ip_start], i - 1)

    config.vm.define name do |vm|
      vm.vm.hostname = name
      vm.vm.network "private_network", ip: ip

      vm.vm.provider "virtualbox" do |vb|
        vb.name   = name
        vb.cpus   = wrk[:cpus]
        vb.memory = wrk[:memory]
        vb.customize ["modifyvm", :id, "--groups", CLUSTER[:vb_group]]
      end
    end
  end
end
