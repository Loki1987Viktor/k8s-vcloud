resource "vcd_vm_internal_disk" "mst_data1_disk" {
  depends_on       = [vcd_vapp.k8s_mgmt_vapp,
                      vcd_vapp_org_network.vappOrgNet,
                      vcd_vapp_vm.k8s_masters_vms]
  count           = var.vms_config.masters.vm_count
  #count = 2
  vapp_name       = var.vcloud.vapp_name
  bus_type        = var.disks_config.diskm1.bus_type
  size_in_mb      = var.disks_config.diskm1.sizegb * 1024
  bus_number      = var.disks_config.diskm1.bus_num
  unit_number     = var.disks_config.diskm1.unit_num
  vm_name = "${var.project.owner_org}-${var.project.name}-${var.project.env_name}-mst-${format("%02s", (count.index + 1))}"
}

resource "vcd_vm_internal_disk" "mst_data2_disk" {
  depends_on       = [vcd_vapp.k8s_mgmt_vapp,
                      vcd_vapp_org_network.vappOrgNet,
                      vcd_vapp_vm.k8s_masters_vms]
  count           = var.vms_config.masters.vm_count
  #count = 2
  vapp_name       = var.vcloud.vapp_name
  bus_type        = var.disks_config.diskm2.bus_type
  size_in_mb      = var.disks_config.diskm2.sizegb * 1024
  bus_number      = var.disks_config.diskm2.bus_num
  unit_number     = var.disks_config.diskm2.unit_num
  vm_name = "${var.project.owner_org}-${var.project.name}-${var.project.env_name}-mst-${format("%02s", (count.index + 1))}"
}

resource "vcd_vm_internal_disk" "wrk_data1_disk" {
  depends_on       = [vcd_vapp.k8s_mgmt_vapp,
                      vcd_vapp_org_network.vappOrgNet,
                      vcd_vapp_vm.k8s_workers_vms]
  count           = var.vms_config.workers.vm_count
  #count = 2
  vapp_name       = var.vcloud.vapp_name
  bus_type        = var.disks_config.diskw1.bus_type
  size_in_mb      = var.disks_config.diskw1.sizegb * 1024
  bus_number      = var.disks_config.diskw1.bus_num
  unit_number     = var.disks_config.diskw1.unit_num
  vm_name = "${var.project.owner_org}-${var.project.name}-${var.project.env_name}-wrk-${format("%02s", (count.index + 1))}"
}

resource "vcd_vm_internal_disk" "wrk_data2_disk" {
  depends_on       = [vcd_vapp.k8s_mgmt_vapp,
                      vcd_vapp_org_network.vappOrgNet,
                      vcd_vapp_vm.k8s_workers_vms]
  count           = var.vms_config.workers.vm_count
  #count = 2
  vapp_name       = var.vcloud.vapp_name
  bus_type        = var.disks_config.diskw2.bus_type
  size_in_mb      = var.disks_config.diskw2.sizegb * 1024
  bus_number      = var.disks_config.diskw2.bus_num
  unit_number     = var.disks_config.diskw2.unit_num
  vm_name = "${var.project.owner_org}-${var.project.name}-${var.project.env_name}-wrk-${format("%02s", (count.index + 1))}"
}


resource "vcd_vapp_vm" "k8s_masters_vms" {

  depends_on       = [vcd_vapp.k8s_mgmt_vapp,
                      vcd_vapp_vm.k8s_workers_vms]
  vapp_name        = vcd_vapp.k8s_mgmt_vapp.name
  name             = "${var.project.owner_org}-${var.project.name}-${var.project.env_name}-mst-${format("%02s", (count.index + 1))}"
  count            = var.vms_config.masters.vm_count

  catalog_item     = data.vcd_catalog_item.vm_template.id
  #vapp_template_id  = data.vcd_catalog_item.vm_template.id
  #catalog_name     = data.vcd_catalog.vcd_dp_linux.name
  #template_name    = var.vcloud.vm_template_name
  hardware_version = "vmx-15"
  cpus             = var.vms_config.masters.vm_cpu_count
  memory           = var.vms_config.masters.vm_ram_size
  cpu_cores        = 1

  network {
    type               = "org"
    name               = var.vcloud.orgvnet_name
    ip_allocation_mode = "MANUAL"
    adapter_type       = "VMXNET3"
    ip                 =  "${cidrhost(var.os_config.vm_ip_cidr, (count.index+tonumber(var.ip_plan.m_node)))}"
  }
  override_template_disk {
    size_in_mb      = var.disks_config.osdisk.sizegb * 1024
    bus_type        = var.disks_config.osdisk.bus_type
    bus_number      = var.disks_config.osdisk.bus_num
    unit_number     = var.disks_config.osdisk.unit_num
    # storage_profile = var.mod_system_disk_storage_profile
  }

  guest_properties = {
    "instance-id" = "${var.project.owner_org}-${var.project.name}-${var.project.env_name}-mst-${format("%02s", (count.index + 1))}"
    "hostname"    = "${var.project.owner_org}-${var.project.name}-${var.project.env_name}-mst-${format("%02s", (count.index + 1))}"
    "user-data"   = "${base64encode(data.template_file.cloudinit_master_node.rendered)}"
  }

}

resource "vcd_vapp_vm" "k8s_workers_vms" {

  depends_on       = [vcd_vapp.k8s_mgmt_vapp,
                      vcd_vapp_org_network.vappOrgNet]
  
  vapp_name        = vcd_vapp.k8s_mgmt_vapp.name
  name             = "${var.project.owner_org}-${var.project.name}-${var.project.env_name}-wrk-${format("%02s", (count.index + 1))}"
  count            = var.vms_config.workers.vm_count

  vapp_template_id  = data.vcd_catalog_item.vm_template.id

  #catalog_name     = data.vcd_catalog.vcd_dp_linux.name
  #template_name    = var.vcloud.vm_template_name
  hardware_version = "vmx-15" #Test version    
  cpus             = var.vms_config.workers.vm_cpu_count
  memory           = var.vms_config.workers.vm_ram_size
  cpu_cores        = 1

  network {
    type               = "org"
    name               = var.vcloud.orgvnet_name
    ip_allocation_mode = "MANUAL"
    adapter_type       = "VMXNET3"
     ip                 =  "${cidrhost(var.os_config.vm_ip_cidr, (count.index+tonumber(var.ip_plan.w_node)))}"
  }
  override_template_disk {
    size_in_mb      = var.disks_config.osdisk.sizegb * 1024
    bus_type        = var.disks_config.osdisk.bus_type
    bus_number      = var.disks_config.osdisk.bus_num
    unit_number     = var.disks_config.osdisk.unit_num
    # storage_profile = var.mod_system_disk_storage_profile
  }

  guest_properties = {
    "instance-id" = "${var.project.owner_org}-${var.project.name}-${var.project.env_name}-wrk-${format("%02s", (count.index + 1))}"
    "hostname"    = "${var.project.owner_org}-${var.project.name}-${var.project.env_name}-wrk-${format("%02s", (count.index + 1))}"
    "user-data"   = "${base64encode(data.template_file.cloudinit_worker_node.rendered)}"
  }

}

### -- the last VM is deployment VM, from there all Ansible automation will run
resource "vcd_vapp_vm" "dvm" {

  depends_on       = [vcd_vapp.k8s_mgmt_vapp,
                      vcd_vapp_vm.k8s_masters_vms]
  vapp_name        = vcd_vapp.k8s_mgmt_vapp.name
  #name             = "${var.vms.dvm.pref}"
  name             = "dvm"
  
  vapp_template_id  = data.vcd_catalog_item.vm_template.id

  #catalog_name     = data.vcd_catalog.vcd_dp_linux.name
  #template_name    = var.vcloud.vm_template_name
  hardware_version = "vmx-15"
  cpus             = var.vms_config.dvm.vm_cpu_count
  memory           = var.vms_config.dvm.vm_ram_size
  cpu_cores        = 1

  network {
    type               = "org"
    name               = var.vcloud.orgvnet_name
    ip_allocation_mode = "MANUAL"
    adapter_type       = "VMXNET3"
    ip                 =  "${cidrhost(var.os_config.vm_ip_cidr,tonumber(var.ip_plan.dvm) )}"
  }
  override_template_disk {
    size_in_mb      = var.disks_config.osdisk.sizegb * 1024
    bus_type        = var.disks_config.osdisk.bus_type
    bus_number      = var.disks_config.osdisk.bus_num
    unit_number     = var.disks_config.osdisk.unit_num
    # storage_profile = var.mod_system_disk_storage_profile

  }

  guest_properties = {
    #"instance-id" = "${var.vms.dvm.pref}"
    #"hostname"    = "${var.vms.dvm.pref}"
    "instance-id" = "dvm"
    "hostname"    = "dvm"
    "user-data"   = "${base64encode(data.template_file.cloudinit_dvm.rendered)}"
  }

}

