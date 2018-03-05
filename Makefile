NAMESPACE = manage-f

# Identifies the docker image that will be built and deployed.
DOCKER_ACCOUNT ?= aljesusg

# SETTINGS BUILD
BUILD_NAME = managef_api
BUILD_WORKER_NAME = managef_worker

#DOCKER SETTINGS
DOCKER_NAME ?= ${DOCKER_ACCOUNT}/${BUILD_NAME}
DOCKER_WORKER_NAME ?= ${DOCKER_ACCOUNT}/${BUILD_WORKER_NAME}
DOCKER_VERSION ?= dev
DOCKER_WORKER_VERSION ?=dev
DOCKER_TAG = ${DOCKER_NAME}:${DOCKER_VERSION}

CONSOLE_VERSION ?= latest
CONSOLE_LOCAL_DIR ?= ../../../../ui

# Indicates the log level the app will use when started.
# <4=INFO
#  4=DEBUG
#  5=TRACE
VERBOSE_MODE ?= 4

all: build


build:
	@echo Building...
	cd ${GOPATH}/src/github.com/managef/models && make build
	cd ${GOPATH}/src/github.com/managef/api && make build
	cd ${GOPATH}/src/github.com/managef/worker && make build


install:
	@echo Installing...
	cd ${GOPATH}/src/github.com/managef/api && make dep-install dep-update
	cd ${GOPATH}/src/github.com/managef/worker && make dep-install dep-update

docker:
	@echo Build Docker...
	cd ${GOPATH}/src/github.com/managef/api && make docker
	cd ${GOPATH}/src/github.com/managef/worker && make docker

minikube-docker:
	@echo Build MiniKube Docker...
	cd ${GOPATH}/src/github.com/managef/api && make minikube-docker
	cd ${GOPATH}/src/github.com/managef/worker && make minikube-docker

.openshift-validate:
	@oc get project ${NAMESPACE} > /dev/null

openshift-deploy: openshift-undeploy
	@if ! which envsubst > /dev/null 2>&1; then echo "You are missing 'envsubst'. Please install it and retry. If on MacOS, you can get this by installing the gettext package"; exit 1; fi
	@echo Deploying to OpenShift project ${NAMESPACE}
	oc create -f deploy/openshift/managef-configmap.yaml -n ${NAMESPACE}
	cat deploy/openshift/managef.yaml | IMAGE_WORKER_NAME=${DOCKER_WORKER_NAME} IMAGE_WORKER_VERSION=${DOCKER_WORKER_VERSION} IMAGE_NAME=${DOCKER_NAME} IMAGE_VERSION=${DOCKER_VERSION} NAMESPACE=${NAMESPACE} VERBOSE_MODE=${VERBOSE_MODE} envsubst | oc create -n ${NAMESPACE} -f -

openshift-undeploy: .openshift-validate
	@echo Undeploying from OpenShift project ${NAMESPACE}
	oc delete all,secrets,sa,templates,configmaps,deployments,clusterroles,clusterrolebindings,services --selector=project=mf -n ${NAMESPACE}

openshift-reload-image: .openshift-validate
	@echo Refreshing image in OpenShift project ${NAMESPACE}
	oc delete pod --selector=project=mf -n ${NAMESPACE}

.k8s-validate:
	@kubectl get namespace ${NAMESPACE} > /dev/null

k8s-deploy: k8s-undeploy
	@echo Deploying to Kubernetes namespace ${NAMESPACE}
	kubectl create -f deploy/kubernetes/managef-configmap.yaml -n ${NAMESPACE}
	cat deploy/kubernetes/managef.yaml | IMAGE_WORKER_NAME=${DOCKER_WORKER_NAME} IMAGE_WORKER_VERSION=${DOCKER_WORKER_VERSION} IMAGE_NAME=${DOCKER_NAME} IMAGE_VERSION=${DOCKER_VERSION} NAMESPACE=${NAMESPACE} VERBOSE_MODE=${VERBOSE_MODE} envsubst | kubectl create -n ${NAMESPACE} -f -

k8s-undeploy:
	@echo Undeploying from Kubernetes namespace ${NAMESPACE}
	kubectl delete all,secrets,sa,configmaps,deployments,ingresses,clusterroles,clusterrolebindings --selector=project=mf -n ${NAMESPACE}

k8s-reload-image: .k8s-validate
	@echo Refreshing image in Kubernetes namespace ${NAMESPACE}
	kubectl delete pod --selector=project=mf -n ${NAMESPACE}