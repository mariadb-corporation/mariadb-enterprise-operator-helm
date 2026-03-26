#!/bin/bash

#==============================================================================
# MariaDB Enterpries Operator Data Collection Script
# Dependencies:
# - kubectl
# - Relevant permissions for MariaDB Namespace and Enterprise Operator Namespace
#==============================================================================

usage() {
  echo "Usage: $0 <mariadb-namespace> <operator-namespace>"
  echo
  echo "Arguments:"
  echo "  <mariadb-namespace>  : The namespace where MariaDB resources are deployed."
  echo "  <operator-namespace> : The namespace where the MariaDB Enterprise Operator is running."
  echo
  echo "Example:"
  echo "  $0 my-app-namespace mariadb-enterprise-operator-system"
  echo
  echo "Tips:"
  echo "  - The following script can be used for community as well as enterprise"
  exit 1
}

if [ "$#" -ne 2 ]; then
    echo "Error: Incorrect number of arguments."
    usage
fi

MARIADB_NAMESPACE=$1
OPERATOR_NAMESPACE=$2
SUPPORT_DIR="mariadb_support_$(date +%Y-%m-%d_%H-%M-%S)"
ARCHIVE_NAME="${SUPPORT_DIR}.tar.gz"

mkdir -p "$SUPPORT_DIR"

echo "Starting MariaDB Operator Data Collection..."
echo "Log files will be saved in: $SUPPORT_DIR"
echo "Target MariaDB Namespace: $MARIADB_NAMESPACE"
echo "Target Operator Namespace: $OPERATOR_NAMESPACE"
echo "----------------------------------------------------------------------"

echo "[1/6] Collecting current namespace state (all resources)..."
{
    kubectl get all -n "$MARIADB_NAMESPACE"
    echo ""
    echo "--- PVC ---"
    kubectl get pvc -n "$MARIADB_NAMESPACE" 2>/dev/null
} > "${SUPPORT_DIR}/${MARIADB_NAMESPACE}_all.log"

echo "[2/6] Collecting resource details..."
kubectl get statefulset -o yaml -n "$MARIADB_NAMESPACE" > "${SUPPORT_DIR}/${MARIADB_NAMESPACE}_statefulsets.yaml" 2>/dev/null || echo "  -> No StatefulSets found."
kubectl get pod -o yaml -n "$MARIADB_NAMESPACE" > "${SUPPORT_DIR}/${MARIADB_NAMESPACE}_pods.yaml" 2>/dev/null || echo "  -> No Pods found."
kubectl get service -o yaml -n "$MARIADB_NAMESPACE" > "${SUPPORT_DIR}/${MARIADB_NAMESPACE}_services.yaml" 2>/dev/null || echo "  -> No Services found."
kubectl get pvc -o yaml -n "$MARIADB_NAMESPACE" > "${SUPPORT_DIR}/${MARIADB_NAMESPACE}_pvcs.yaml" 2>/dev/null || echo "  -> No PVCs found."
kubectl get pdb -o yaml -n "$MARIADB_NAMESPACE" > "${SUPPORT_DIR}/${MARIADB_NAMESPACE}_pdbs.yaml" 2>/dev/null || echo "  -> No PodDisruptionBudgets found."

if kubectl get crd volumesnapshots.snapshot.storage.k8s.io &> /dev/null; then
  kubectl get volumesnapshot -o yaml -n "$MARIADB_NAMESPACE" > "${SUPPORT_DIR}/${MARIADB_NAMESPACE}_volumesnapshots.yaml" 2>/dev/null || echo "  -> No VolumeSnapshots found."
fi

echo "[3/6] Collecting logs from all pods and containers in '$MARIADB_NAMESPACE'..."
for p in $(kubectl get pods -n "$MARIADB_NAMESPACE" -o name); do
  for c in $(kubectl get "$p" -n "$MARIADB_NAMESPACE" -o jsonpath='{.spec.containers[*].name}'); do
    # Strip the 'pod/' prefix for a cleaner filename
    pod_name=$(echo "$p" | sed 's#pod/##')
    kubectl logs "$p" -c "$c" -n "$MARIADB_NAMESPACE" > "${SUPPORT_DIR}/${MARIADB_NAMESPACE}-${pod_name}-${c}.log"
  done
done

echo "[4/6] Extracting Kubernetes events sorted by creation timestamp..."
kubectl get events --sort-by='.metadata.creationTimestamp' -n "$MARIADB_NAMESPACE" > "${SUPPORT_DIR}/${MARIADB_NAMESPACE}_events.log"

echo "[5/6] Extracting Operator Custom Resources..."
kubectl get mariadb -o yaml -n "$MARIADB_NAMESPACE" > "${SUPPORT_DIR}/${MARIADB_NAMESPACE}_mariadbs.yaml" 2>/dev/null || echo "  -> No MariaDB custom resources found."
kubectl get maxscale -o yaml -n "$MARIADB_NAMESPACE" > "${SUPPORT_DIR}/${MARIADB_NAMESPACE}_maxscales.yaml" 2>/dev/null || echo "  -> No MaxScale custom resources found."
kubectl get backup -o yaml -n "$MARIADB_NAMESPACE" > "${SUPPORT_DIR}/${MARIADB_NAMESPACE}_backups.yaml" 2>/dev/null || echo "  -> No Backup custom resources found."
kubectl get physicalbackup -o yaml -n "$MARIADB_NAMESPACE" > "${SUPPORT_DIR}/${MARIADB_NAMESPACE}_physicalbackups.yaml" 2>/dev/null || echo "  -> No PhysicalBackup custom resources found."

# Community interop
if kubectl get crd pointintimerecoveries.k8s.mariadb.com &> /dev/null || kubectl get crd pointintimerecoveries.enterprise.mariadb.com &> /dev/null; then
  kubectl get pitr -o yaml -n "$MARIADB_NAMESPACE" > "${SUPPORT_DIR}/${MARIADB_NAMESPACE}_pitrs.yaml" 2>/dev/null || echo "  -> No PointInTimeRecovery custom resources found."
fi

echo "[6/6] Extracting Operator logs from '$OPERATOR_NAMESPACE'..."
kubectl get deployments -n "$OPERATOR_NAMESPACE" 
read -p "Please enter the Deployment name for the MariaDB Enterprise Operator from the list above [mariadb-enterprise-operator]: " OPERATOR_DEPLOY_NAME
OPERATOR_DEPLOY_NAME=${OPERATOR_DEPLOY_NAME:-mariadb-enterprise-operator}
kubectl logs deployment/${OPERATOR_DEPLOY_NAME} -n "$OPERATOR_NAMESPACE" > "${SUPPORT_DIR}/${OPERATOR_NAMESPACE}_operator.log" 2>/dev/null || echo "  -> Operator deployment logs not found in $OPERATOR_NAMESPACE."

echo "----------------------------------------------------------------------"
echo "📋 Please provide the following environment details:"
read -p "Kubernetes version: " K8S_VERSION
read -p "Kubernetes distribution (Vanilla, OpenShift, EKS, GKE, AKS, etc.): " K8S_DISTRO
read -p "MariaDB Operator version: " OPERATOR_VERSION
read -p "MariaDB Server version: " MARIADB_VERSION
read -p "MariaDB topology (Replication, Galera, Standalone): " MARIADB_TOPOLOGY
read -p "MaxScale version: " MAXSCALE_VERSION
read -p "Install method (Helm, OLM): " INSTALL_METHOD
read -p "Air-Gapped (Yes, No): " AIR_GAPPED
if [[ "${K8S_DISTRO,,}" == "openshift" ]]; then
    read -p "(Optional) OpenShift version: " OCP_VERSION
    read -p "(Optional) OpenShift channel: " OCP_CHANNEL
fi

cat <<EOF > "${SUPPORT_DIR}/environment_details.txt"
Kubernetes version: ${K8S_VERSION:-"Not provided"}
Kubernetes distribution: ${K8S_DISTRO:-"Not provided"}
MariaDB Operator version: ${OPERATOR_VERSION:-"Not provided"}
MariaDB Server version: ${MARIADB_VERSION:-"Not provided"}
MariaDB topology: ${MARIADB_TOPOLOGY:-"Not provided"}
MaxScale version: ${MAXSCALE_VERSION:-"Not provided"}
Install method: ${INSTALL_METHOD:-"Not provided"}
Air-Gapped: ${AIR_GAPPED:-"Not provided"}
(Optional) OpenShift version: ${OCP_VERSION:-"Not provided"}
(Optional) OpenShift channel: ${OCP_CHANNEL:-"Not provided"}
EOF

echo "----------------------------------------------------------------------"
echo "📦 Creating archive: ${ARCHIVE_NAME}..."
tar -czf "${ARCHIVE_NAME}" "${SUPPORT_DIR}"

echo "🧹 Cleaning up temporary directory..."
rm -rf "${SUPPORT_DIR}"

echo "----------------------------------------------------------------------"
echo "✅ Data collection complete!"
echo "======================================================================"