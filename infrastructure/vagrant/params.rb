CLUSTER = {
  box:      "bento/ubuntu-22.04",
  vb_group: "/k3s-homelab",

  control: {
    count:    1,
    cpus:     2,
    memory:   2048,
    ip_start: "10.0.0.10",
  },

  workers: {
    count:    2,
    cpus:     1,
    memory:   1024,
    ip_start: "10.0.0.20",
  },
}
