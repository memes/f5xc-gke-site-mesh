GENERATED_DIR := $(realpath ../generated)
FOUNDATIONS_JSON := $(GENERATED_DIR)/foundations.json

.DEFAULT: apply

.PHONY: apply
apply: $(FOUNDATIONS_JSON)
	terraform init -input=false
	terraform apply -auto-approve -input=false \
		-var foundations_json=$<

.PHONY: delete
delete:
	if test -f $(FOUNDATIONS_JSON) && test -d .terraform; then \
		terraform destroy -auto-approve -input=false \
			-var foundations_json=$(FOUNDATIONS_JSON) ; \
	fi

.PHONY: clean
clean: delete

# Try to warn if a missing dependency has not been created
$(FOUNDATIONS_JSON):
	@echo Foundations are not in place
	@false
