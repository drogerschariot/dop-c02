.PHONY: plan apply destroy init


ifneq (,$(wildcard ../../.env))
include ../../.env
export
endif

plan: init
	terraform plan

apply: init
	terraform apply

destroy: init
	terraform destroy

init:
	terraform init --upgrade
