GENERATED_DIR := generated
FOUNDATIONS_JSON := $(GENERATED_DIR)/foundations.json

.PHONY: all
all: echoserver f5xc-full-site-mesh-group f5xc-site

.PHONY: echoserver
echoserver: $(FOUNDATIONS_JSON)
	$(MAKE) -C echoserver

.PHONY: f5xc-full-site-mesh-group
f5xc-full-site-mesh-group: $(FOUNDATIONS_JSON)
	$(MAKE) -C f5xc-full-site-mesh-group

.PHONY: f5xc-site
f5xc-site: $(FOUNDATIONS_JSON)
	$(MAKE) -C f5xc-site

.PHONY: service-discovery
service-discovery: $(FOUNDATIONS_JSON)
	$(MAKE) -C service-discovery

.PHONY: foundations
foundations: $(FOUNDATIONS_JSON)

$(FOUNDATIONS_JSON): $(wildcard foundations/*.tf) $(wildcard foundations/templates/*) $(wildcard foundations/*.tfvars)
	terraform -chdir=foundations init -input=false
	terraform -chdir=foundations apply -input=false -auto-approve

.PHONY: clean
clean:
	$(MAKE) -C service-discovery clean
	$(MAKE) -C f5xc-site clean
	$(MAKE) -C f5xc-full-site-mesh-group clean
	$(MAKE) -C echoserver clean
	terraform -chdir=foundations destroy -input=false -auto-approve

.PHONY: realclean
realclean:
	$(MAKE) -C service-discovery realclean
	$(MAKE) -C f5xc-site realclean
	$(MAKE) -C f5xc-full-site-mesh-group realclean
	$(MAKE) -C echoserver realclean
	if test -d $(GENERATED_DIR); then find $(GENERATED_DIR) -depth 1 -type d -exec rm -rf {} +; fi
	find . -type d -name .terraform -exec rm -rf {} +
	find . -type d -name terraform.tfstate.d -exec rm -rf {} +
	find . -type f -name .terraform.lock.hcl -exec rm -f {} +
	find . -type f -name terraform.tfstate -exec rm -f {} +
	find . -type f -name terraform.tfstate.backup -exec rm -f {} +
