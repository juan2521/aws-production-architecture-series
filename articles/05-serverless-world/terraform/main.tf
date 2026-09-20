terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
    archive = { source = "hashicorp/archive", version = "~> 2.7" }
  }
}
provider "aws" { region = var.aws_region }
variable "aws_region" { type = string; default = "us-east-1" }
variable "project" { type = string; default = "production-serverless" }

data "archive_file" "consumer" {
  type = "zip"
  output_path = "${path.module}/consumer.zip"
  source { content = <<PY
import json
def handler(event, context):
    failures=[]
    for record in event.get("Records", []):
        try:
            payload=json.loads(record["body"])
            print(json.dumps({"event":"processing","payload":payload}))
            # Production: enforce business idempotency before side effects.
        except Exception:
            failures.append({"itemIdentifier": record["messageId"]})
    return {"batchItemFailures": failures}
PY
    filename = "handler.py"
  }
}
resource "aws_sqs_queue" "dlq" { name="${var.project}-dlq"; message_retention_seconds=1209600 }
resource "aws_sqs_queue" "work" {
  name="${var.project}-work"; visibility_timeout_seconds=180
  redrive_policy=jsonencode({deadLetterTargetArn=aws_sqs_queue.dlq.arn,maxReceiveCount=5})
}
resource "aws_cloudwatch_event_bus" "domain" { name="${var.project}-bus" }
resource "aws_cloudwatch_event_rule" "orders" {
  name="${var.project}-orders"; event_bus_name=aws_cloudwatch_event_bus.domain.name
  event_pattern=jsonencode({source=["production.orders"]})
}
resource "aws_cloudwatch_event_target" "queue" { rule=aws_cloudwatch_event_rule.orders.name; event_bus_name=aws_cloudwatch_event_bus.domain.name; target_id="WorkQueue"; arn=aws_sqs_queue.work.arn }
resource "aws_sqs_queue_policy" "events" {
  queue_url=aws_sqs_queue.work.id
  policy=jsonencode({Version="2012-10-17",Statement=[{Effect="Allow",Principal={Service="events.amazonaws.com"},Action="sqs:SendMessage",Resource=aws_sqs_queue.work.arn,Condition={ArnEquals={"aws:SourceArn"=aws_cloudwatch_event_rule.orders.arn}}}]})
}
resource "aws_iam_role" "lambda" {
  name="${var.project}-consumer-role"
  assume_role_policy=jsonencode({Version="2012-10-17",Statement=[{Effect="Allow",Principal={Service="lambda.amazonaws.com"},Action="sts:AssumeRole"}]})
}
resource "aws_iam_role_policy" "lambda" {
  role=aws_iam_role.lambda.id
  policy=jsonencode({Version="2012-10-17",Statement=[
    {Effect="Allow",Action=["sqs:ReceiveMessage","sqs:DeleteMessage","sqs:GetQueueAttributes"],Resource=aws_sqs_queue.work.arn},
    {Effect="Allow",Action=["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"],Resource="*"}
  ]})
}
resource "aws_lambda_function" "consumer" {
  function_name="${var.project}-consumer"; role=aws_iam_role.lambda.arn; runtime="python3.13"; handler="handler.handler"
  filename=data.archive_file.consumer.output_path; source_code_hash=data.archive_file.consumer.output_base64sha256
  timeout=30; reserved_concurrent_executions=10
}
resource "aws_lambda_event_source_mapping" "sqs" {
  event_source_arn=aws_sqs_queue.work.arn; function_name=aws_lambda_function.consumer.arn; batch_size=10
  function_response_types=["ReportBatchItemFailures"]
}
resource "aws_cloudwatch_metric_alarm" "dlq" {
  alarm_name="${var.project}-dlq-not-empty"; namespace="AWS/SQS"; metric_name="ApproximateNumberOfMessagesVisible"
  dimensions={QueueName=aws_sqs_queue.dlq.name}; statistic="Maximum"; period=60; evaluation_periods=1; threshold=0; comparison_operator="GreaterThanThreshold"
}
output "event_bus_name" { value=aws_cloudwatch_event_bus.domain.name }
output "queue_url" { value=aws_sqs_queue.work.url }
output "dlq_url" { value=aws_sqs_queue.dlq.url }
