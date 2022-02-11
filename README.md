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
minikube start  --disk-size=50g   --insecure-registry='10.0.0.0/24' 
minikube addons enable registry

kubectl apply -f https://github.com/knative/serving/releases/download/knative-v1.2.0/serving-crds.yaml \
  -f  https://github.com/knative/eventing/releases/download/knative-v1.2.0/eventing-crds.yaml

```
All Knative Serving resources will be under the API group called serving.knative.dev.
```bash
kubectl api-resources --api-group='serving.knative.dev'

NAME             SHORTNAMES      APIVERSION                    NAMESPACED   KIND
configurations   config,cfg      serving.knative.dev/v1        true         Configuration
domainmappings   dm              serving.knative.dev/v1beta1   true         DomainMapping
revisions        rev             serving.knative.dev/v1        true         Revision
routes           rt              serving.knative.dev/v1        true         Route
services         kservice,ksvc   serving.knative.dev/v1        true         Service
```
All Knative Eventing resources will be under the one of following API groups:

* messaging.knative.dev
* eventing.knative.dev
* sources.knative.dev

  * messaging.knative.dev
```bash
kubectl api-resources --api-group='messaging.knative.dev'

NAME            SHORTNAMES   APIVERSION                 NAMESPACED   KIND
channels        ch           messaging.knative.dev/v1   true         Channel
subscriptions   sub          messaging.knative.dev/v1   true         Subscription
```
  *   eventing.knative.dev
```bash
kubectl api-resources --api-group='eventing.knative.dev'

NAME         SHORTNAMES   APIVERSION                     NAMESPACED   KIND
brokers                   eventing.knative.dev/v1        true         Broker
eventtypes                eventing.knative.dev/v1beta1   true         EventType
triggers                  eventing.knative.dev/v1        true         Trigger
```
  *   sources.knative.dev
```bash
kubectl api-resources --api-group='sources.knative.dev'

NAME               SHORTNAMES   APIVERSION               NAMESPACED   KIND
apiserversources                sources.knative.dev/v1   true         ApiServerSource
containersources                sources.knative.dev/v1   true         ContainerSource
pingsources                     sources.knative.dev/v1   true         PingSource
sinkbindings                    sources.knative.dev/v1   true         SinkBinding
```
The Knative has two main infrastructure components: controller and webhook helps in translating the Knative CRDs which are usually written YAML files, into Kubernetes objects like Deployment and Service. Apart from the controller and webhook, the Knative Serving and Eventing also install their respective functional components which are listed in the upcoming sections.

### Install Knative Serving Core
[refer redhat](https://redhat-developer-demos.github.io/knative-tutorial/knative-tutorial/setup/minikube.html#install-knative-serving)   
[refer official site](https://knative.dev/docs/install/serving/install-serving-with-yaml/#install-a-networking-layer)
```bash
kubectl apply -f  \
  https://github.com/knative/serving/releases/download/knative-v1.2.0/serving-core.yaml
```
Wait for the Knative Serving deployment to complete:
```bash
kubectl rollout status deploy controller -n knative-serving
kubectl rollout status deploy activator -n knative-serving
kubectl rollout status deploy autoscaler -n knative-serving
kubectl rollout status deploy webhook -n knative-serving
```
### Knative serve - Install-a-networking-layer
[refer official site](https://knative.dev/docs/install/serving/install-serving-with-yaml/#install-a-networking-layer)

####  Install Kourier Ingress Gateway
```bash
kubectl apply  -f  \
    https://github.com/knative/net-kourier/releases/download/knative-v1.2.0/kourier.yaml
```
Wait for the Ingress Gateway deployment to complete:
```bash
kubectl rollout status deploy 3scale-kourier-control -n knative-serving
kubectl rollout status deploy 3scale-kourier-gateway -n kourier-system
```
A successful Kourier Ingress Gateway should show the following pods in kourier-system and knative-serving:
```bash
kubectl get pods --all-namespaces -l 'app in(3scale-kourier-gateway,3scale-kourier-control)'

NAMESPACE        NAME                                     READY   STATUS    RESTARTS   AGE
kourier-system   3scale-kourier-gateway-bf9cb68c8-h7gwn   1/1     Running   0          47s
```
Now configure Knative serving to use Kourier as the ingress:
```bash
kubectl patch configmap/config-network \
  -n knative-serving \
  --type merge \
  -p '{"data":{"ingress.class":"kourier.ingress.networking.knative.dev"}}'
```
#### Install and Configure Ingress Controller
[refer redhat](https://redhat-developer-demos.github.io/knative-tutorial/knative-tutorial/setup/minikube.html#install-ingress-controller)   
To access the Knative Serving services from the minikube host, it will be easier to have [Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/) deployed and configured.

The following section will install and configure [Contour](https://projectcontour.io/) as the Ingress Controller.
```bash
kubectl apply -f  https://projectcontour.io/quickstart/contour.yaml
```
Wait for the Ingress to be deployed and running:
```bash
kubectl rollout status ds envoy -n projectcontour
kubectl rollout status deploy contour -n projectcontour
```
A successful rollout should list the following pods in projectcontour
```bash
kubectl get pods -n projectcontour

NAME                            READY   STATUS      RESTARTS   AGE
contour-79bdf94f8-n48dp         1/1     Running     0          25m
contour-79bdf94f8-wc26t         1/1     Running     0          25m
contour-certgen-v1.20.0-t952h   0/1     Completed   0          25m
envoy-bb6lc                     2/2     Running     0          25m
```
Now create an Ingress to Kourier Ingress Gateway:
```bash
cat <<EOF | kubectl apply -n kourier-system -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: kourier-ingress
  namespace: kourier-system
spec:
  rules:
  - http:
     paths:
       - path: /
         pathType: Prefix
         backend:
           service:
             name: kourier
             port:
               number: 80
EOF
```
Configure Knative to use the kourier-ingress Gateway:
```bash
export ksvc_domain="\"data\":{\""$(minikube   ip)".nip.io\": \"\"}"

kubectl patch configmap/config-domain \
    -n knative-serving \
    --type merge \
    -p "{$ksvc_domain}"
```
You can inspect ingres controller or svc
```bash
kubectl get svc -A
NAMESPACE          NAME                         TYPE           CLUSTER-IP       EXTERNAL-IP   PORT(S)                           AGE
default            kubernetes                   ClusterIP      10.96.0.1        <none>        443/TCP                           54m
knative-eventing   broker-filter                ClusterIP      10.100.70.42     <none>        80/TCP,9092/TCP                   36s
knative-eventing   broker-ingress               ClusterIP      10.104.148.203   <none>        80/TCP,9092/TCP                   36s
knative-eventing   eventing-webhook             ClusterIP      10.109.100.10    <none>        443/TCP                           37s
knative-eventing   imc-dispatcher               ClusterIP      10.96.0.187      <none>        80/TCP,9090/TCP                   37s
knative-eventing   inmemorychannel-webhook      ClusterIP      10.111.238.0     <none>        443/TCP,9090/TCP,8008/TCP         37s
knative-serving    activator-service            ClusterIP      10.108.95.116    <none>        9090/TCP,8008/TCP,80/TCP,81/TCP   45m
knative-serving    autoscaler                   ClusterIP      10.96.222.99     <none>        9090/TCP,8008/TCP,8080/TCP        45m
knative-serving    autoscaler-bucket-00-of-01   ClusterIP      10.108.149.185   <none>        8080/TCP                          45m
knative-serving    controller                   ClusterIP      10.108.146.103   <none>        9090/TCP,8008/TCP                 45m
knative-serving    domainmapping-webhook        ClusterIP      10.100.32.171    <none>        9090/TCP,8008/TCP,443/TCP         45m
knative-serving    net-kourier-controller       ClusterIP      10.103.22.118    <none>        18000/TCP                         43m
knative-serving    webhook                      ClusterIP      10.100.52.173    <none>        9090/TCP,8008/TCP,443/TCP         45m
kourier-system     kourier                      LoadBalancer   10.99.122.131    <pending>     80:32043/TCP,443:30926/TCP        43m
kourier-system     kourier-internal             ClusterIP      10.107.240.200   <none>        80/TCP                            43m
kube-system        kube-dns                     ClusterIP      10.96.0.10       <none>        53/UDP,53/TCP,9153/TCP            54m
kube-system        registry                     ClusterIP      10.110.234.67    <none>        80/TCP,443/TCP                    53m
projectcontour     contour                      ClusterIP      10.103.82.216    <none>        8001/TCP                          35m
projectcontour     envoy                        LoadBalancer   10.97.202.130    <pending>     80:30643/TCP,443:31979/TCP        35m

```
####  Install Istio Ingress Gateway
```bash
kubectl apply -l knative.dev/crd-install=true -f https://github.com/knative/net-istio/releases/download/knative-v1.2.0/istio.yaml
kubectl apply -f https://github.com/knative/net-istio/releases/download/knative-v1.2.0/istio.yaml

kubectl apply -f https://github.com/knative/net-istio/releases/download/knative-v1.2.0/net-istio.yaml

kubectl --namespace istio-system get service istio-ingressgateway
```
#### Install Minikube LoadBalancer
You can use metallb
```bash
minikube addons enable metallb
```
You have to specific IP address range as Minikube (minikube ip)
```bash
minikube addons configure metallb
-- Enter Load Balancer Start IP: 192.168.59.200
-- Enter Load Balancer End IP: 192.168.59.210
  - Using image metallb/controller:v0.9.6
  - Using image metallb/speaker:v0.9.6
* metallb was successfully configured
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
## Install Knative Eventing
[refence redhat](https://redhat-developer-demos.github.io/knative-tutorial/knative-tutorial/setup/minikube.html#install-knative-eventing)  
[refence github](https://github.com/knative/eventing)  
[refer official site](https://knative.dev/docs/install/eventing/install-eventing-with-yaml/#install-knative-eventing)

```bash
kubectl apply \
  -f \
  https://github.com/knative/eventing/releases/download/knative-v1.2.0/eventing-crds.yaml \
  -f \
  https://github.com/knative/eventing/releases/download/knative-v1.2.0/eventing-core.yaml \
  -f \
  https://github.com/knative/eventing/releases/download/knative-v1.2.0/in-memory-channel.yaml \
  -f \
  https://github.com/knative/eventing/releases/download/knative-v1.2.0/mt-channel-broker.yaml
```