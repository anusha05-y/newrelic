# nr-alert-sync

This project deploys a small Lambda function that keeps New Relic alert
policies aligned with EC2 instances in AWS.

The idea is simple, if an EC2 instance has an "application" tag, there
should be a corresponding Alert Policy in New Relic with the same name.
EC2 acts as the source of truth. The Lambda ensures New Relic reflects
that state automatically.

The function is triggered by an EventBridge rule whenever an EC2 instance
transitions to the "running" state. When invoked, it reads the instance’s
tags, extracts the value of the "application" key, and checks
whether a matching Alert Policy already exists in New Relic. If it does not,
the function creates one. If it already exists, the function exits cleanly.

The New Relic API key is stored in AWS Systems Manager Parameter Store
as a SecureString and retrieved at runtime. It is not hardcoded in the
Lambda or Terraform configuration.

CloudWatch log retention is explicitly set to 14 days to avoid
unbounded log growth if needed we can add more days as well

## Why This Design

Event-driven trigger

Instead of periodically scanning EC2 inventory, we react to EC2 state change
events via EventBridge. This solution avoids unnecessary API calls, and keeps cost and operational overhead low.

Lambda for glue logic

The logic required is small and stateless: read a tag, check for an existing
policy, create one if missing. 
Lambda is a good fit because it avoids managing infrastructure and scales automatically.

EC2 as source of truth

Rather than attempting bidirectional sync, EC2 tags define the intended state.
New Relic policies are derived from that state.

#Idempotency

Before creating a policy, the Lambda checks whether it already exists. This
ensures retries (or duplicate events) do not create duplicate policies.

#Secrets management

The New Relic API key is stored in SSM Parameter Store as a SecureString and
retrieved at runtime. It is not embedded in the code or Terraform state.

#Operational considerations

- CloudWatch log retention is explicitly set to avoid unbounded growth.
- The function has a short timeout to prevent hanging on external API calls.
- IAM permissions are scoped to only what is required.


## Repository Layout

The repository is split into two main parts.

The "lambda/" directory contains the function code, its minimal dependency
file, and a small build script used to package the deployment artifact.

The "terraform/" directory defines all required AWS infrastructure,
including IAM roles, the Lambda function, the EventBridge rule, and
logging configuration.

A sample event payload is included under "tests/" for reference when
simulating the trigger locally.


## Setup

First, store your New Relic API key in SSM:

aws ssm put-parameter \
  --name /newrelic/api-key \
  --value <API_KEY> \
  --type SecureString

Next, build the Lambda package:

cd lambda
./build.sh

This generates "lambda.zip", which Terraform references during deployment.

Finally, deploy the infrastructure:

cd terraform
terraform init
terraform plan

terraform apply \
  -var="nr_api_key_param_name=/newrelic/api-key" \
  -var="nr_api_key_param_arn=<SSM_PARAMETER_ARN>"


## Verifying the Workflow

To validate the behavior, we should launch an EC2 instance and include a tag such as:

application=app-api

Once the instance reaches the 'running' state, the Lambda will execute.
You can review its execution logs in CloudWatch. A corresponding Alert
Policy named 'app-api' should appear in New Relic.

# Architecture diagram is attached on the root level in the name of architecture_diagram.png
"# newrelic" 
"# newrelic" 
