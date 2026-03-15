"srv01" = {
  name               = "SRV01"
  desc               = "SRV01 - exchange - the-eyrie - {{ip_range}}.21"
  cores              = 4
  memory             = 8192
  clone              = "WinServer2019_x64"
  dns                = "{{ip_range}}.1"
  ip                 = "{{ip_range}}.21/24"
  gateway            = "{{ip_range}}.1"
}