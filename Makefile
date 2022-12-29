GENERATED_DIR := $(realpath ./generated)
FOUNDATIONS_JSON := $(GENERATED_DIR)/foundations.json
SUBS := application f5xc-site f5xc-full-site-mesh-group service-discovery

.DEFAULT: foundations

.PHONY: all
all: $(filter-out service-discovery, $(SUBS)) .WAIT service-discovery

.PHONY: $(SUBS)
$(SUBS): $(FOUNDATIONS_JSON)
	$(MAKE) -C $@ GENERATED_DIR=$(GENERATED_DIR) FOUNDATIONS_JSON=$(FOUNDATIONS_JSON)

.PHONY: foundations
foundations: $(FOUNDATIONS_JSON)

$(FOUNDATIONS_JSON): $(wildcard foundations/*.tf foundations/*.tfvars $(addsuffix /*,$(addprefix foundations/templates/,$(SUBS))))
	terraform -chdir=foundations init -input=false
	terraform -chdir=foundations apply -input=false -auto-approve -target=random_pet.prefix
	terraform -chdir=foundations apply -input=false -auto-approve

.PHONY: clean.%
clean.%:
	$(MAKE) -C $* clean GENERATED_DIR=$(GENERATED_DIR) FOUNDATIONS_JSON=$(FOUNDATIONS_JSON)

reverse = $(shell printf "%s\n" $(strip $1) | tac)
.PHONY: clean
clean: $(call reverse,$(addprefix clean.,$(SUBS)))

.PHONY: destroy
destroy: clean
	if test -d foundations/.terraform; then \
		terraform -chdir=foundations destroy -input=false -auto-approve; \
	fi

# WARNING: Nuke target attempts to delete all Terraform state, plugins, and
# locks, and deletes any remaining generated files. Be sure that the deployment
# has been cleaned up and that destroy target is not failing in a weird way. Any
# deployments or infrastructure remaining will have to be manually removed from
# GCP and/or F5XC.
.PHONY: nuke
nuke: destroy
	if test -d $(GENERATED_DIR); then find $(GENERATED_DIR) -depth 1 -type d -exec rm -rf {} +; fi
	find . -type d -name .terraform -exec rm -rf {} +
	find . -type d -name terraform.tfstate.d -exec rm -rf {} +
	find . -type f -name .terraform.lock.hcl -exec rm -f {} +
	find . -type f -name terraform.tfstate -exec rm -f {} +
	find . -type f -name terraform.tfstate.backup -exec rm -f {} +
