# ---------- Балансировщик: единственная точка входа снаружи ----------
# Это тот же reverse proxy, что nginx на занятии 9, только как облачный сервис.

resource "sbercloud_lb_loadbalancer" "lb" {
  name          = "${var.prefix}-lb"
  vip_subnet_id = data.sbercloud_vpc_subnet.course.subnet_id # IPv4-ID подсети (не id!)
  tags          = local.tags
}

# Публичный IP балансировщика
resource "sbercloud_vpc_eip" "lb" {
  publicip {
    type = "5_bgp"
  }

  bandwidth {
    name        = "${var.prefix}-lb-bw"
    share_type  = "PER"
    size        = 5
    charge_mode = "traffic"
  }
}

resource "sbercloud_networking_eip_associate" "lb" {
  public_ip = sbercloud_vpc_eip.lb.address
  port_id   = sbercloud_lb_loadbalancer.lb.vip_port_id
}

# Слушатель: принимает HTTP на 80-м порту (как listen 80 в nginx)
resource "sbercloud_lb_listener" "http" {
  name            = "${var.prefix}-http"
  protocol        = "HTTP"
  protocol_port   = 80
  loadbalancer_id = sbercloud_lb_loadbalancer.lb.id
}

# Пул серверов: куда отправлять запросы (как upstream в nginx)
resource "sbercloud_lb_pool" "app" {
  name        = "${var.prefix}-app-pool"
  protocol    = "HTTP"
  lb_method   = "ROUND_ROBIN"
  listener_id = sbercloud_lb_listener.http.id
}

# Health check: балансировщик сам спрашивает /health у каждого сервера.
# Ответ не 200 три раза подряд — сервер выводится из ротации.
resource "sbercloud_lb_monitor" "health" {
  name           = "${var.prefix}-health"
  pool_id        = sbercloud_lb_pool.app.id
  type           = "HTTP"
  url_path       = "/health"
  expected_codes = "200"
  delay          = 5
  timeout        = 3
  max_retries    = 3
}

# Участники пула: по одному на каждый сервер приложения
resource "sbercloud_lb_member" "app" {
  for_each = module.app

  pool_id       = sbercloud_lb_pool.app.id
  address       = each.value.private_ip
  protocol_port = 8000
  subnet_id     = data.sbercloud_vpc_subnet.course.subnet_id
}
