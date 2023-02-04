variable "env" {
  type    = string
  default = "none"
}

output "hello_env" {
  value = "Hello, ${var.env}!"
}
