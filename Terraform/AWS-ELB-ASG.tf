provider "aws" {
    region = "us-east-1"
}

resource "aws_security_group" "allow-http" {
    name = "allow-http-sg"

    ingress {
        from_port = "${var.server_port}"
        to_port = "${var.server_port}"
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    lifecycle {
        create_before_destroy = true
    }
}

resource "aws_launch_configuration" "lc-tf-test" {
    image_id = "ami-0c94855ba95c71c99"
    instance_type = "t2.micro"
    security_groups = ["${aws_security_group.allow-http.id}"]
    user_data = <<-EOF
                #! /bin/bash
                yum install httpd
                echo "<html><h1>This is a test webpage inside EC2</h1></html>" > /var/www/html/index.html
                service httpd start
                EOF
    lifecycle {
        create_before_destroy = true
    }

}

resource "aws_autoscaling_group" "asg-terraform-test" {
    launch_configuration = "${aws_launch_configuration.lc-tf-test.id}"
    availability_zones = ["us-east-1a", "us-east-1b"]
    load_balancers = ["${aws_elb.elb-tf-test.name}"]
    #health_check_type = "ELB"
    min_size = 2
    max_size = 3
    tag {
        key = "Name"
        value = "tf-asg-instance"
        propagate_at_launch = true
    }
}

resource "aws_elb" "elb-tf-test" {
    name = "terraform-elb"
    availability_zones = ["us-east-1a", "us-east-1b"]
    security_groups = ["${aws_security_group.elb-sg.id}"]
    listener {
        lb_port = 80
        lb_protocol = "http"
        instance_port = "${var.server_port}"
        instance_protocol = "http"
    }
    /*
    health_check {
        healthy_threshold = 2
        unhealthy_threshold = 2
        timeout = 3
        interval = 30
        target = "HTTP:${var.server_port}/"
    }
    */
}

resource "aws_security_group" "elb-sg" {
    name = "terraform-elb-sg"
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

variable "server_port" {
    description = "Use this port to send HTTP requests to the server"
    default = 80
}

output "elb-dns-name" {
    value = "${aws_elb.elb-tf-test.dns_name}"
}
