# Google Cloud Load Balancer Managed Certificate rotation with Terraform

This repo contains the Terraform resource and code snippet to dynamically provisioning Google Managed SSL certificates for dynamic domain lists.

## Note

This solution was implemented before the release of the GCP Certificate Manager service, which allows for a more flexible use of the certificates (via maps and map entries). It is thus recommended to first take a look to the service at https://cloud.google.com/certificate-manager/docs/overview since in the future it will be the primary choice for GCP managed certificates.

## Scenario description

Since GCP managed certificates are immutable, adding/removing a new domain requires to create a new SSL certificate to add to the Global HTTPS Load Balancer.

The strict limit of max 15 certificates per Load Balancer makes this scenario unfeasable.

But since each certificate can contain up to 100 domains, a rotation procedure could be performed where:

- we start with a domain list A with the certificate A attached to LB (and in an active state)

- we decide to update the domain list to B

- A new managed certificate B is created with the domain list B and attached to the load balancer

- the procedure waits until the certificate B is in active state

- once certificate B is in active state, certificate A can be removed from the load balancer


If the domain list size exceeds 100 entries, the procedure automatically performs the same steps using the number of certificates required.


## Content of this repo

This repo contains the following resources to setup the scenario (using Terraform):

- backend bucket with a static content to show load balancer is working

- dedicated service account and custom role with minimum set of permissions required to perform the ssl certificate rotation

- gcp global external http/s load balancer setup

- cloud function (with source code) used to perform the steps described in the above section

Updating the domain list in the *terraform.tfvars* file and launching Terraform will ensure that the cloud function env variables will be updated with the new domain list and the cloud scheduler job which triggers the cf will automatically starts the certificate rotation procedure.


## Requirements

You will need the following resources in order to test this repo:

- A GCP Project with an active billing account

- A user/service account with at least Editor role on the GCP project in order to create the required resources

- Terraform >=1.1.0 on your laptop

- gcloud > 365.0 on your laptop

- a personal domain with a DNS registrar to add A records


## Launch steps

### Set project

```
gcloud compute set project <PROJECT_ID>
```

### Ensure required APIs are enabled

```
gcloud services enable compute.googleapis.com logging.googleapis.com cloudfunctions.googleapis.com pubsub.googleapis.com cloudbuild.googleapis.com cloudscheduler.googleapis.com
```

### Execute Terraform

Rename *terraform.tfvars.template* to *terraform.tfvars* and enter the required values, then launch Terraform:

```
terraform init
terraform plan -out plan.out
terraform apply plan.out
```

### Add to your DNS registrar the domains pointing to the load balancer IP (from terraform output) and wait for certificates to be active


### Try to add new domain to the domain_list variable, relaunch terraform and wait for certificates to be rotated.