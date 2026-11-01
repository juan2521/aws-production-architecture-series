# Terraform · AWS Organizations guardrail (chapter 10)

This example creates **a demonstration SCP without attaching it to any OU**. It denies CloudTrail and AWS Config logging shutdown/deletion actions **only if it is subsequently attached** to an OU of member accounts. It does not install AWS Control Tower, create accounts, or change effective permissions by default.

## Prerequisites

- Terraform >= 1.5 and a compatible AWS provider.
- An AWS Organizations organization with **all features** and the **SERVICE_CONTROL_POLICY** type enabled.
- Management-account credentials or an appropriately authorized Organizations policy-management role; verify delegated-administration scope.
- A laboratory OU and tested rollback procedure before considering attachment.

## Safe validation

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan
```

By default, the plan should show **one new unattached policy**. Review the plan, organization, and AWS identity before any `apply`.

### Optional attachment — approval required

```bash
terraform plan -var='attach_policy=true' -var='target_ou_id=ou-xxxx-xxxxxxxx'
# Replace with an actual lab OU ID; approve the plan before considering apply.
```

**Caveats:** SCPs are permission boundaries and **do not grant access**. They do not constrain the management account or service-linked roles in the same way as ordinary principals. This Deny can block legitimate maintenance, enrollment, or baseline operations. Test in a lab and review Control Tower-managed controls. Never run `terraform destroy` against shared state.

**References:** [AWS Organizations SCPs](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps.html) · [Terraform aws_organizations_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_policy) · [Terraform aws_organizations_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_policy_attachment)
