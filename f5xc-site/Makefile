GENERATED_DIR := ../generated
FOUNDATIONS_JSON := $(GENERATED_DIR)/foundations.json
KEYS := $(shell jq -r '.clusters//{}|keys|.[]' < $(FOUNDATIONS_JSON))

.DEFAULT: all

.PHONY: all
all: $(addprefix apply.,$(KEYS)) $(addprefix register.,$(KEYS))

.PHONY: apply.%
apply.%: $(GENERATED_DIR)/%/kubeconfig.yaml $(GENERATED_DIR)/%/f5xc-site/kustomization.yaml $(GENERATED_DIR)/%/f5xc-site/resourcegroup.yaml
	kustomize build $(word 2,$(^D)) | kpt live apply --kubeconfig $< --reconcile-timeout=15m -

.PRECIOUS: $(GENERATED_DIR)/%/f5xc-site/resourcegroup.yaml
$(GENERATED_DIR)/%/f5xc-site/resourcegroup.yaml: $(GENERATED_DIR)/%/kubeconfig.yaml
	kpt live init --kubeconfig $< $(@D)

.PHONY: register.%
register.%: $(GENERATED_DIR)/%/kubeconfig.yaml $(GENERATED_DIR)/%/f5xc-site/kustomization.yaml $(FOUNDATIONS_JSON)
	kubectl --kubeconfig $< wait --timeout 120s --for jsonpath='{.status.readyReplicas}'=3 \
		statefulset/$(shell kustomize build $(word 2,$(^D)) | yq eval --no-doc 'select(.kind=="StatefulSet")|.metadata|.name + " --namespace " + .namespace')
	terraform init -input=false
	terraform workspace new $* || terraform workspace select $*
	terraform apply -auto-approve -input=false \
		-var foundations_json=$(FOUNDATIONS_JSON) \
		-var key=$*
	terraform workspace select default

.PHONY: delete.%
delete.%: $(GENERATED_DIR)/%/kubeconfig.yaml $(GENERATED_DIR)/%/f5xc-site/kustomization.yaml
	-kustomize build $(word 2,$(^D)) | kpt live destroy --kubeconfig $< -

.PHONY: unregister.%
unregister.%: $(GENERATED_DIR)/%/kubeconfig.yaml $(GENERATED_DIR)/%/f5xc-site/kustomization.yaml $(FOUNDATIONS_JSON)
	-terraform workspace select $* && \
		terraform destroy -auto-approve -input=false \
		-var foundations_json=$(FOUNDATIONS_JSON) \
		-var key=$*
	terraform workspace select default

.PHONY: clean
clean: $(addprefix unregister.,$(KEYS)) $(addprefix delete.,$(KEYS))
	if test -d $(GENERATED_DIR); then find $(GENERATED_DIR) -depth 3 -type f -name resourcegroup.yaml -exec rm -f {} +; fi

.PHONY: realclean
realclean: clean
