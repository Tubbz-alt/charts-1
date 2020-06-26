#!/usr/bin/env bash


## extract the version from objectscale-manager 
objs_ver=$(grep appVersion: objectscale-manager/Chart.yaml | sed -e "s/.*: //g")

vsphere7_plugin_file="objectscale-${objs_ver}-vmware-config-map.yaml"

cat <<EOT >> temp_package/${vsphere7_plugin_file}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: objectscale
  namespace: kube-system
  labels:
    appplatform.vmware.com/kind: supervisorservice
data:
  objectscale-crd.yaml: |-
$(awk '{printf "%4s%s\n", "", $0}' temp_package/objectscale-crd.yaml)
  objectscale-operator.yaml: |-
$(awk '{printf "%4s%s\n", "", $0}' temp_package/objectscale-manager.yaml)
$(awk '{printf "%4s%s\n", "", $0}' temp_package/kahm.yaml)
$(awk '{printf "%4s%s\n", "", $0}' temp_package/decks.yaml)
  objectscale.yaml: |-
    apiVersion: appplatform.wcp.vmware.com/v1alpha1
    kind: SupervisorService
    metadata:
      labels:
        controller-tools.k8s.io: "1.0"
      name: objectscale
      namespace: "kube-system"
    spec:
      serviceId: dellemc-objectscale
      label: "Dell EMC ObjectScale"
      description: |
        Dell EMC ObjectScale is a dynamically scalable, secure, and multi-tenant object storage platform
        for on-premises and cloud use cases.  It supports advanced storage functionality including
        comprehensive S3 support, flexible erasure-coding, data-at-rest encryption, compression,
        and scales capacity and performance linearly.
      versions: ["${objs_ver}"]
      enabled: false
      eula: |+
        $(sed "s/^/        /" ./dellemc_eula.txt)
EOT

# Remove trailing whitespaace
sed -i 's/[[:space:]]*$//' temp_package/${vsphere7_plugin_file}
