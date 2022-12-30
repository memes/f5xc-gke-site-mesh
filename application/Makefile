GENERATED_DIR := $(realpath ../generated)
FOUNDATIONS_JSON := $(GENERATED_DIR)/foundations.json
KEYS := $(shell test -f $(FOUNDATIONS_JSON) && jq -r '.clusters//{}|keys|.[]' $(FOUNDATIONS_JSON))

.DEFAULT: apply

.PHONY: apply
apply: $(addprefix apply.,$(KEYS))

.PHONY: apply.%
apply.%: $(GENERATED_DIR)/%/kubeconfig.yaml $(GENERATED_DIR)/%/application/kustomization.yaml
	kustomize build $(word 2,$(^D)) | kubectl --kubeconfig $< apply -f -

.PHONY: delete.%
delete.%:
	if test -f $(GENERATED_DIR)/$*/kubeconfig.yaml && test -f $(GENERATED_DIR)/$*/application/kustomization.yaml; then \
		kustomize build $(GENERATED_DIR)/$*/application | kubectl --kubeconfig $(GENERATED_DIR)/$*/kubeconfig.yaml delete -f - || true ; \
	fi

.PHONY: clean
clean: $(addprefix delete.,$(KEYS))

# Try to warn if a missing dependency has not been created
$(GENERATED_DIR)/%/kubeconfig.yaml:
	@echo Foundations are not in place
	@false

$(GENERATED_DIR)/%/application/kustomization.yaml:
	@echo Foundations are not in place
	@false
