ROLLOUTS_DEMO_NS=rollouts-demo-gitops
SLEEP_SECONDS=20

echo "Fetching cluster subdomain"
export SUB_DOMAIN=$(oc get ingress.config.openshift.io cluster -n openshift-ingress -o jsonpath='{.spec.domain}')
echo "SUB_DOMAIN=${SUB_DOMAIN}"

echo "Getting remote URL for repo"
export GIT_REPO=$(git config --get remote.origin.url)
echo "GIT_REPO=${GIT_REPO}"

echo "Create namespaces"
oc apply -k infra/namespaces/base

echo "Create and configure istio-system and istio-cni"
oc apply -l infra/istio/base

# echo "Authorize monitoring for rollouts analysis"
# oc apply -k infra/auth-monitoring/base

echo "Add cluster scoped RolloutsManager"
oc apply -k infra/gitops/base

echo "Create rollouts GitOps instance"
# echo "Create default instance of gitops operator"
kustomize build environments/overlays/gitops | envsubst \$SUB_DOMAIN,\$GIT_REPO | oc apply -f -

echo "Pause $SLEEP_SECONDS seconds for the creation of the ${ROLLOUTS_DEMO_NS} instance..."
sleep $SLEEP_SECONDS

echo "Waiting for all pods to be created"
deployments=(argocd-dex-server argocd-redis argocd-repo-server argocd-server)
for i in "${deployments[@]}";
do
  echo "Waiting for deployment $i";
  oc rollout status deployment $i -n $ROLLOUTS_DEMO_NS
done

echo "Install applications and pipelines"
kustomize build argocd/base --enable-helm | envsubst \$SUB_DOMAIN,\$GIT_REPO | oc apply -f -
