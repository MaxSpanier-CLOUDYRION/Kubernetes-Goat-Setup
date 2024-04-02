#!/bin/bash

show_help() {
  echo "Usage: $0 [OPTION]"
  echo "Automate the setup or teardown of a Kubernetes Goat environment on AWS EKS."
  echo ""
  echo "Options:"
  echo "  --create           Create the EKS cluster and deploy Kubernetes Goat."
  echo "  --delete           Delete the EKS cluster and teardown Kubernetes Goat."
  echo "  --help             Display this help message and exit."
  echo ""
  echo "Example:"
  echo "  $0 --create        # Sets up the environment."
  echo "  $0 --delete        # Tears down the environment."
}

# Check if an argument is passed
if [ $# -eq 0 ]; then
  echo "No arguments provided. Please use --create, --delete, or --help."
  exit 1
elif [ "$1" == "--help" ]; then
  show_help
  exit 0
elif [ "$1" == "--create" ]; then
  operation="create"
elif [ "$1" == "--delete" ]; then
  operation="delete"
else
  echo "Invalid argument. Please use --create, --delete, or --help."
  exit 1
fi

# Generate a random 6 character long string for the cluster name
cluster_name_suffix=$(LC_ALL=C tr -dc 'a-z0-9' < /dev/urandom | fold -w 6 | head -n 1)
cluster_name="k8s-goat-$cluster_name_suffix"

# Kubernetes Goat directory
k8s_goat_dir="kubernetes-goat"

# Check if the required tools are installed
for tool in eksctl kubectl aws helm; do
  command -v $tool >/dev/null 2>&1 || { echo >&2 "The tool $tool is required but it's not installed. Aborting.\e[0m"; exit 1; }
done

# Execute based on operation
if [ "$operation" == "create" ]; then
  echo "The whole setup can take up to 20 minutes!"

  # Step 1: Create the EKS cluster
  echo "Creating EKS cluster named $cluster_name..."
  eksctl create cluster --name "$cluster_name" \
  --region eu-central-1 \
  --node-type t4g.medium \
  --nodes 2
  if [ $? -ne 0 ]; then
	echo "Failed to create EKS cluster. Exiting..."
	exit 1
  fi

# Step 2: Update kubeconfig for the cluster
echo "Updating kubeconfig..."
aws eks update-kubeconfig --name "$cluster_name" --region eu-central-1
if [ $? -ne 0 ]; then
  echo "Failed to update kubeconfig. Exiting..."
  exit 1
fi

# Step 3: Clone Kubernetes Goat and run setup script
echo "Cloning Kubernetes Goat..."
git clone https://github.com/madhuakula/kubernetes-goat.git
if [ $? -ne 0 ]; then
  echo "Failed to clone Kubernetes Goat. Exiting..."
  exit 1
fi
cd kubernetes-goat/ || exit
echo "Setting up Kubernetes Goat..."
bash setup-kubernetes-goat.sh
if [ $? -ne 0 ]; then
  echo "Failed to set up Kubernetes Goat. Exiting..."
  exit 1
fi

# Step 4: Access Kubernetes Goat
echo "Accessing Kubernetes Goat..."
bash access-kubernetes-goat.sh
if [ $? -ne 0 ]; then
  echo "Failed to access Kubernetes Goat. Exiting..."
  exit 1
fi

elif [ "$operation" == "delete" ]; then
  # Navigate to Kubernetes Goat directory
  if [ -d "$k8s_goat_dir" ]; then
	cd "$k8s_goat_dir" || exit
	# Run the teardown script for Kubernetes Goat
	echo "Running teardown for Kubernetes Goat..."
	bash teardown-kubernetes-goat.sh
	if [ $? -ne 0 ]; then
	  echo "Failed to teardown Kubernetes Goat. Exiting..."
	  exit 1
	fi
	cd - || exit
  else
	echo "Kubernetes Goat directory does not exist. Skipping teardown..."
  fi

  # Delete the EKS cluster
  echo "Deleting EKS cluster named $cluster_name..."
  eksctl delete cluster --name "$cluster_name" --region eu-central-1
  echo "Don't forget to remove the local copy of the kubernetes-goat directory!"
else
  # This part is technically unreachable due to the earlier checks
  echo "Unknown operation. Exiting..."
  exit 1
fi

echo "Script completed."
