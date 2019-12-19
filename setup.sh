#!/bin/bash

KUBECONFIG="$(k3d get-kubeconfig --name='logging')"
export KUBECONFIG

if [[ $1 == "-b" ]]; then
  cd base-image
  make build-image
  cd ..

  cd config-reloader
  make build-image
  cd ..

  k3d i vmware/kube-fluentd-operator -n logging

  docker rm k3d-logging-tools
fi

mkdir -p .tmp

cat > .tmp/fluent.conf << EOF
<filter \$labels(app=podinfo)>
  @type parser
  reserve_data true
  remove_key_name_field true
  <parse>
    @type json
  </parse>
  key_name log
</filter>

<match **>
  @type loki
  url "http://grafana-loki:3100"
  extract_kubernetes_labels true
  <label>
    container \$.kubernetes.container_name
    pod \$.kubernetes.pod_name
    namespace \$.kubernetes.namespace_name
    host \$.kubernetes.host
  </label>
  #line_format "key_value"
  line_format json
  flush_interval 10s
  flush_at_shutdown true
  buffer_chunk_limit 1m
</match>
EOF

kubectl create configmap fluentd-config --namespace default --from-file=fluent.conf=.tmp/fluent.conf --dry-run -o yaml | kubectl apply -f -

rm .tmp/fluent.conf

cat > .tmp/fluent.conf << EOF
<match systemd.** docker>
  @type null
</match>
EOF

kubectl create configmap fluentd-config --namespace kube-system --from-file=fluent.conf=.tmp/fluent.conf --dry-run -o yaml | kubectl apply -f -

rm .tmp/fluent.conf

cat > .tmp/fluent.conf << EOF
<match **>
  @type loki
  url "http://grafana-loki:3100"
  extract_kubernetes_labels true
  remove_keys kubernetes
  label_keys \$.kubernetes.host
  <label>
    container \$.kubernetes.container_name
    pod \$.kubernetes.pod_name
    host \$.kubernetes.host
  </label>
  # line_format key_value
  line_format json
  flush_interval 10s
  flush_at_shutdown true
  buffer_chunk_limit 1m
</match>
EOF

kubectl create configmap fluentd-config --namespace monitoring --from-file=fluent.conf=.tmp/fluent.conf --dry-run -o yaml | kubectl apply -f -

rm .tmp/fluent.conf

rm -rf .tmp

kubectl annotate namespace default logging.csp.vmware.com/fluentd-configmap=fluentd-config --overwrite
kubectl annotate namespace kube-system logging.csp.vmware.com/fluentd-configmap=fluentd-config --overwrite
kubectl annotate namespace monitoring logging.csp.vmware.com/fluentd-configmap=fluentd-config --overwrite

helm upgrade --install log-router log-router/ \
  --namespace monitoring \
  --recreate-pods \
  --set image.repository=vmware/kube-fluentd-operator \
  --set image.pullPolicy=Never \
  --set image.tag=latest \
  --set rbac.create=true \
  --set logLevel=info
