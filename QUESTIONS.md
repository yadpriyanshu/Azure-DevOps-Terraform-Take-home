
---

## `QUESTIONS.md`

```markdown
# Middle-earth DevOps – Questions

Please answer briefly in your own words. Bullet points or short paragraphs are fine.

---

## 1. Terraform design

- How did you approach the dev/prod split?
The Current config is driven by a single env variable (dev or prod). A realm_by_env maps locally dev -> shire and prod -> gondor , so all resource names and tags stay consistent. Vnet and subnet CIDRs are also environment-specific so that dev and prod don't overlap. One codebase, one state per environment: deploy dev with -var-file=dev.tfvars & prod with -var-file=prod.tfvars ideally with seperate backend configs as per env.  


- How would this approach scale if we later add a third realm (for example, **Rohan**)?

Add an entry to realm_by_env (staging = "rohan") and extend the environment validation and the address-space maps (vnet_address_space_by_env, subnet_address_prefix_by_env) with new env. No new resources or copy-paste; only new keys in the existing maps and validation. If we outgrow a single main.tf, we could move shared pieces into a module and pass environment /realm as inputs.

---

## 2. CI/CD integration

- How would you plug this Terraform into a pipeline using **GitHub Actions** or **Azure DevOps**?
  Add a pipeline that runs in the repo on push/PR (e.g. to main or feature/*). Steps: checkout, terraform init (with backend config from a variable or secret), terraform validate, terraform plan (and optionally post plan as a comment). On merge to a release branch or on manual approval, run terraform apply -auto-approve for the corresponding environment. Use a matrix or parameter so the same pipeline can target dev or prod (e.g. environment: dev vs environment: prod) with separate jobs or stages.

- How would you:
  - Handle secrets (e.g. Azure credentials, state backend access)?
  Use OIDC/federated identity where possible (e.g. GitHub OIDC with Azure, or Azure DevOps service connection). Otherwise store Azure client credentials (client_id, client_secret, tenant_id) in the pipeline’s secret store (GitHub Secrets, Azure DevOps variable group with “secret” checked, or Azure Key Vault) and inject as env vars (e.g. ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_TENANT_ID, ARM_SUBSCRIPTION_ID). Never commit these.  

  If using Azure Storage for state, use a SAS token or storage account key from the same secret store, or use a managed identity with access to the storage account and pass only non-secret backend config (resource group, storage account, container, key).


  - Prevent accidental prod deployments from a developer’s laptop?
  - Do not give developers long-lived Azure credentials that can change prod.  
  - Allow plan locally (e.g. with read-only or dev credentials) but require apply to run only in CI for prod, with branch/PR rules and manual approval.  
  - Use separate state backends (and possibly separate subscriptions) for prod so that a dev running apply with dev vars doesn’t touch prod.  
  - In the pipeline, gate prod with: branch protection (e.g. only from main or release/*), required reviewers, and an explicit “environment” parameter so prod isn’t applied by default.
---

## 3. AI usage

If you used AI tools (e.g. ChatGPT, Copilot), please answer:

- What did you use them for?
Cursor was used to implement Terraform fixes and validating code for network acls and vault secret

- How did you validate or adjust the output?
Using Terraform validate command 

- Is there anything you chose not to use? Why?

---

## 4. If you had more time…

If you had another few hours, what would you improve or refactor in your solution?

**Modules** : I can create modules (Resource Group, Vnet, Subnet, App Service Plan, App Service, Key Vault, Access Policy) and call it with for_each over var.environments
**Remote Backend** : I can add Remote Backend system to manage Terraform State file at scale
**Linting/testing** : I can add jobs in CI like terraform fmt -check and tflint 
**OPA Policies** : I can add OPA policies to make sure infrastructure is provisoned with meeting certain requirements.

(Structure, modules, linting, testing, naming, documentation, anything you like.)
