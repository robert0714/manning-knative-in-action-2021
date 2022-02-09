# Chapter 5 Autoscaling
## 5.7 Configuring autoscaling
So far, in this chapter, I’ve gone over the Autoscaler’s behavior in some basic scenarios, then followed with a tour of the inner workings. I’ve given you two passes at understanding it. But there are gaps in these accounts. A survey of the Autoscaler’s knobs allows me to fill in gaps without having to add even more digressions to the narrative discussions.
So far, in this chapter, I’ve gone over the Autoscaler’s behavior in some basic scenarios, then followed with a tour of the inner workings. I’ve given you two passes at understanding it. But there are gaps in these accounts. A survey of the Autoscaler’s knobs allows me to fill in gaps without having to add even more digressions to the narrative discussions.

Most of the configuration settings I’ll discuss can either be set globally by an operator or set at a Configuration or Service by a developer. It’s best not to set things globally because everything under a given Knative Serving installation will be affected. And besides, the defaults are fairly sensible for most cases.

Put another way: My goal is to improve your understanding, not to encourage unnecessary changes. Naming and explaining a setting isn’t an endorsement of tinkering with it.

### 5.7.1 How settings get applied
The Autoscaler can receive settings via a number of means. One such means is to create a Kubernetes ConfigMap record in the knative-serving namespace, named config-autoscaler. It would look something like the following listing.

Listing 5.1 Config mapping in example.yaml
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: config-autoscaler
  namespace: knative-serving
data:
  enable-scale-to-zero: 'true'
```
The YAML in listing 5.1 can then be submitted with kubectl, as the next listing shows.

Listing 5.2 Setting the ConfigMap with kubectl
```bash
kn service create hello-example \
  --image gcr.io/knative-samples/helloworld-go \
  --env TARGET="First" 
 kubectl apply -f example.yaml
```
The warning here occurs because, in fact, the ``config-autoscaler ConfigMap`` is already present, but without any active settings on it.

A second means for setting configurations is annotations. These are the little key-value pairs that you can set on anything in Kubernetes, which means you can set these on a Configuration. Annotations are a mixed bag, by the way. On the upside, these provide a kind of dynamically-typed escape hatch from the schema of any Kubernetes record. On the downside, they ... well ... refer to the upside. One way to create and change annotations is with the ``kubectl annotate`` command, shown in the following listing.

Listing 5.3 Setting a /minScale with kubectl annotate
```bash
$ kubectl annotate revisions \
  hello-example-00001    \
  autoscaling.knative.dev/minScale=1
revision.serving.knative.dev/hello-example-00001 annotated
```
Actually, I don’t need ``kubectl`` for this, if I don’t want it. I can use ``kn`` instead, as in the following listing.  
Listing 5.4 Using kn to set /minScale
```bash
$  kn service update \
  hello-example \
  --annotation autoscaling.knative.dev/minScale=1

Updating Service 'hello-example' in namespace 'default':

  0.040s The Configuration is still working to reflect the latest desired specification.
  3.368s Traffic is not yet migrated to the latest revision.
  3.459s Ingress has not yet been reconciled.
  3.539s Waiting for load balancer to be ready
  3.701s Ready to serve.

Service 'hello-example' updated to latest revision 'hello-example-00002' is available at URL:
http://hello-example.default.192.168.59.201.sslip.io
```
Note that autoscaling annotations have the form autoscaling.knative.dev/<name>. For convenience, I’ll just refer to this with the shorthand /<name>.

### 5.7.2 Setting scaling limits
Autoscaling is always enabled, but you needn’t always scale to zero. You can disable that in two ways. The first is to use ``enable-scale-to-zero`` on the ``ConfigMap``. This is a fairly consequential decision, of course, because you’d be disabling it for *everyone*.

The alternative is setting a ``/minScale`` annotation on a Service or a Revision. In the previous section, I set it on the Revision by using ``kubectl`` and then ``kn``.

The minimum and maximum scale options are sufficiently likely to be used that ``kn`` allows you to set these at creation time or when updating a Service with ``--scale-min`` and ``--scale-max``. The following listing gives an example.

Listing 5.5 Using kn to set scaling limits
```bash
$  kn service update    hello-example    --scale-min 1    --scale-max 5
Updating Service 'hello-example' in namespace 'default':

  0.032s The Configuration is still working to reflect the latest desired specification.
  3.213s Traffic is not yet migrated to the latest revision.
  3.284s Ingress has not yet been reconciled.
  3.335s Waiting for load balancer to be ready
  3.550s Ready to serve.

Service 'hello-example' updated to latest revision 'hello-example-00003' is available at URL:
http://hello-example.default.192.168.59.201.sslip.io
```
Doing so creates a new Revision. You can use kn to see the scaling limits on a Revision as part of revision describe, as this listing shows.
```bash
$ kn revision describe hello-example-00003
Name:         hello-example-00003
Namespace:    default
Annotations:  autoscaling.knative.dev/max-scale=5, autoscaling.knative.dev/min-scale=1, autoscali ...
Age:          1m
Image:        gcr.io/knative-samples/helloworld-go (pinned to 5ea96b)
Replicas:     1/1
Env:          TARGET=First
Scale:        1 ... 5
Service:      hello-example

Conditions:
  OK TYPE                  AGE REASON
  ++ Ready                  1m
  ++ ContainerHealthy       1m
  ++ ResourcesAvailable     1m
  ++ Active                 1m
```
Note the ``Scale: 1 ... 5`` line in listing 5.6, showing the inclusive scaling range. You might also notice that the same information appears in ``Annotations`` as well.

I think it’s worth forming the view that these settings are really about economics rather than engineering. Setting ``/minScale`` is a statement of how much delay you can afford to tolerate, whereas ``/maxScale`` is a statement of how much capacity you can afford to carry.

You should consider using ``/minScale`` if you are sure that you can never allow a slow response due to a cold start. Otherwise, don’t. Using ``/maxScale`` is worth doing as a general policy, even if you set the value to an “impossible” level, such as 100 or 500 or 1,000—a level high enough to give you heartburn without seeming like something you will plausibly reach.

#### As they come around the bend ...

“But what about limitless scaling?” you ask, grimly clutching dim memories of Google blog posts. It’s true that given enough money and given enough cluster capacity, you might be well served in a sudden surge by allowing scaling to an unlimited level.

As an answer, I draw your eye to the odds board of those notoriously merciless bookies, Murphy & Sons, posted down at the Production Is Broken Racing Ground. For “sudden wave of interest and success,” Murphy & Sons have posted long odds of 200:1. This doesn’t happen often in practice and, when it does, you’ll probably hear about it.

For “bad person hates your guts,” our flint-eyed bookmakers have posted shorter odds of 50:1. And this situation favors using /maxScale, because it constrains the blast radius of a DDOS attack.

Finally, Murphy & Sons know the form and have posted short odds for the most likely case: “bug caused by mistake obvious only in hindsight” of just 3:1. If asked, they’ll explain that they’ve seen far more DDOSes caused by an infinite loop, suddenly enormous error log, suddenly large response size, escalating mutual deadlocks, and so on, than from any other action of Lady Fortune. “No need to worry about zebras,” they politely explain, “when a startled horse can trample you to death just as well.”

Here too, /maxScale can help. You reach a limit but you don’t exceed it. This gives you a sporting chance to at least rollback a version or two until things clear up, and it stops a single piece of software from choking something—your network, your cluster, your wallet perhaps—to death.

So whaddya reckon, punter? Feel like taking a flutter? Placeyerbets, place yer beeeets!