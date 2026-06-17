output "host" {
  description = "In-cluster DNS name of the Redis service. Mapped onto the resource's `endpoint` property by the recipe `outputs` field."
  value       = "${kubernetes_service_v1.redis.metadata[0].name}.${kubernetes_service_v1.redis.metadata[0].namespace}.svc.cluster.local"
}

output "port" {
  description = "Port exposed by the Redis service. Mapped onto the resource's `port` property by the recipe `outputs` field."
  value       = tostring(var.port)
}
