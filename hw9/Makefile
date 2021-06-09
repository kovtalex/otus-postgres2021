INSTANCE_COUNT=4

.PHONY: infra-deploy

infra-deploy:
	cd ./terraform; \
	tflint; \
	terraform validate; \
	terraform plan; \
	terraform apply -auto-approve -var="instance_count=${INSTANCE_COUNT}"

infra-destroy:
	cd ./terraform; \
	terraform destroy -auto-approve

infra-ip:
	cd ./terraform; \
	terraform output

postgres-deploy:
	cd ansible; \
	ansible-inventory -i inventory.gcp.yml --graph; \
	ansible-playbook playbook.yml
