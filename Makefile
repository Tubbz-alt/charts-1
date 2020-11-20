HELM_VERSION := v3.0.3
HELM_URL     := https://get.helm.sh
HELM_TGZ      = helm-${HELM_VERSION}-linux-amd64.tar.gz
YQ_VERSION   := 2.4.1
YAMLLINT_VERSION := 1.20.0
CHARTS := ecs-cluster objectscale-manager mongoose zookeeper-operator atlas-operator decks kahm dks-testapp fio-test sonobuoy dellemc-license service-pod objectscale-graphql helm-controller objectscale-vsphere iam pravega-operator bookkeeper-operator supportassist decks-support-store statefuldaemonset-operator
DECKSCHARTS := decks kahm supportassist service-pod dellemc-license decks-support-store
FLEXCHARTS := ecs-cluster objectscale-manager objectscale-vsphere objectscale-graphql helm-controller iam statefuldaemonset-operator
MONITORING_DIR := monitoring

# release version
PACKAGE_VERSION=0.54
FULL_PACKAGE_VERSION=${PACKAGE_VERSION}.0
FLEXVER=${FULL_PACKAGE_VERSION}
DECKSVER=2.${PACKAGE_VERSION}

GIT_COMMIT_COUNT=$(shell git rev-list HEAD | wc -l)
GIT_COMMIT_ID=$(shell git rev-parse HEAD)
GIT_COMMIT_SHORT_ID=$(shell git rev-parse --short HEAD)
GIT_BRANCH_ID=$(shell git rev-parse --abbrev-ref HEAD)

# packaging
MANAGER_MANIFEST    := objectscale-manager.yaml
KAHM_MANIFEST       := kahm.yaml
DECKS_MANIFEST      := decks.yaml
PACKAGE_NAME        := objectscale-charts-package.tgz
NAMESPACE            = dellemc-objectscale-system
TEMP_PACKAGE        := temp_package
SERVICE_ID           = objectscale
REGISTRY             = objectscale
DECKS_REGISTRY       = objectscale
KAHM_REGISTRY        = objectscale
STORAGECLASSNAME     = dellemc-objectscale-highly-available
STORAGECLASSNAME_VSAN_SNA     = dellemc-objectscale-vsan-sna-thick

WATCH_ALL_NAMESPACES = false # --set global.watchAllNamespaces={true | false}
HELM_MANAGER_ARGS    = # --set image.tag={YOUR_VERSION_HERE}
HELM_MONITORING_ARGS = # --set global.monitoring.tag=${YOUR_VERSION_HERE}
HELM_UI_ARGS         = # --set image.tag=${YOUR_VERSION_HERE}
HELM_GRAPHQL_ARGS    = # --set objectscale-graphql.tag=${YOUR_VERSION_HERE}
HELM_INSTALLER_ARGS  = # --set objectscale-graphql.helm-controller.tag=${YOUR_VERSION_HERE}
HELM_DECKS_ARGS      = # --set image.tag=${YOUR_VERSION_HERE}
HELM_KAHM_ARGS       = # --set image.tag=${YOUR_VERSION_HERE}
HELM_DECKS_SUPPORT_STORE_ARGS      = # --set decks-support-store.image.tag=${YOUR_VERSION_HERE}

clean: clean-package

all: test package

release: decksver flexver monitoringver build-all add-to-git

test: monitoring-test
	helm lint ${CHARTS} --set product=objectscale --set global.product=objectscale
	yamllint -c .yamllint.yml */Chart.yaml */values.yaml
	yamllint -c .yamllint.yml -s .yamllint.yml .travis.yml
	helm unittest ${CHARTS}

dep:
	wget -q ${HELM_URL}/${HELM_TGZ}
	tar xzf ${HELM_TGZ} -C /tmp --strip-components=1
	PATH=`pwd`/linux-amd64/:$PATH
	chmod +x /tmp/helm
	helm plugin list | grep -q "unittest" ; \
	if [ "$${?}" -eq "1" ] ; then \
		helm plugin install https://github.com/lrills/helm-unittest ; \
 	fi
	export PATH=$PATH:/tmp
	sudo pip install yamllint=="${YAMLLINT_VERSION}"
	sudo pip install yq=="${YQ_VERSION}"

decksver:
	if [ -z ${DECKSVER} ] ; then \
		echo "Missing DECKSVER= param" ; \
		exit 1 ; \
	fi

	echo "looking for yq command"
	which yq
	echo "Found it"
	for CHART in ${DECKSCHARTS}; do  \
		echo "Setting version ${DECKSVER} in $$CHART" ;\
		yq w -i $$CHART/Chart.yaml appVersion ${DECKSVER} ; \
		yq w -i $$CHART/Chart.yaml version ${DECKSVER} ; \
		echo -e "---\n`cat $$CHART/Chart.yaml`" > $$CHART/Chart.yaml ; \
		sed -i -e "0,/^tag.*/s//tag: ${DECKSVER}/"  $$CHART/values.yaml; \
	done ;

	for CHART in ${FLEXCHARTS} ${DECKSCHARTS}; do  \
		echo "Setting decs dep version ${DECKSVER} in $$CHART" ;\
		sed -i -e "/no_auto_change__decks_auto_change/s/version:.*/version: ${DECKSVER} # no_auto_change__decks_auto_change/g"  $$CHART/Chart.yaml; \
	done ;

flexver:
	if [ -z ${FLEXVER} ] ; then \
		echo "Missing FLEXVER= param" ; \
		exit 1 ; \
	fi
	echo "looking for yq command"
	which yq
	echo "Found it"
	for CHART in ${FLEXCHARTS}; do  \
		echo "Setting version $$FLEXVER in $$CHART" ;\
		yq w -i $$CHART/Chart.yaml appVersion ${FLEXVER} ; \
		sed -i -e "/no_auto_change/!s/version:.*/version: ${FLEXVER}/g"  $$CHART/Chart.yaml; \
		echo -e "---\n`cat $$CHART/Chart.yaml`" > $$CHART/Chart.yaml ; \
		sed -i -e "0,/^tag.*/s//tag: ${FLEXVER}/"  $$CHART/values.yaml; \
	done ;

build-all: monitoring-dep build

build:
	@echo "looking for yq command"
	which yq
	@echo "Ensure no helm repo accessible"
	helm repo list | grep .; \
        if [ $${?} -eq 0 ]; then exit 1; fi
	REINDEX=0; \
	for CHART in ${CHARTS}; do \
		CURRENT_VER=`yq r $$CHART/Chart.yaml version` ; \
		yq r docs/index.yaml "entries.$${CHART}[*].version" | grep -q "\- $${CURRENT_VER}$$" ; \
		if [ "$${?}" -eq "1" ] || [ "$${REBUILDHELMPKG}" ] ; then \
		    echo "Updating package for $${CHART}" ; \
		    helm dep update $${CHART}; \
			helm package $${CHART} --destination docs ; \
			REINDEX=1 ; \
		else  \
		    echo "Packages for $${CHART} are up to date" ; \
		fi ; \
	done ; \
	if [ "$${REINDEX}" -eq "1" ]; then \
		cd docs && helm repo index . ; \
	fi

add-to-git:
	for CHART in ${CHARTS}; do \
		if [ -d "$${CHART}/charts" ]; then \
			echo "Adding charts to git for $${CHART}" ; \
			git add $${CHART}/charts; \
		fi; \
	done ; \
	echo "Adding docs to git" ; \
	git add docs; \

package: clean-package create-temp-package create-manifests combine-crds create-vmware-package archive-package
create-temp-package:
	mkdir -p ${TEMP_PACKAGE}/yaml
	mkdir -p ${TEMP_PACKAGE}/scripts


combine-crds:
	cp -R objectscale-manager/crds ${TEMP_PACKAGE}
	cp -R atlas-operator/crds ${TEMP_PACKAGE}
	cp -R zookeeper-operator/crds ${TEMP_PACKAGE}
	cp -R kahm/crds ${TEMP_PACKAGE}
	cp -R decks/crds ${TEMP_PACKAGE}
	cp -R statefuldaemonset-operator/crds ${TEMP_PACKAGE}
	cat ${TEMP_PACKAGE}/crds/*.yaml > ${TEMP_PACKAGE}/yaml/objectscale-crd.yaml
	## Remove # from crd to prevent app-platform from crashing in 7.0P1
	sed -i -e "/^#.*/d" ${TEMP_PACKAGE}/yaml/objectscale-crd.yaml
	rm -rf ${TEMP_PACKAGE}/crds

create-vmware-package:
	./vmware/vmware_pack.sh ${SERVICE_ID}

create-manifests: create-vsphere-install create-kahm-manifest create-decks-app create-manager-app

create-vsphere-install: create-vsphere-templates

create-manager-app: create-temp-package
	# cd in makefiles spawns a subshell, so continue the command with ;
	#
	# Run helm template with monitoring.enabled=false to not pollute
	# nautilus.dellemc.com/chart-values of objectscale-manager with tons of default values
	# from child charts. After that replace this value by sed.
	cd objectscale-manager; \
	helm template --show-only templates/objectscale-manager-app.yaml objectscale-manager ../objectscale-manager  -n ${NAMESPACE} \
	--set global.platform=VMware \
	--set global.watchAllNamespaces=${WATCH_ALL_NAMESPACES} \
	--set global.registry=${REGISTRY} \
	--set global.storageClassName=${STORAGECLASSNAME} \
	--set logReceiver.create=true --set logReceiver.type=Syslog \
	--set logReceiver.persistence.storageClassName=${STORAGECLASSNAME} \
	--set global.monitoring_registry=${REGISTRY} \
	--set ecs-monitoring.influxdb.persistence.storageClassName=${STORAGECLASSNAME} \
	--set global.monitoring.enabled=false \
	--set objectscale-monitoring.influxdb.persistence.storageClassName=${STORAGECLASSNAME_VSAN_SNA} \
	--set objectscale-monitoring.rsyslog.persistence.storageClassName=${STORAGECLASSNAME_VSAN_SNA} \
	--set iam.enabled=false ${HELM_MANAGER_ARGS} ${HELM_MONITORING_ARGS} \
	-f values.yaml > ../${TEMP_PACKAGE}/yaml/objectscale-manager-app.yaml;
	sed -i 's/createApplicationResource\\":true/createApplicationResource\\":false/g' ${TEMP_PACKAGE}/yaml/objectscale-manager-app.yaml && \
	sed -i 's/\\"monitoring\\":{\\"enabled\\":false}/\\"monitoring\\":{\\"enabled\\":true}/g' ${TEMP_PACKAGE}/yaml/objectscale-manager-app.yaml && \
	sed -i 's/app.kubernetes.io\/managed-by: Helm/app.kubernetes.io\/managed-by: nautilus/g' ${TEMP_PACKAGE}/yaml/objectscale-manager-app.yaml
	cat ${TEMP_PACKAGE}/yaml/objectscale-manager-app.yaml >> ${TEMP_PACKAGE}/yaml/${MANAGER_MANIFEST} && rm ${TEMP_PACKAGE}/yaml/objectscale-manager-app.yaml

create-vsphere-templates: create-temp-package
	helm template vsphere-plugin ./objectscale-vsphere -n ${NAMESPACE} \
	--set global.platform=VMware \
	--set global.watchAllNamespaces=${WATCH_ALL_NAMESPACES} \
    --set graphql.enabled=true \
	--set global.registry=${REGISTRY} \
	--set global.storageClassName=${STORAGECLASSNAME} ${HELM_UI_ARGS} ${HELM_GRAPHQL_ARGS} ${HELM_INSTALLER_ARGS} \
	-f objectscale-vsphere/values.yaml >> ${TEMP_PACKAGE}/yaml/${MANAGER_MANIFEST}

create-kahm-manifest: create-temp-package
	helm template kahm ./kahm -n ${NAMESPACE} --set global.platform=VMware \
	--set global.watchAllNamespaces=${WATCH_ALL_NAMESPACES} --set global.registry=${KAHM_REGISTRY} ${HELM_KAHM_ARGS} \
	--set storageClassName=${STORAGECLASSNAME} -f kahm/values.yaml >> ${TEMP_PACKAGE}/yaml/${KAHM_MANIFEST}

create-decks-app: create-temp-package
	# cd in makefiles spawns a subshell, so continue the command with ;
	cd decks; \
	helm template --show-only templates/decks-app.yaml decks ../decks  -n ${NAMESPACE} \
	--set global.platform=VMware \
	--set global.watchAllNamespaces=${WATCH_ALL_NAMESPACES} \
	--set global.registry=${DECKS_REGISTRY} \
	--set decks-support-store.persistentVolume.storageClassName=${STORAGECLASSNAME} \
        ${HELM_DECKS_ARGS} ${HELM_DECKS_SUPPORT_STORE_ARGS} \
	-f values.yaml > ../${TEMP_PACKAGE}/yaml/decks-app.yaml;
	sed -i 's/createdecksappResource\\":true/createdecksappResource\\":false/g' ${TEMP_PACKAGE}/yaml/decks-app.yaml && \
	sed -i 's/app.kubernetes.io\/managed-by: Helm/app.kubernetes.io\/managed-by: nautilus/g' ${TEMP_PACKAGE}/yaml/decks-app.yaml
	cat ${TEMP_PACKAGE}/yaml/decks-app.yaml >> ${TEMP_PACKAGE}/yaml/${DECKS_MANIFEST} && rm ${TEMP_PACKAGE}/yaml/decks-app.yaml
archive-package:
	tar -zcvf ${PACKAGE_NAME} ${TEMP_PACKAGE}/*

clean-package:
	rm -rf temp_package ${PACKAGE_NAME}

combine-crd-manager-ci: create-temp-package
	cp -R objectscale-manager/crds ${TEMP_PACKAGE}
	cp -R atlas-operator/crds ${TEMP_PACKAGE}
	cp -R zookeeper-operator/crds ${TEMP_PACKAGE}
	cp -R statefuldaemonset-operator/crds ${TEMP_PACKAGE}
	cat ${TEMP_PACKAGE}/crds/*.yaml > ${TEMP_PACKAGE}/yaml/manager-crd.yaml
	rm -rf ${TEMP_PACKAGE}/crds

create-manager-manifest-ci: create-temp-package
	helm template objectscale-manager ./objectscale-manager -n ${NAMESPACE} \
	--set global.platform=Default --set global.watchAllNamespaces=${WATCH_ALL_NAMESPACES} \
	--set global.registry=${REGISTRY} \
	--set global.storageClassName=${STORAGECLASSNAME} \
	--set logReceiver.create=false \
	-f objectscale-manager/values.yaml >> ${TEMP_PACKAGE}/yaml/${MANAGER_MANIFEST}

monitoring-test:
	make -C ${MONITORING_DIR} test
	git checkout -- monitoring 

monitoring-dep:
	make -C ${MONITORING_DIR} dep

monitoringver:
	make -C ${MONITORING_DIR} ver PACKAGE_VERSION=${FULL_PACKAGE_VERSION}

build-installer:
	echo "Copy charts to container and build image"
	docker pull asdrepo.isus.emc.com:8099/install-controller:green
	docker create --name installer-container asdrepo.isus.emc.com:8099/install-controller:green
	docker cp ./docs installer-container:/docs
	docker commit installer-container asdrepo.isus.emc.com:8099/install-controller:${FULL_PACKAGE_VERSION}-$(GIT_COMMIT_COUNT).$(GIT_COMMIT_SHORT_ID)
	docker push asdrepo.isus.emc.com:8099/install-controller:${FULL_PACKAGE_VERSION}-$(GIT_COMMIT_COUNT).$(GIT_COMMIT_SHORT_ID)
	docker rm installer-container
	docker rmi asdrepo.isus.emc.com:8099/install-controller:green

tag-push-installer:
	docker tag asdrepo.isus.emc.com:8099/install-controller:${FULL_PACKAGE_VERSION}-$(GIT_COMMIT_COUNT).$(GIT_COMMIT_SHORT_ID) asdrepo.isus.emc.com:8099/install-controller:${FULL_PACKAGE_VERSION}
	docker push asdrepo.isus.emc.com:8099/install-controller:${FULL_PACKAGE_VERSION}
