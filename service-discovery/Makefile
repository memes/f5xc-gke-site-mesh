GENERATED_DIR := $(realpath ../generated)
FOUNDATIONS_JSON := $(GENERATED_DIR)/foundations.json
KEYS := $(shell test -f $(FOUNDATIONS_JSON) && jq -r '.clusters//{}|keys|.[]' $(FOUNDATIONS_JSON))

.NOTPARALLEL:

.DEFAULT: all

.PHONY: all
all: apply

.PHONY: apply
apply: $(addprefix apply.,$(KEYS))

.PHONY: apply.%
apply.%: $(GENERATED_DIR)/%/kubeconfig.yaml $(GENERATED_DIR)/%/service-discovery/kustomization.yaml $(FOUNDATIONS_JSON)
	vesctl configuration get site --namespace system \
		$(shell jq -r '.clusters."$*".name' <  $(FOUNDATIONS_JSON)) >/dev/null 2>&1 \
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

.PHONY: delete
delete: $(addprefix delete.,$(KEYS))

.PHONY: delete.%
delete.%:
	if test -f $(GENERATED_DIR)/$*/kubeconfig.yaml && test -f $(GENERATED_DIR)/$*/service-discovery/kustomization.yaml; then \
		kustomize build $(GENERATED_DIR)/$*/service-discovery | kubectl --kubeconfig $(GENERATED_DIR)/$*/kubeconfig.yaml delete -f - ; \
		if test -f $(FOUNDATIONS_JSON) && test -d .terraform; then \
			terraform workspace select $* && \
				terraform destroy -auto-approve -input=false \
					-var foundations_json=$(FOUNDATIONS_JSON) \
					-var kubeconfig=$(GENERATED_DIR)/$*/kubeconfig.yaml \
					-var key=$* \
					$(shell kustomize build $(GENERATED_DIR)/$*/service-discovery | yq eval --no-doc 'select(.kind=="Secret")|.metadata|"-var service_account=" + .annotations."kubernetes.io/service-account.name" + " -var secret_namespace=" + .namespace + " -var secret_name=" + .name') ; \
			terraform workspace select default; \
		fi ; \
	fi

.PHONY: clean
clean: delete

# Try to warn if a missing dependency has not been created
$(GENERATED_DIR)/%/kubeconfig.yaml:
	@echo Foundations are not in place
	@false

$(GENERATED_DIR)/%/service-discovery/kustomization.yaml:
	@echo Foundations are not in place
	@false

$(FOUNDATIONS_JSON):
	@echo Foundations are not in place
	@false
