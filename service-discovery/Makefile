GENERATED_DIR := ../generated
FOUNDATIONS_JSON := $(GENERATED_DIR)/foundations.json
KEYS := $(shell jq -r '.clusters//{}|keys|.[]' < $(FOUNDATIONS_JSON))

.DEFAULT: all

.PHONY: all
all: $(addprefix apply.,$(KEYS))

.PHONY: apply.%
apply.%: $(GENERATED_DIR)/%/kubeconfig.yaml $(GENERATED_DIR)/%/service-discovery/kustomization.yaml $(FOUNDATIONS_JSON)
	vesctl configuration get site --namespace system \
		$(shell jq -r '.clusters.$*.name' <  $(FOUNDATIONS_JSON)) >/dev/null 2>&1 \
		|| (echo "F5 XC site for $* hasn't been created" && false)
	kustomize build $(word 2,$(^D)) | kubectl --kubeconfig $< apply -f -
	terraform init -input=false
	terraform workspace new $* || terraform workspace select $*
	terraform apply -auto-approve -input=false \
		-var foundations_json=$(FOUNDATIONS_JSON) \
		-var kubeconfig=$< \
		-var key=$* \
		$(shell kustomize build $(word 2,$(^D)) | yq eval --no-doc 'select(.kind=="Secret")|.metadata|"-var service_account=" + .annotations."kubernetes.io/service-account.name" + " -var secret_namespace=" + .namespace + " -var secret_name=" + .name')
	terraform workspace select default

.PHONY: delete.%
delete.%: $(GENERATED_DIR)/%/kubeconfig.yaml $(GENERATED_DIR)/%/service-discovery/kustomization.yaml $(FOUNDATIONS_JSON)
	-kustomize build $(word 2,$(^D)) | kubectl --kubeconfig $< delete -f -
	-terraform workspace select $* && \
		terraform destroy -auto-approve -input=false \
			-var foundations_json=$(FOUNDATIONS_JSON) \
			-var kubeconfig=$< \
			-var key=$* \
			$(shell kustomize build $(word 2,$(^D)) | yq eval --no-doc 'select(.kind=="Secret")|.metadata|"-var service_account=" + .annotations."kubernetes.io/service-account.name" + " -var secret_namespace=" + .namespace + " -var secret_name=" + .name')
	terraform workspace select default

.PHONY: clean
clean: $(addprefix delete.,$(KEYS))

.PHONY: realclean
realclean: clean
