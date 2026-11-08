# Terraform — recovery DNS

Minimal example: two failover A records in an existing public hosted zone and a primary HTTPS health check. It does not provision the application or promote a database. Replace documentation IPs and zone with actual values. The secondary must be healthy and ready before traffic switching.

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan -var='zone_id=Z123456789EXAMPLE' -var='record_name=app.example.com' -var='primary_ip=203.0.113.10' -var='secondary_ip=198.51.100.20' -var='health_fqdn=health.example.com'
```
