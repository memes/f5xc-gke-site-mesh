GENERATED_DIR := ../generated
FOUNDATIONS_JSON := $(GENERATED_DIR)/foundations.json
KEYS := $(shell jq -r '.clusters//{}|keys|.[]' < $(FOUNDATIONS_JSON))

.DEFAULT: apply

.PHONY: apply
apply: $(addprefix apply.,$(KEYS))

.PHONY: apply.%
apply.%: $(GENERATED_DIR)/%/kubeconfig.yaml $(GENERATED_DIR)/%/echoserver/kustomization.yaml
	kustomize build $(word 2,$(^D)) | kubectl --kubeconfig $< apply -f -

.PHONY: delete.%
delete.%: $(GENERATED_DIR)/%/kubeconfig.yaml $(GENERATED_DIR)/%/echoserver/kustomization.yaml
	-kustomize build $(word 2,$(^D)) | kubectl --kubeconfig $< delete -f -

.PHONY: clean
clean: $(addprefix delete.,$(KEYS))

.PHONY: realclean
realclean: clean
