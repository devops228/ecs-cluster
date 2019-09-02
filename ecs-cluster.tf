# ECS cluster
resource "aws_ecs_cluster" "ecs-cluster" {
  name = "ecs-cluster"
}
#Compute
resource "aws_autoscaling_group" "ecs-cluster" {
  name                      = "ecs-cluster"
  vpc_zone_identifier       = aws_subnet.private.*.id
  min_size                  = 2
  max_size                  = 10
  desired_capacity          = 3
  launch_configuration      = "${aws_launch_configuration.ecs-cluster-lc.name}"
  health_check_grace_period = 120
  default_cooldown          = 30
  termination_policies      = ["OldestInstance"]
 
}

resource "aws_autoscaling_policy" "ecs-cluster" {
  name                      = "demo-ecs-auto-scaling"
  policy_type               = "TargetTrackingScaling"
  estimated_instance_warmup = 90
  adjustment_type           = "ChangeInCapacity"
  autoscaling_group_name    = "${aws_autoscaling_group.ecs-cluster.name}"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 60.0
  }
}

resource "aws_launch_configuration" "ecs-cluster-lc" {
  name_prefix     = "ecs-cluster-lc"
  security_groups = ["${aws_security_group.instance_sg.id}"]

  # key_name                    = "${aws_key_pair.demodev.key_name}"
  image_id                    = "${data.aws_ami.latest_ecs.id}"
  instance_type               = "${var.instance_type}"
  iam_instance_profile        = "${aws_iam_instance_profile.ecs-ec2-role.id}"
  user_data                   = "${data.template_file.ecs-cluster.rendered}"
  associate_public_ip_address = true

  lifecycle {
    create_before_destroy = true
  }
}
