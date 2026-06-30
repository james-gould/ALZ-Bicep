# CloudHealth health model discovery via policy

A spike for [Azure/ahm-planning#3553](https://github.com/Azure/ahm-planning/issues/3553). The policy creates a `Microsoft.CloudHealth/healthmodels` health model whose discovery rule finds every other health model in a target resource group and roots them under the model. These files are subscription-scoped and self-contained, and not yet wired into the ALZ module structure.

## What you must adapt

Set these for your environment before you deploy:

1. **Sign in and pick the subscription.**
   ```bash
   az login
   az account set --subscription <YOUR_SUBSCRIPTION_ID>
   ```
2. **Permissions.** You need `Owner`, or `Contributor` plus `User Access Administrator`, on the subscription. The deployment creates role assignments (a Reader grant for the discovery identity and two roles for the policy identity), which needs role-assignment write.
3. **The target resource group must already exist.** The default is `rg-aon2-global`. Pass your own with `targetResourceGroupName=<YOUR_RG>`.
4. **Pick a region that supports Microsoft.CloudHealth** (uksouth, centralus, swedencentral, northeurope). The default is `uksouth`. Pass your own with `location=<REGION>`.

Optional overrides: `healthModelName`, `identityName`, `assignmentName`, and `resourceGraphQuery`. Leave `resourceGraphQuery` empty and the policy builds a query that discovers every health model in `targetResourceGroupName` except the deployed model.

## Deploy

**1. Deploy the policy, identity, and assignment (one command).**
```bash
az deployment sub create \
  --location uksouth \
  --template-file healthmodel-policy.bicep \
  --parameters targetResourceGroupName=rg-aon2-global
```

**2. Evaluate compliance.** This forces an on-demand scan and waits for it (about 10 to 15 minutes).
```bash
az policy state trigger-scan --resource-group rg-aon2-global
```

**3. Remediate the resource group.** The policy deploys the health model, the discovery rule, and the relationship that roots the discovery entity under the model.
```bash
az policy remediation create --name remediate-ahm \
  --policy-assignment "$(az policy assignment show --name deploy-ahm-discovery --query id --output tsv)"
```

## Verify

Discovery runs on a five-minute cadence. After a few minutes, list the discovered models:
```bash
az monitor health-models entity list \
  --resource-group rg-aon2-global \
  --health-model-name hm-portfolio-aon2 \
  --query "[].properties.displayName" --output tsv
```
You should see the deployed model, the `discover-healthmodels` entity, and one entry per health model found in the resource group.

## Files

| File | Purpose |
|------|---------|
| `healthmodel-policy.bicep` | The file you deploy. It defines the `DeployIfNotExists` policy (the embedded template creates the health model, an authentication setting, the discovery rule, and the root relationship), assigns the policy, grants the policy identity Contributor and Managed Identity Operator, and imports the identity module below. |
| `healthmodel-discovery-identity.bicep` | Resource-group-scoped module: the user-assigned managed identity the discovery rule runs as, plus a Reader grant on the target resource group so its query can run. |

## Notes

- The Reader grant happens at deploy time through the identity module, so the policy's remediation identity stays at Contributor and Managed Identity Operator. It does not need Owner.
- `Microsoft.CloudHealth` has no strong Bicep types, so `az bicep build` accepts invalid shapes. Confirm any change with a live deploy.
- `ReEvaluateCompliance` remediation can stall, so the steps above use `trigger-scan` followed by the default remediation mode.
