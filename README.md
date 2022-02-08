# manning-knative-in-action-2021
## Install Kapp
### Via chocolatey (windows)
Install binaries :
```bash
$ choco install kapp
``` 
### Via script (macOS or Linux)
Install binaries into specific directory:
```bash
$ mkdir local-bin/
$ curl -L https://carvel.dev/install.sh | K14SIO_INSTALL_BIN_DIR=local-bin bash

$ export PATH=$PWD/local-bin/:$PATH
$ kapp version
``` 

Or system wide:
```bash
$ wget -O- https://carvel.dev/install.sh > install.sh
```
### Via Homebrew (macOS or Linux)
```bash
$ brew tap vmware-tanzu/carvel
$ brew install kapp
$ kapp version
```
 
## Install ytt

### Via chocolatey (windows)
Install binaries :
```bash
$ choco install ytt
``` 
### Via script (macOS or Linux)
Install binaries into specific directory:
```bash
$ mkdir local-bin/
$ curl -L https://carvel.dev/install.sh | K14SIO_INSTALL_BIN_DIR=local-bin bash

$ export PATH=$PWD/local-bin/:$PATH
$ ytt version
``` 

Or system wide:
```bash
$ wget -O- https://carvel.dev/install.sh > install.sh

# Inspect install.sh before running...
$ sudo bash install.sh
$ ytt version
```
### Via Homebrew (macOS or Linux)
```bash
$ brew tap vmware-tanzu/carvel
$ brew install ytt
$ ytt version
```

## Install Knative client
https://github.com/knative/client
https://github.com/knative/client/blob/main/docs/README.md

### Via Homebrew (macOS or Linux)
```bash
brew tap knative/client
brew install kn
```

## Install Knative serve
[refence redhat](https://redhat-developer-demos.github.io/knative-tutorial/knative-tutorial/setup/minikube.html)  
[refence github](https://github.com/knative/serving)  
[refer official site](https://knative.dev/docs/install/serving/install-serving-with-yaml)

```bash
minikube addons enable registry

kubectl apply \
  --filename https://github.com/knative/serving/releases/download/knative-v1.2.0/serving-crds.yaml \
  --filename https://github.com/knative/eventing/releases/download/knative-v1.2.0/eventing-crds.yaml

kubectl api-resources --api-group='serving.knative.dev'
```

### Knative serve - Install-a-networking-layer
[refer official site](https://knative.dev/docs/install/serving/install-serving-with-yaml/#install-a-networking-layer)

```bash
kubectl apply -l knative.dev/crd-install=true -f https://github.com/knative/net-istio/releases/download/knative-v1.2.0/istio.yaml
kubectl apply -f https://github.com/knative/net-istio/releases/download/knative-v1.2.0/istio.yaml

kubectl apply -f https://github.com/knative/net-istio/releases/download/knative-v1.2.0/net-istio.yaml

kubectl --namespace istio-system get service istio-ingressgateway
```

### Knative serve - Configure-dns
[refer official site](https://knative.dev/docs/install/serving/install-serving-with-yaml/#configure-dns)

```bash
kubectl apply -f https://github.com/knative/serving/releases/download/knative-v1.2.0/serving-default-domain.yaml
```
### Knative serve - Example
[refer official site](https://github.com/csantanapr/knative-minikube#deploy-knative-serving-application)

```bash
kn service create hello-example \
  --image gcr.io/knative-samples/helloworld-go \
  --env TARGET="First" 

kn service list

kn service list -o json |jq -r ".items[0].status.url"

curl  $(kn service list -o json |jq -r ".items[0].status.url")

```
