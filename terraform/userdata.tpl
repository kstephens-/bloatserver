#!/bin/bash -xe

# since we explicitly set the ami version in the launch template, managed
# node groups consider it a custom ami. For that reason, we still have to
# explicitly call the bootstrap script ourselves
/etc/eks/bootstrap.sh --b64-cluster-ca '${eks_certificate_authority}' --apiserver-endpoint '${eks_endpoint}' '${eks_cluster_name}'
