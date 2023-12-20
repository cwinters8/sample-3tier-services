# Terraform Infrastructure Configuration

The terraform configuration here is intended to be used in the GitHub Actions workflow to manage app service deployments.

## Required variables

- `api_image_tag`
  type: string

  The image applied to the API image deployed to the ECR repository

- `web_image_tag`
  type: string

  The image applied to the API image deployed to the ECR repository

## Deploying manually

### Prerequisites

The terraform configuration in the [sample 3 tier infra](https://github.com/cwinters8/sample-3tier-infra) must have already been applied successfully before this configuration is applied.

#### Tools

- [awscli](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html) installed and configured with access keys for a user with sufficient permissions
- [terraform](https://developer.hashicorp.com/terraform/install) installed

#### Credentials

If you don't have keys configured in `~/.aws/credentials`, you will need to set the environment variables `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`. These are used for authenticating both the prerequisite awscli commands and terraform itself.

```sh
export AWS_ACCESS_KEY_ID="your_access_key_id"
export AWS_SECRET_ACCESS_KEY="your_secret_access_key"
```

#### S3 Bucket

Create an S3 bucket if you don't already have one to use for this purpose. Ideally the bucket should have versioning enabled.

You must also update the `terraform.backend.s3.bucket` value in [providers.tf](./providers.tf) with your chosen bucket name.

```sh
BUCKET_NAME="3tier-app-services-infra"
aws s3 mb s3://$BUCKET_NAME
# enables versioning
aws s3api put-bucket-versioning --bucket $BUCKET_NAME --versioning-configuration Status=Enabled
```

To validate

```sh
aws s3api get-bucket-versioning --bucket $BUCKET_NAME
```

Expected output

```json
{
  "Status": "Enabled"
}
```

#### DynamoDB Table

The table must have a partition key named `LockID` with type of `String`.

The table name must be unique within the AWS account's region. The `terraform.backend.s3.dynamodb_table` value in [providers.tf](./providers.tf) must also be updated with your chosen table name.

```sh
TABLE_NAME="3tier-app-services-infra"
aws dynamodb create-table --table-name $TABLE_NAME \
--attribute-definitions AttributeName=LockID,AttributeType=S \
--key-schema AttributeName=LockID,KeyType=HASH \
--billing-mode PAY_PER_REQUEST
```

Expected output

```json
{
  "TableDescription": {
    "AttributeDefinitions": [
      {
        "AttributeName": "LockID",
        "AttributeType": "S"
      }
    ],
    "TableName": "3tier-app-services-infra",
    "KeySchema": [
      {
        "AttributeName": "LockID",
        "KeyType": "HASH"
      }
    ],
    "TableStatus": "CREATING",
    "CreationDateTime": "2023-12-20T10:30:42.796000-06:00",
    "ProvisionedThroughput": {
      "NumberOfDecreasesToday": 0,
      "ReadCapacityUnits": 0,
      "WriteCapacityUnits": 0
    },
    "TableSizeBytes": 0,
    "ItemCount": 0,
    "TableArn": "arn:aws:dynamodb:us-east-2:773669924601:table/3tier-app-services-infra",
    "TableId": "d23fdb0a-4202-489a-9e84-14b87a439f47",
    "BillingModeSummary": {
      "BillingMode": "PAY_PER_REQUEST"
    },
    "DeletionProtectionEnabled": false
  }
}
```

Validate the table creates successfully

```sh
aws dynamodb describe-table --table-name $TABLE_NAME
```

Expected output, showing table status `ACTIVE`

```json
{
  "Table": {
    "AttributeDefinitions": [
      {
        "AttributeName": "LockID",
        "AttributeType": "S"
      }
    ],
    "TableName": "3tier-app-services-infra",
    "KeySchema": [
      {
        "AttributeName": "LockID",
        "KeyType": "HASH"
      }
    ],
    "TableStatus": "ACTIVE",
    "CreationDateTime": "2023-12-20T10:30:42.796000-06:00",
    "ProvisionedThroughput": {
      "NumberOfDecreasesToday": 0,
      "ReadCapacityUnits": 0,
      "WriteCapacityUnits": 0
    },
    "TableSizeBytes": 0,
    "ItemCount": 0,
    "TableArn": "arn:aws:dynamodb:us-east-2:773669924601:table/3tier-app-services-infra",
    "TableId": "d23fdb0a-4202-489a-9e84-14b87a439f47",
    "BillingModeSummary": {
      "BillingMode": "PAY_PER_REQUEST",
      "LastUpdateToPayPerRequestDateTime": "2023-12-20T10:30:42.796000-06:00"
    },
    "DeletionProtectionEnabled": false
  }
}
```

To get just the status value using `jq`

```sh
aws dynamodb describe-table --table-name $TABLE_NAME | jq '.Table.TableStatus'
```

Expected output

```json
"ACTIVE"
```

### Docker images

Build and push docker images

Start these commands from the repository's root directory

```sh
# login to ECR with docker
aws ecr get-login-password | docker login --username AWS --password-stdin $(aws ecr describe-repositories | jq '.repositories[0].repositoryUri' | tr -d '"' | cut -d '/' -f1)

# Expected output: Login Succeeded

# get ECR repositories
API_REPO=$(aws ecr describe-repositories | jq '.repositories[].repositoryUri' | grep api | tr -d '"')
WEB_REPO=$(aws ecr describe-repositories | jq '.repositories[].repositoryUri' | grep web | tr -d '"')

# validate repositories
echo "api: $API_REPO\nweb: $WEB_REPO"

# pick a tag name (will also use when applying terraform)
TAG_NAME="validate.0"

# build and push api
docker build api -t $API_REPO:$TAG_NAME && docker push $API_REPO:$TAG_NAME

# build and push web
docker build web -t $WEB_REPO:$TAG_NAME && docker push $WEB_REPO:$TAG_NAME
```

### Apply terraform

```sh
cd terraform
TF_VAR_api_image_tag=$TAG_NAME TF_VAR_web_image_tag=$TAG_NAME terraform apply
```
