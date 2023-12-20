resource "aws_s3_bucket" "app_logs" {
  bucket        = "${var.app_name}-logs"
  force_destroy = true

  tags = var.logging_tags
}

resource "aws_s3_bucket_policy" "lb_logging" {
  bucket = aws_s3_bucket.app_logs.id
  policy = data.aws_iam_policy_document.lb_logging.json
}

data "aws_iam_policy_document" "lb_logging" {
  statement {
    principals {
      type        = "AWS"
      identifiers = [data.aws_elb_service_account.lb.arn]
    }
    actions = ["s3:PutObject"]
    resources = [
      "${aws_s3_bucket.app_logs.arn}/*/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
    ]
  }
}

data "aws_elb_service_account" "lb" {}
