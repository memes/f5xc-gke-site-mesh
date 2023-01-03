GENERATED_DIR := $(realpath ../generated)
FOUNDATIONS_JSON := $(GENERATED_DIR)/foundations.json
KEYS := $(shell test -f $(FOUNDATIONS_JSON) && jq -r '.clusters//{}|keys|.[]' $(FOUNDATIONS_JSON))

.NOTPARALLEL:

.DEFAULT: all

.PHONY: all
all: apply register

.PHONY: apply
apply: $(addprefix apply.,$(KEYS))

.PHONY: apply.%
apply.%: $(GENERATED_DIR)/%/kubeconfig.yaml $(GENERATED_DIR)/%/f5xc-site/kustomization.yaml $(GENERATED_DIR)/%/f5xc-site/resourcegroup.yaml
	kustomize build $(word 2,$(^D)) | kpt live apply --kubeconfig $< --reconcile-timeout=15m -

.PRECIOUS: $(GENERATED_DIR)/%/f5xc-site/resourcegroup.yaml
$(GENERATED_DIR)/%/f5xc-site/resourcegroup.yaml: $(GENERATED_DIR)/%/kubeconfig.yaml
	kpt live init --kubeconfig $< $(@D)

.PHONY: register
register: $(addprefix register.,$(KEYS))

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

.PHONY: delete
delete: $(addprefix delete.,$(KEYS))

.PHONY: delete.%
delete.%:
	if test -f $(GENERATED_DIR)/$*/kubeconfig.yaml && test -f $(GENERATED_DIR)/$*/f5xc-site/kustomization.yaml && test -f $(GENERATED_DIR)/$*/f5xc-site/resourcegroup.yaml; then \
		kustomize build $(GENERATED_DIR)/$*/f5xc-site | kpt live destroy --kubeconfig $(GENERATED_DIR)/$*/kubeconfig.yaml - ;\
	fi

.PHONY: unregister
unregister: $(addprefix unregister.,$(KEYS))

.PHONY: unregister.%
unregister.%:
	if test -f $(FOUNDATIONS_JSON) && test -d .terraform; then \
		terraform workspace select $* && \
			terraform destroy -auto-approve -input=false \
				-var foundations_json=$(FOUNDATIONS_JSON) \
				-var key=$* ; \
		terraform workspace select default ; \
	fi

.PHONY: clean
clean: unregister delete
	if test -d $(GENERATED_DIR); then \
		find $(GENERATED_DIR) -depth 3 -type f -name resourcegroup.yaml -exec rm -f {} + ; \
	fi

# Try to warn if a missing dependency has not been created
$(GENERATED_DIR)/%/kubeconfig.yaml:
	@echo Foundations are not in place
	@false

$(GENERATED_DIR)/%/f5xc-site/kustomization.yaml:
	@echo Foundations are not in place
	@false

$(FOUNDATIONS_JSON):
	@echo Foundations are not in place
	@false
