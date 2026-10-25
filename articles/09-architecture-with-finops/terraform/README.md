# Terraform · FinOps monthly budget

A deliberately minimal, non-destructive example: creates **one AWS monthly cost budget** and email alerts when actual spend exceeds 80% or forecasted spend exceeds 100% of the target. It does not provision workloads, purchase Savings Plans, stop resources, or **enforce a spending cap**.

## Prerequisites

- Terraform >= 1.5, configured AWS credentials, and permission to manage AWS Budgets in the target account.
- A valid notification email address and approval to create a budget.
- Review current AWS Budgets pricing and free-tier limits for your account.

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan -var='alert_email=finops@example.com' -var='monthly_budget_usd=1000'
# Only after reviewing the plan and replacing the example email:
terraform apply -var='alert_email=finops@example.com' -var='monthly_budget_usd=1000'
```

**Important:** do not apply with the example email address. AWS Budgets is not real time; charges can accrue before an alert is delivered. Before removing this demo resource, review `terraform plan -destroy`. Do not run `destroy` if the state includes unrelated resources.

[AWS Budgets documentation](https://docs.aws.amazon.com/cost-management/latest/userguide/budgets-managing-costs.html) · [Terraform aws_budgets_budget](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/budgets_budget)
