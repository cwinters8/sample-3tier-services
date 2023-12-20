# Sample 3 tier services

Sample web and API services to deploy in the [sample 3 tier infra](https://github.com/cwinters8/sample-3tier-infra) configuration.

## Deployment

This repository is configured with a GitHub Actions workflow that handles building and pushing the Docker images to their respective ECR repositories and deploying the new version of the app through the [terraform configuration](./terraform). The `README.md` in the `terraform` directory has all the information you will need if you would like to make changes to the services configuration or run the `terraform apply` process locally.
