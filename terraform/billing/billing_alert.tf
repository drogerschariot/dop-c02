resource "aws_sns_topic" "billing_alert" {
  provider = aws.use1
  name     = "${local.name}-billing-alert"
}

resource "aws_sns_topic_subscription" "billing_sms" {
  provider  = aws.use1
  topic_arn = aws_sns_topic.billing_alert.arn
  protocol  = "sms"
  endpoint  = "+12153801945"
}

resource "aws_budgets_budget" "monthly_forecast" {
  name         = "${local.name}-monthly-forecast"
  budget_type  = "COST"
  limit_amount = "100"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "ABSOLUTE_VALUE"
    notification_type          = "FORECASTED"
    subscriber_sns_topic_arns  = [aws_sns_topic.billing_alert.arn]
  }
}

resource "aws_sns_topic_policy" "billing_alert" {
  provider = aws.use1
  arn      = aws_sns_topic.billing_alert.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowBudgetsPublish"
        Effect = "Allow"
        Principal = {
          Service = "budgets.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.billing_alert.arn
      }
    ]
  })
}
