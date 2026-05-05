resource "aws_lb" "this" {
  name               = "spc-stg-ue1-alb-external"
  internal           = false              # internet-facing
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids

  drop_invalid_header_fields = true       # security best practice

  tags = merge(var.common_tags, {
    Name = "spc-stg-ue1-alb-external"
  })
}

resource "aws_lb_target_group" "default" {
  name        = "spc-stg-ue1-alb-tg-default"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"                      # required for EKS pod routing

  health_check {
    path                = "/actuator/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 15
    timeout             = 5
    matcher             = "200"
  }

  tags = merge(var.common_tags, {
    Name = "spc-stg-ue1-alb-tg-default"
  })
}

# Port 80 — redirects all HTTP traffic to HTTPS permanently
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = merge(var.common_tags, {
    Name = "spc-stg-ue1-alb-listener-http"
  })
}

# Port 443 — SSL terminates here, traffic forwarded to target group
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.default.arn
  }

  tags = merge(var.common_tags, {
    Name = "spc-stg-ue1-alb-listener-https"
  })
}