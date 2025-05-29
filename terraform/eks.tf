locals {
  instance_type = "t3.small"
  addons = [
    {
      name    = "vpc-cni"
      version = "v1.18.6-eksbuild.1"
    },
    {
      name    = "coredns"
      version = "v1.11.3-eksbuild.2"
    },
    {
      name    = "kube-proxy"
      version = "v1.31.2-eksbuild.2"
    }
  ]
}

# eks security groups
resource "aws_security_group" "cluster" {
  name        = "cluster"
  description = "Cluster communication with worker nodes"
  vpc_id      = aws_vpc.vpc.id
}

resource "aws_security_group_rule" "cluster_ingress_node_https" {
  description              = "Allow pods to communicate with the cluster api server"
  protocol                 = "tcp"
  from_port                = 443
  to_port                  = 443
  security_group_id        = aws_security_group.cluster.id
  source_security_group_id = aws_security_group.node.id
  type                     = "ingress"
}

resource "aws_security_group_rule" "cluster_ingress_workstation_https" {
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow workstation to communicate with cluster API server"
  protocol          = "tcp"
  from_port         = 443
  to_port           = 443
  security_group_id = aws_security_group.cluster.id
  type              = "ingress"
}

resource "aws_security_group_rule" "cluster_egress_node" {
  description              = "Allow API server to communicate with nodes"
  type                     = "egress"
  security_group_id        = aws_security_group.cluster.id
  source_security_group_id = aws_security_group.node.id
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
}

resource "aws_security_group_rule" "cluster_egress_node_ssl" {
  description              = "Allow API server to communicate with nodes over ssl"
  type                     = "egress"
  security_group_id        = aws_security_group.cluster.id
  source_security_group_id = aws_security_group.node.id
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
}

resource "aws_security_group" "node" {
  name        = "node"
  description = "Security group for all nodes in the cluster"
  vpc_id      = aws_vpc.vpc.id
}

resource "aws_security_group_rule" "node_ingress_self" {
  description              = "Allow node to communicate with each other"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.node.id
  source_security_group_id = aws_security_group.node.id
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "node_ingress_cluster_ssl" {
  description              = "Allow worker kubelets and pods to receive communication from control plan over ssl"
  type                     = "ingress"
  security_group_id        = aws_security_group.node.id
  source_security_group_id = aws_security_group.cluster.id
  protocol                 = "tcp"
  from_port                = 443
  to_port                  = 443
}

resource "aws_security_group_rule" "node_ingress_cluster" {
  description              = "Allow worker kubeltes and pods to receive communication from cluster control plane"
  from_port                = 1025
  protocol                 = "tcp"
  security_group_id        = aws_security_group.node.id
  source_security_group_id = aws_security_group.cluster.id
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "node_egress" {
  type              = "egress"
  security_group_id = aws_security_group.node.id
  protocol          = -1
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
}

# eks iam roles
resource "aws_iam_role" "cluster" {
  name = "demo-cluster"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Sid = ""
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_role_policy_attachment" "cluster_service_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_role" "node" {
  name = "demo-node"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Sid = ""
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "node_worker_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node_container_registry_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node.name
}

# allow access to amazon linux repos
resource "aws_iam_role_policy" "ami_resources" {
  name = "node-ami-resource-policy"
  role = aws_iam_role.node.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "s3:GetObject"
        Effect   = "Allow"
        Resource = "arn:aws:s3:::amazonlinux.us-west-2.amazonaws.com/*"
        Sid      = "amiRepoAccess"
      }
    ]
  })
}

# eks cluster
resource "aws_eks_cluster" "demo" {
  name     = "demo"
  version  = "1.31"
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    endpoint_private_access = true
    endpoint_public_access  = true
    security_group_ids      = [aws_security_group.cluster.id]
    subnet_ids              = aws_subnet.public.*.id
  }

  depends_on = [aws_iam_role.cluster, aws_iam_role.node]
}

resource "aws_eks_addon" "addons" {
  for_each = { for addon in local.addons : addon.name => addon }

  addon_name   = each.key
  cluster_name = aws_eks_cluster.demo.name

  addon_version               = each.value["version"]
  resolve_conflicts_on_create = "OVERWRITE"
}

# nodes
data "aws_ec2_instance_type" "node" {
  instance_type = local.instance_type
}

data "aws_ami" "node" {
  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["amazon-eks-node-1.31-v20241109"]
  }

  filter {
    name   = "architecture"
    values = data.aws_ec2_instance_type.node.supported_architectures
  }

  filter {
    name   = "virtualization-type"
    values = data.aws_ec2_instance_type.node.supported_virtualization_types
  }

  filter {
    name   = "root-device-type"
    values = data.aws_ec2_instance_type.node.supported_root_device_types
  }
}

data "template_file" "user_data" {
  template = file("${path.root}/userdata.tpl")

  vars = {
    eks_certificate_authority = aws_eks_cluster.demo.certificate_authority[0].data
    eks_endpoint              = aws_eks_cluster.demo.endpoint
    eks_cluster_name          = aws_eks_cluster.demo.name
    aws_region_current_name   = "us-west-2"
  }
}

data "cloudinit_config" "node_group" {
  base64_encode = true
  gzip          = false
  boundary      = "//"

  part {
    content_type = "text/x-shellscript"
    content      = data.template_file.user_data.rendered
  }
}

resource "aws_launch_template" "node_group" {
  name = "demo-node-group"

  image_id      = data.aws_ami.node.id
  instance_type = local.instance_type

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.node.id]
  }

  user_data = data.cloudinit_config.node_group.rendered
}

resource "aws_eks_node_group" "demo" {
  cluster_name    = "demo"
  node_group_name = "demo"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = aws_subnet.public.*.id

  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }

  launch_template {
    id      = aws_launch_template.node_group.id
    version = aws_launch_template.node_group.latest_version
  }

  update_config {
    max_unavailable = 1
  }
}
