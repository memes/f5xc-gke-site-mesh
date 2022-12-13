GENERATED_DIR := ../generated
FOUNDATIONS_JSON := $(GENERATED_DIR)/foundations.json

.DEFAULT: apply

.PHONY: apply
apply: $(FOUNDATIONS_JSON)
	terraform init -input=false
	terraform apply -auto-approve -input=false \
		-var foundations_json=$<

.PHONY: delete
delete: $(FOUNDATIONS_JSON)
	terraform destroy -auto-approve -input=false \
		-var foundations_json=$<

.PHONY: clean
clean: delete

.PHONY: realclean
realclean: clean
