#!/bin/bash


apply_sticky_pod_settings() {

    echo "Applying stick-pod settings"
    authYaml="/tmp/new-auth-svc.yaml"
    cat <<'EOA' > $authYaml
apiVersion: v1
kind: Service
metadata:
  name: kube-apiserver-authproxy-svc
  namespace: kube-system
spec:
  ports:
  - name: nginx
    port: 443
    protocol: TCP
    targetPort: 443
  - name: kube-apiserver
    port: 6443
    protocol: TCP
    targetPort: 6443
  selector:
    component: kube-apiserver
    fix: sticky-pod
  type: LoadBalancer
EOA

    kubectl -n kube-system apply -f $authYaml
    ## its ok to re-apply if its already there. it'll return unchanged.

    ## Now get the first kube-apiserver and apply the stick-pod label:
    apiserver=$(kubectl get pod -l component=kube-apiserver --no-headers -o name -n kube-system | head -1 | sed s%^pod/%%)

    echo "Setting the label on pod: $apiserver"
    kubectl -n kube-system label pod $apiserver fix=sticky-pod
}

apply_sticky_pod_settings

