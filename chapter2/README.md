# Chapter 2 Introducing Knative Serving

## A walkthrough
In this section, I’ll use ``kn`` exclusively to demonstrate some Knative Serving capabilities. I assume you’ve installed it, following the directions in appendix A.

``kn`` is the “official” CLI for Knative, but it wasn’t the first. Before it came along there were a number of alternatives, such as ``knctl``. These tools helped to explore different approaches to a CLI experience for Knative.

``kn`` serves two purposes. The first is a CLI in itself, specifically intended for Knative rather than requiring users to anxiously skitter around kubectl, pretending that Kubernetes isn’t right there. The secondary purpose is to drive out Golang APIs for Knative, which can be used by other tools to interact with Knative from within Go programs.

### Your first deployment
Let’s first use ``kn service list`` to ensure you’re in a clean state. You should see No Services Found as the response. Now we can create a Service using ``kn service create``. The listing shows the basics of how to use kn to create Services.

Listing 2.1 Using kn to create our first Service
```bash
$ kn service create hello-example \                                    ❶
  --image gcr.io/knative-samples/helloworld-go \                       ❷
  --env TARGET="First"                                                 ❸
                                                                       ❹
Creating service 'hello-example' in namespace 'default':
 
  0.084s The Route is still working to reflect the latest desired specification.
  0.260s Configuration "hello-example" is waiting for a Revision to become ready.
  4.356s ...
  4.762s Ingress has not yet been reconciled.
  6.104s Ready to serve.
 
Service 'hello-example' created with latest revision 'hello-example-00001' and URL: http://hello-example.example.com                          ❺
```
❶ Names the service

❷ References the container image. In this case, we use a sample app image provided by Knative.

❸ Injects an environment variable that’s consumed by the sample app

❹ Monitors the deployment process and emits logs

❺ Returns the URL for the newly deployed software

```bash
kn service create hello-example \
  --image gcr.io/knative-samples/helloworld-go \
  --env TARGET="First" 
```

The logs emitted by ``kn`` refer to concepts I discussed in chapter 1. The Service you provide is split into a Configuration and a Route. The Configuration creates a Revision. The Revision needs to be ready before the Route can attach Ingress to it, and Ingress needs to be ready before traffic can be served at the URL.

This dance illustrates how hierarchical control breaks your high-level intentions into particular software to be configured and run. At the end of the process, Knative has launched the container you nominated and configured, routing it so that it’s listening at the given URL.

What’s at the URL we were given in listing 1.2? Let’s see what the following listing shows.

Listing 2.1 The first hello
```bash
$ kn service list

$ kn service list -o json |jq -r ".items[0].status.url"

$ curl  $(kn service list -o json |jq -r ".items[0].status.url")
Hello First!
```
Very cheerful.

### Your second deployment
Mind you, perhaps you don’t like ``First``. Maybe you like ``Second`` better. Easily fixed, as the following listing shows.

Listing 2.3 Updating hello-example
```bash
$ kn service update hello-example \
  --env TARGET=Second
 
Updating Service 'hello-example' in namespace 'default':
 
  3.418s Traffic is not yet migrated to the latest revision.
  3.466s Ingress has not yet been reconciled.
  4.823s Ready to serve.
 
Service 'hello-example' updated with latest revision 'hello-example-00002' and URL: http://hello-example.example.com
 
$ kn service list -o json |jq -r ".items[0].status.url"

$ curl  $(kn service list -o json |jq -r ".items[0].status.url")
Hello Second!
```
What happened is that I changed the ``TARGET`` environment variable that the example application interpolates into a simple template. The next listing shows this.

Listing 2.4 How a hello sausage gets made
```bash
func handler(w http.ResponseWriter, r *http.Request) {
  target := os.Getenv("TARGET")
  fmt.Fprintf(w, "Hello %s!\n", target)
}
```
You may have noticed that the revision name changed. ``First`` was ``hello-example-00001``, and ``Second`` was ``hello-example-00002``. Yours will look slightly different because part of the name is randomly generated: ``hello-example`` comes from the name of the Service, and the 1 and 2 suffixes indicate the generation of the Service (more on that in a second). But the bit in the middle is randomized to prevent accidental name collisions.

Did ``Second`` replace ``First``? The answer is—it depends who you ask. If you’re an end user sending HTTP requests to the URL, yes, it appears as though a total replacement took place. But from the point of view of a developer, both Revisions still exist, as shown in the following listing.

Listing 2.5 Both revisions still exist
```bash
$  kn revision list
NAME                  SERVICE         TRAFFIC   TAGS   GENERATION   AGE     CONDITIONS   READY   REASON
hello-example-00002   hello-example   100%             2            4m58s   3 OK / 4     True
hello-example-00001   hello-example                    1            42m     3 OK / 4     True
```

I can look more closely at each of these with ``kn revision describe``. The following listing shows this.

Listing 2.6 Looking at the first revision
```bash
$ kn revision describe  hello-example-00001
Name:       hello-example-00001
Namespace:  default
Age:        43m
Image:      gcr.io/knative-samples/helloworld-go (pinned to 5ea96b)
Replicas:   0/0
Env:        TARGET=First
Service:    hello-example

Conditions:
  OK TYPE                  AGE REASON
  ++ Ready                 43m
  ++ ContainerHealthy      43m
  ++ ResourcesAvailable    43m
   I Active                33m NoTraffic
``` 
### Conditions
It’s worth taking a slightly closer look at the ``Conditions table`` (listing 2.6). Software can be in any number of states, and it can be useful to know what these are. A smoke test or external monitoring service can detect that you have a problem, but it may not be able to tell you why you have a problem. What this table gives you is four pieces of information:

* ``OK`` **gives the quick summary about whether the news is good or bad**. The ++ signals that everything is fine. The I signals an informational condition. It’s not bad, but it’s not as unambiguously positive as ++. If things were going badly, you’d see !!. If things are bad but not, like, ``bad`` bad, ``kn`` signals a warning condition with ``W``. And if Knative just doesn’t know what’s happening, you’ll see ??.

* ``TYPE`` **is the unique condition being described**. In this table, we can see four types reported. The **Ready** condition, for example, surfaces the result of an underlying Kubernetes readiness probe. Of greater interest to us is the **Active** condition, which tells us whether there is an instance of the Revision running.

* ``AGE`` **reports on when this condition was last observed to have changed**. In the example, these are all three hours, but they don’t have to be.

* ``REASON`` **allows a condition to provide a clue as to deeper causes**. For example, our ``Active`` condition shows ``NoTraffic`` as its reason.

So this line
```bash
   I Active                33m NoTraffic
``` 
is an instance of the Revision running.

AGE reports on when this condition was last observed to have changed. In the example, these are all three hours, but they don’t have to be.

REASON allows a condition to provide a clue as to deeper causes. For example, our Active condition shows NoTraffic as its reason.

So this line

I Active 3h NoTraffic
Can be read as

“As of 3 hours ago, the ``Active`` condition has an Informational status due to ``NoTraffic``.”

Suppose we get this line:
```bash
!! Ready 1h AliensAttackedTooSoon
````

We could read it as

“As of an hour ago, the ``Ready`` condition became not OK because the ``AliensAttackedTooSoon``.”

###  What does Active mean?

When the ``Active`` condition gives ``NoTraffic`` as a reason, that means there are no active instances of the Revision running. Suppose we poke it with ``curl`` as in the following listing.

Listing 2.7 Poking with curl
```bash
$ kn revision describe  hello-example-00002
Name:       hello-example-00002
Namespace:  default
Age:        1h
Image:      gcr.io/knative-samples/helloworld-go (pinned to 5ea96b)
Replicas:   0/0
Env:        TARGET=Second
Service:    hello-example

Conditions:
  OK TYPE                  AGE REASON
  ++ Ready                  1h
  ++ ContainerHealthy       1h
  ++ ResourcesAvailable     1h
   I Active                 1h NoTraffic


$  curl  $(kn service list -o json |jq -r ".items[0].status.url")
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100    14  100    14    0     0      3      0  0:00:04  0:00:03  0:00:01     3   Hello Second!

 
$ kn revision describe  hello-example-00002
Name:       hello-example-00002
Namespace:  default
Age:        1h
Image:      gcr.io/knative-samples/helloworld-go (pinned to 5ea96b)
Replicas:   1/1
Env:        TARGET=Second
Service:    hello-example

Conditions:
  OK TYPE                  AGE REASON
  ++ Ready                  1h
  ++ ContainerHealthy       1h
  ++ ResourcesAvailable     1h
  ++ Active                 4s
```
Note that we now see ``++ Active`` **without** the ``NoTraffic`` reason. Knative is saying that a running process was created and is active. If you leave it for a minute, the process will shut down again and the ``Active`` Condition will return to complaining about a lack of traffic.

###  Changing the image
The Go programming language, aka Golang to its friends and “erhrhfjahaahh” to its enemies, is the Old Hotness. The New Hotness is Rust, which I have so far been able to evade forming an opinion about. All I know is that it’s the New Hotness and that, therefore, as a responsible engineer, I know that it is “Better.”

This means that ``helloworld-go`` no longer excites me. I would like to use ``helloworld-rust``, instead. The following listing shows how this is easily done.

Listing 2.8 Updating the container image
```bash
$ kn service update hello-example \
  --image gcr.io/knative-samples/helloworld-rust

Updating Service 'hello-example' in namespace 'default':

  0.093s The Configuration is still working to reflect the latest desired specification.

175.944s Traffic is not yet migrated to the latest revision.
176.083s Ingress has not yet been reconciled.
176.226s Waiting for load balancer to be ready
176.484s Ready to serve.

Service 'hello-example' updated to latest revision 'hello-example-00003' is available at URL:
http://hello-example.default.192.168.59.201.sslip.io
```
And then I poke it (as in the next listing).

Listing 2.9 The New Hotness says Hello
```bash
$  curl  $(kn service list -o json |jq -r ".items[0].status.url")

Hello world: Second
```

Note that the message is slightly different: “Hello world: Second” instead of “Hello Second!” Not being deeply familiar with Rust, I can only suppose that it forbids excessive informality when greeting people it has never met. But it does at least prove that I didn’t cheat and just change the ``TARGET`` environment variable.

There’s an important point to remember here: changing the environment variable caused the second Revision to come into being. Changing the image caused a third Revision to be created. But because I didn’t change the variable, the third Revision also says “Hello world: Second.” In fact, almost any update I make to a Service causes a new Revision to be stamped out.

Almost any? What’s the exception? It’s Routes. Updating these as part of a Service won’t create a new Revision.

###  Splitting traffic
I’m going to prove that Route updates don’t create new Revisions by splitting traffic evenly between the last two Revisions. The next listing shows this split.

Listing 2.10 Splitting traffic 50/50
```bash
$ kn service update hello-example \
  --traffic hello-example-00002=50 \
  --traffic hello-example-00003=50

Updating Service 'hello-example' in namespace 'default':

  0.075s The Route is still working to reflect the latest desired specification.
  0.159s Ingress has not yet been reconciled.
  0.344s Waiting for load balancer to be ready
  0.514s Ready to serve.

Service 'hello-example' with latest revision 'hello-example-00003' (unchanged) is available at URL:
http://hello-example.default.192.168.59.201.sslip.io

$  kn revision list
NAME                  SERVICE         TRAFFIC   TAGS   GENERATION   AGE     CONDITIONS   READY   REASON
hello-example-00003   hello-example   50%              3            4m35s   3 OK / 4     True
hello-example-00002   hello-example   50%              2            5m7s    3 OK / 4     True
hello-example-00001   hello-example                    1            5m42s   3 OK / 4     True

```

The --traffic parameter shown in listing 2.10 allows us to assign percentages to each Revision. The key is that the percentages must all add up to 100. If I give ``50`` and ``60``, I’m told that “given traffic percents sum to ``110``, want ``100``.” Likewise, if I try to cut some corners by giving ``50`` and ``40``, I get “given traffic percents sum to ``90``, want ``100``.” It’s my responsibility to ensure that the numbers add up correctly.

Does it work? Let’s see what the following listing does.

Listing 2.11 Totally not a perfect made-up sequence of events
```bash 
$  curl  $(kn service list -o json |jq -r ".items[0].status.url")
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100    14  100    14    0     0    264      0 --:--:-- --:--:-- --:--:--   274  Hello Second!
 
$  curl  $(kn service list -o json |jq -r ".items[0].status.url")
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100    19  100    19    0     0      6      0  0:00:03  0:00:02  0:00:01     6  Hello world: Second

```

It works! Half your traffic will now be allocated to each Revision.

50/50 is just one split; you can split the traffic however you please. Suppose you had Revisions called ``un``, ``deux``, ``trois``, and quatre. You might split it evenly, as the next listing shows.

Listing 2.12 Even four-way split
```bash 
$ kn service update french-flashbacks-example \
  --traffic un=25 \
  --traffic deux=25 \
  --traffic trois=25 \
  --traffic quatre=25
Error: services.serving.knative.dev "french-flashbacks-example" not found
Run 'kn --help' for usage
```
Or, you can split it so that ``quatre`` is getting a tiny sliver to prove itself, while the bulk of the work lands on ``trois``. Let’s look at the next listing to see this.

Listing 2.13 Production and next versions
```bash
$ kn service update french-flashbacks-example \
  --traffic un=0 \
  --traffic deux=0 \
  --traffic trois=98 \
  --traffic quatre=2
```
You don’t explicitly need to set traffic to 0%. You can achieve the same by leaving out Revisions from the list as shown in this listing.

Listing 2.14 Implicit zero traffic level
```bash
$ kn service update french-flashbacks-example \
  --traffic trois=98 \
  --traffic quatre=2
```

Finally, if I am satisfied that ``quatre`` is ready, I can switch over all the traffic using ``@latest`` as my target. The following listing shows this switch.

Listing 2.15 Targeting @latest
```bash
$ kn service update french-flashbacks-example \
  --traffic @latest=100

```

## 2.2 Serving components
As promised, I’m going to spend some time looking at some Knative Serving internals. In chapter 1, I explained that Knative and Kubernetes are built on the concept of control loops. A control loop involves a mechanism for comparing a desired world and an actual world, then taking action to close the gap between these.

But that’s the boxes-and-lines explanation. The concept of a control loop needs to be embodied as actual software processes. Knative Serving has several of these, falling broadly into four groups:

* ``Reconcilers`` —Act on both user-facing concepts like Services, Revisions, Configurations, and Routes, as well as lower-level housekeeping

* ``The Webhook`` —Validates and enriches the Services, Configurations, and Routes that users provide

* ``Networking controllers`` —Configure TLS certificates and HTTP Ingress routing

* ``The Autoscaler/Activator/Queue-Proxy triad`` —Manages the business of comprehending and reacting to changes on traffic

### 2.2.1 The controller and reconcilers
Let’s talk about names for a second. Knative has a component named ``controller``, which is really a bundle of individual “reconcilers.” Reconcilers are controllers in the sense that I discussed in chapter 1: a system that reacts to changes in the difference between desired and actual worlds. So reconcilers are controllers, but the controller isn’t really a controller. Got it?

No? You’re wondering why the names are different? The simplest answer is: to avoid confusion about what’s what. That may sound silly. Bear with me, I promise it will make sense soon.

At the top, in terms of actual running processes managed directly by Kubernetes, Knative Serving only has one controller. But in terms of logical processes, Knative Serving has several controllers running in Goroutines inside the single physical ``controller`` process (figure 2.1). Moreover, the Reconciler is a Golang interface that implementations of the controller pattern are expected to implement.

So that we don’t wind up saying “the controller controller” and “the controllers that run on the controller” or other less-than-illuminating naming schemes, there are instead two names: controller and reconciler.

Each reconciler is responsible for some aspect of Knative Serving’s work, which falls into two categories. The first category is simple to understand—it’s the reconcilers responsible for managing the developer-facing resources. Hence, there are reconcilers called **configuration**, **revision**, **route**, and **service**.

For example, when you use ``kn service create``, the first port of call will be for a Service record to be picked up by the service controller. When you used ``kn service update`` to create a traffic split, you actually get the route controller to do some work for you. I’ll touch on some of these controllers in coming chapters.


Figure 2.1 The Serving controller and its reconcilers

Reconcilers in the second category work behind the scenes to carry out essential lower-level tasks. These are ``labeler``, ``serverlessservice``, and ``gc``. The labeler is part of how networking works; it essentially sets and maintains labels on Kubernetes objects that networking systems can use to target those for traffic.

The serverlessservice (that is the name) reconciler is part of how the Activator works. It reacts to and updates serverlessservice records (say that 5 times fast!). These are also mostly about networking in Kubernetes-land.

Lastly, the gc reconciler performs garbage-collection duties. Hopefully, you will never need to think about it again.
