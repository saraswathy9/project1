# cloudwatch-alarm.tf
# WHY: Even with Prometheus/Grafana, AWS CloudWatch gives native alarms
# on the EC2/Jenkins host itself (CPU, disk) that email/SMS you when
# something is wrong - no extra software needed.

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "jenkins-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods   = 2
  metric_name          = "CPUUtilization"
  namespace            = "AWS/EC2"
  period               = 300              # check every 5 minutes
  statistic            = "Average"
  threshold            = 80               # alert if CPU > 80%
  alarm_description    = "Alarm when Jenkins EC2 CPU exceeds 80%"
  dimensions = {
    InstanceId = aws_instance.jenkins_server.id
  }
}
