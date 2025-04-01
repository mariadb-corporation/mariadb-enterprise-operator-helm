#!/bin/bash

set -eo pipefail

if [ -z "$RESOURCE" ]; then
    echo "Error: RESOURCE enviroiment variable is not set."
    exit 1
fi
if [ -z "$OLD_API_GROUP" ]; then
    echo "Error: OLD_API_GROUP enviroiment variable is not set."
    exit 1
fi
if [ -z "$NEW_API_GROUP" ]; then
    echo "Error: NEW_API_GROUP enviroiment variable is not set."
    exit 1
fi
if [ -z "$NEW_MARIADB_IMAGE" ]; then
    echo "Error: NEW_MARIADB_IMAGE enviroiment variable is not set."
    exit 1
fi
if [ -z "$NEW_MARIADB_OPERATOR_IMAGE" ]; then
    echo "Error: NEW_MARIADB_OPERATOR_IMAGE enviroiment variable is not set."
    exit 1
fi

OLD_RESOURCE="community.$RESOURCE.yaml"
NEW_RESOURCE="enterprise.$RESOURCE.yaml"
NEW_RESOURCE_STATUS="status.$RESOURCE.yaml"
OLD_API="mariadbs.$OLD_API_GROUP"
NEW_API="mariadbs.$NEW_API_GROUP"

YQ=/tmp/yq
function setup_yq() {
  OS=$(uname -s | tr '[:upper:]' '[:lower:]')
  ARCH=$(uname -m)
  case $ARCH in
    x86_64)
      ARCH="amd64"
      ;;
    aarch64|arm64|armv8)
      ARCH="arm64"
      ;;
    i386)
      ARCH="386"
      ;;
    *)
      echo "Unsupported architecture: $ARCH" >&2
      exit 1
      ;;
  esac

  YQ_VERSION="4.45.1"
  YQ_BINARY="yq_${OS}_${ARCH}"
  YQ_DOWNLOAD_URL="https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/${YQ_BINARY}"

  echo "Downloading yq version ${YQ_VERSION}..."
  if ! wget -q "$YQ_DOWNLOAD_URL" -O "$YQ"; then
    echo "Failed to download yq binary." >&2
    exit 1
  fi

  chmod +x "$YQ"
}

if command -v yq &> /dev/null; then
  YQ=$(command -v yq)
  echo "yq is already installed. Using the current installation: $YQ"
else
  echo "Setting up yq..."
  setup_yq
  echo "Installed yq: $YQ"
fi

"$YQ" --version

echo "Getting \"$OLD_API\" resource..."
kubectl get "$OLD_API" "$RESOURCE" -o yaml > "$OLD_RESOURCE"

echo "Migrating from \"$OLD_API\" to \"$NEW_API\"..."

cp "$OLD_RESOURCE" "$NEW_RESOURCE"
"$YQ" eval "
  .apiVersion = \"$NEW_API_GROUP/v1alpha1\" |
  .spec.image = \"$NEW_MARIADB_IMAGE\"
" -i "$NEW_RESOURCE"

GALERA_ENABLED=$("$YQ" eval ".spec.galera != null and .spec.galera.enabled == true" "$OLD_RESOURCE")
if [ "$GALERA_ENABLED" = "true" ]; then
  echo "Migrating Galera fields..."
  "$YQ" eval "
    .spec.galera.initContainer.image = \"$NEW_MARIADB_OPERATOR_IMAGE\" |
    .spec.galera.agent.image = \"$NEW_MARIADB_OPERATOR_IMAGE\" |
    .spec.galera.galeraLibPath = \"/usr/lib64/galera/libgalera_enterprise_smm.so\" |
    .spec.galera.clusterName = \"mariadb-operator\"
  " -i "$NEW_RESOURCE"
fi

METRICS_ENABLED=$("$YQ" eval ".spec.metrics != null and .spec.metrics.enabled == true" "$OLD_RESOURCE")
if [ "$METRICS_ENABLED" = "true" ]; then
  echo "Migrating metrics fields..."
  "$YQ" eval '
    .spec.metrics.exporter.image = "mariadb/mariadb-prometheus-exporter-ubi:v0.0.2"
  ' -i "$NEW_RESOURCE"
fi

cp "$OLD_RESOURCE" "$NEW_RESOURCE_STATUS"
"$YQ" eval '. |= pick(["status"])' -i "$NEW_RESOURCE_STATUS"

echo "Creating \"$NEW_API\" resource..."
kubectl apply -f "$NEW_RESOURCE"
kubectl patch "$NEW_API" "$RESOURCE" --subresource status --type merge -p "$(cat "$NEW_RESOURCE_STATUS")"

echo "Patching StatefulSet ownerReferences..."
MARIADB_UID=$(kubectl get "$NEW_API" "$RESOURCE" -o jsonpath="{.metadata.uid}")
kubectl patch statefulset "$RESOURCE" --type=json -p="[
  {\"op\": \"replace\", \"path\": \"/metadata/ownerReferences/0/apiVersion\", \"value\": \"${NEW_API_GROUP}/v1alpha1\"}, 
  {\"op\": \"replace\", \"path\": \"/metadata/ownerReferences/0/uid\", \"value\": \"${MARIADB_UID}\"}
]"

rm "$NEW_RESOURCE" "$NEW_RESOURCE_STATUS"
echo "Done!"