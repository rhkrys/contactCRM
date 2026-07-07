# ContactCRM Infrastructure (Terraform)

Declarative definition of the AWS stack serving
**https://sales.awesomeblackbusiness.com** — S3 (private) + CloudFront (OAC,
HTTPS) + ACM (DNS-validated) + Route 53.

## Layout

- `main.tf` — all resources, variables, and outputs.

## Usage

```sh
cd web/infra/terraform
export AWS_PROFILE=svc-ai-cowork-mcp
terraform init
terraform plan
terraform apply
```

## Adopting the already-deployed resources

The site was first stood up with the AWS CLI, so the live resources exist
outside Terraform state. Import them once so `plan` shows no changes instead of
trying to recreate them (IDs are the current deployment):

```sh
terraform import aws_s3_bucket.site                      sales.awesomeblackbusiness.com
terraform import aws_cloudfront_distribution.site        E2SWY5YFIV3RV9
terraform import aws_cloudfront_origin_access_control.site E334I0GQFVAN6T
terraform import aws_acm_certificate.site                arn:aws:acm:us-east-1:306499034564:certificate/af587cc5-2c1d-44b7-9f29-4b21d9b1c1d8
# Route 53 records: <ZONE_ID>_<RECORD_NAME>_<TYPE>
terraform import aws_route53_record.site                 ZQKDSIZ3XJDSM_sales.awesomeblackbusiness.com_A
```

## Content deploys

Terraform manages the **infrastructure**, not the site files. To publish the
`web/` app, use `web/deploy.sh` (S3 sync + CloudFront invalidation).
