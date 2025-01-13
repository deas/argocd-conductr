#!/bin/sh

target=apply

echo "$target" | figlet | lolcat
sleep 2
make -C tf "$target"
echo "Ready deployment,sts,ds" | figlet | lolcat
sleep 2
# watch -n 10 "kubectl get deployments,ds --all-namespaces -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,REPLICAS:.status.replicas,READY:.status.readyReplicas --no-headers | awk '$3==$4' | awk '{ print $2 }' | tr '\n' ' '"
watch -n 10 'kubectl get deployments,ds --all-namespaces -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,REPLICAS:.status.replicas,READY:.status.readyReplicas --no-headers | awk \$3==\$4 | awk "{ print\$2 }" | sort | tr "\n" " "'
