data "aws_ami" "eks-worker" {
  filter {
    name   = "name"
    values = ["amazon-eks-node-${aws_eks_cluster.k8s.version}-v*"]
  }

  most_recent = true
  owners      = ["amazon"] # Amazon
}

locals {
  k8s-node-userdata = <<USERDATA
#!/bin/bash
set -o xtrace
/etc/eks/bootstrap.sh --apiserver-endpoint '${aws_eks_cluster.k8s.endpoint}' --b64-cluster-ca '${aws_eks_cluster.k8s.certificate_authority[0].data}' '${var.cluster-name}'
USERDATA

}

resource "aws_launch_configuration" "k8s" {
  associate_public_ip_address = true
  iam_instance_profile = aws_iam_instance_profile.k8s-node.name
  image_id = data.aws_ami.eks-worker.id
  instance_type = "t2.micro"
  name_prefix = "terraform-eks-k8s"
  security_groups = [aws_security_group.k8s-node.id]
  user_data_base64 = base64encode(local.k8s-node-userdata)

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "k8s" {
  desired_capacity = 2
  launch_configuration = aws_launch_configuration.k8s.id
  max_size = 2
  min_size = 1
  name = "terraform-eks-k8s"
  vpc_zone_identifier = module.vpc.public_subnets

  tag {
    key = "Name"
    value = "terraform-eks-k8s"
    propagate_at_launch = true
  }

  tag {
    key = "kubernetes.io/cluster/${var.cluster-name}"
    value = "owned"
    propagate_at_launch = true
  }
}

