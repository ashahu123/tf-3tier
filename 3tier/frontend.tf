resource "aws_security_group" "web_sg" {
  name = "web_sg"
  description = "Allow HTTP/S and SSH traffic"
  vpc_id      = aws_vpc.tt.id

  # Ingress rules (Inbound traffic)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow SSH from anywhere (use cautiously!)
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow HTTP from anywhere
  }

  # ingress {
  #   from_port   = 443
  #   to_port     = 443
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"] # Allow HTTPS from anywhere
  # }

  # Egress rules (Outbound traffic)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # All protocols
    cidr_blocks = ["0.0.0.0/0"] # Allow outbound traffic to anywhere
  }

  tags = {
    Name = "web-security-group"
  }
}

resource "aws_launch_template" "lt" {
    name = "web-lt"
    image_id = "ami-022ce6f32988af5fa"
    instance_type = "t2.micro"
    key_name = "aws_key"
    vpc_security_group_ids = [ aws_security_group.web_sg.id ]
    user_data = filebase64("./apache-install.sh")
}

resource "aws_autoscaling_group" "web-asg" {
    max_size = 4
    min_size = 1
    desired_capacity = 1
    launch_template {
        id = aws_launch_template.lt.id
        #version = aws_launch_template.lt.latest_version
    }  
    vpc_zone_identifier = [ aws_subnet.public1.id, aws_subnet.public2.id ]
    target_group_arns = [aws_lb_target_group.tg-web.arn]
}

resource "aws_autoscaling_policy" "web-asg-policy" {
  autoscaling_group_name = aws_autoscaling_group.web-asg.name
  name                   = "web-asg-policy"
  policy_type            = "TargetTrackingScaling"
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 50.0
  }
}

resource "aws_lb_target_group" "tg-web" {
  name     = "tg-web"
  port     = 80
  protocol = "HTTP"
  vpc_id = aws_vpc.tt.id
  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 2
    matcher = "200-299"
    interval            = 30
    timeout             = 5
  }
}

resource "aws_lb" "web_lb" {
  name               = "web-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_sg.id]
  subnets            = [aws_subnet.public1.id, aws_subnet.public2.id]
}

resource "aws_lb_listener" "lb_listener" {
  load_balancer_arn = aws_lb.web_lb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg-web.arn
  }
}


