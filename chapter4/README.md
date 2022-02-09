# Chapter 4 Routes
## 4.2 The anatomy of Routes

> ⚠ WARNING Knative Services and Kubernetes Services are not the same. In fact, these are deeply unalike. Refer to the sidebar for more.

### Service vs. Service

A Kubernetes Service is approximately half of a Route. It defines a name where traffic can be sent and where that traffic will wind up being sent. This is needed because copies of software can come and go, appearing with new unique names each time. A downstream client shouldn’t have to keep track of the exact location of its upstream server. If you define a Kubernetes Service, you can send traffic there and let Kubernetes find the running software for you.

But a Kubernetes Service is at its best in dealing with traffic inside a cluster. Traffic that comes from outside the cluster can, in theory, be sent through a Kubernetes Service, but it isn’t pretty. You wind up needing a specialized kind of Service (a LoadBalancer) that lashes you to the particular infrastructure you’re running on. Meaning that if you ask the Kubernetes Service to be the outside world face of your software, you will need to get AWS or Azure or vSphere or what-have-you to set up a load balancer that will shuffle traffic between the underlying platform’s network and your Kubernetes cluster’s internal network.

The more idiomatic way in Kubernetes is to have the Service as an internal thing and to provide a Kubernetes Ingress that knows how to listen for outside world traffic and send it to the Kubernetes Service. If you look carefully, you might have realized that Routes roll up both of these problems. It deals with the business of wiring Ingresses and Kubernetes Services on your behalf. Easy peasy.

But a Knative Service, as we’ve seen before, is not purely about networking stuff. Instead, it rolls up Configurations and Routes; it’s a high-level statement of all the things you want Knative to do for a particular piece of software.

I know the name collision here is less than ideal. It’s passable for folks who are new to both Knative and Kubernetes, for whom we can say “just ignore the Kubernetes stuff as much as possible.” For seasoned Kubernetes pros, it’s a bit annoying. As it happens, “seasoned pros” is a decent description for some of the folks who designed Knative. The name “Service” was not chosen by accident and, I promise you, there were naming discussions that took bikeshedding to new and exciting levels. “Service” came out as the least worst.

## 4.3 The anatomy of TrafficTargets
 
### 4.3.3 tag

Way, waaaay back in chapter 2, I performed the cool party trick shown in the following listing.

Listing 4.13 Splitting traffic 50/50
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

$  curl  $(kn service list -o json |jq -r ".items[0].status.url")
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100    14  100    14    0     0    264      0 --:--:-- --:--:-- --:--:--   274  Hello Second!
 
$  curl  $(kn service list -o json |jq -r ".items[0].status.url")
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100    19  100    19    0     0      6      0  0:00:03  0:00:02  0:00:01     6  Hello world: Second
```
The gist was that using ``--traffic`` enabled me to set routing percentages on particular Revisions. Sometimes, though, I don’t want percentages—I want certainties. Suppose I have two Revisions, ``rev-1`` and ``rev-2``. If I want to be sure to hit ``rev-1``, I can set its percentage to 100%.

This might not be what I want, however. While it guarantees that my requests all go to ``rev-1``, it also guarantees that everyone’s requests will as well. If my purpose was to debug a flaky function, this is going to cause some problems. What’s needed is to separate two different problems:

* How do I divvy up traffic between Revisions using a shared name?

* How can I refer to Revisions directly?

Setting a ``tag`` is what gives us the ability to directly target a particular Revision. Let’s assume I’ve created a Service with two Revisions. I want to tag these ``satu`` (“one”) and ``dua`` (“two”), respectively.2 It looks like the next listing.

Listing 4.14 Setting a tag
```bash
$ kn service create satu-dua-example --image gcr.io/knative-samples/helloworld-go --env TARGET=Satu
# ... Service 'satu-dua-example' created to latest revision 'satu-dua-example-00001' is available at URL: http://satu-dua-example.default.192.168.59.201.sslip.io
 
$ kn service update satu-dua-example   --env TARGET=Dua 
# ... Service 'satu-dua-example' updated to latest revision 'satu-dua-example-00002' is available at URL: http://satu-dua-example.default.192.168.59.201.sslip.io
 
$ kn service update satu-dua-example --tag satu-dua-example-00001=satu --tag satu-dua-example-00002=dua
 
Updating Service 'satu-dua-example' in namespace 'default':

  0.032s The Route is still working to reflect the latest desired specification.
  0.135s Ingress has not yet been reconciled.
  0.222s Waiting for load balancer to be ready
  0.396s Ready to serve.

Service 'satu-dua-example' with latest revision 'satu-dua-example-00002' (unchanged) is available at URL:
http://satu-dua-example.default.192.168.59.201.sslip.io
```

Note that adding a tag *doesn’t* cause a new Revision to be stamped out. That’s because ``tag`` is part of a Route, not part of a Configuration. And besides, if tagging Revisions created new Revisions, you’d never catch up.

What does the world look like now? I check the following listing for revelations.

Listing 4.15 Three targets
```bash
$ kn route describe satu-dua-example
Name:       satu-dua-example
Namespace:  default
Age:        5m
URL:        http://satu-dua-example.default.192.168.59.201.sslip.io         ❶
Service:    satu-dua-example

Traffic Targets:
  100%  @latest (satu-dua-example-00002)                                    ❷
    0%  satu-dua-example-00001 #satu                                        ❸
        URL:  http://satu-satu-dua-example.default.192.168.59.201.sslip.io  ❹
    0%  satu-dua-example-00002 #dua                                         ❸
        URL:  http://dua-satu-dua-example.default.192.168.59.201.sslip.io   ❹

Conditions:
  OK TYPE                      AGE REASON
  ++ Ready                      2m
  ++ AllTrafficAssigned         4m
  ++ CertificateProvisioned     4m TLSNotEnabled
  ++ IngressReady               2m
```
❶ The main URL is still available. Anything sent to this URL flows according to the configuration of the Traffic Targets.

❷ 100% of traffic is flowing to @latest because I didn’t update any —traffic settings while updating —tag. The @latest tag is a floating pointer to the latest Revision. This is the same Revision that will be pointed to when latestRevision is true.

❸ satu-dua-example-brvhy-1 has the tag satu attached to it. Likewise, satu-dua-example-snznt-2 has dua attached.

❹ Now the fun bit: in addition to the normal URL, I now have special URLs that only route to particular tags.

I’ll test the theory with the following listing.
Listing 4.16 One, two
```bash
curl  http://satu-satu-dua-example.default.192.168.59.201.sslip.io
Hello Satu!

curl  http://dua-satu-dua-example.default.192.168.59.201.sslip.io 
Hello Dua!
```

Note that these URLs follow a predictable pattern. The main URL, where traffic flows according to the Traffic Target rules, includes the service name only (http:/ /<servicename>.default.example.com). But each tagged Revision now has a URL of the form http:/ /<tag>-<servicename>.default.example.com. In these, the main URL is prepended with the tag. Hence, **satu**``-satu-dua-example`` points to ``#satu``, which points to ``satu-dua-example-00001``.

Now that I have tags, I can use those to split up traffic, as the next listing demonstrates. This is exactly the same as splitting traffic using a Revision name.

Listing 4.17 Splitting traffic between tags
```bash 
$ kn service update satu-dua-example --traffic satu=50   --traffic dua=50
Updating Service 'satu-dua-example' in namespace 'default':

  0.033s The Route is still working to reflect the latest desired specification.
  0.107s Ingress has not yet been reconciled.
  0.181s Waiting for load balancer to be ready
  0.388s Ready to serve.

Service 'satu-dua-example' with latest revision 'satu-dua-example-00002' (unchanged) is available at URL:
http://satu-dua-example.default.192.168.59.201.sslip.io

$  kn route describe satu-dua-example
Name:       satu-dua-example
Namespace:  default
Age:        12m
URL:        http://satu-dua-example.default.192.168.59.201.sslip.io
Service:    satu-dua-example

Traffic Targets:
   50%  satu-dua-example-00001 #satu
        URL:  http://satu-satu-dua-example.default.192.168.59.201.sslip.io
   50%  satu-dua-example-00002 #dua
        URL:  http://dua-satu-dua-example.default.192.168.59.201.sslip.io

Conditions:
  OK TYPE                      AGE REASON
  ++ Ready                     14s
  ++ AllTrafficAssigned        11m
  ++ CertificateProvisioned    11m TLSNotEnabled
  ++ IngressReady              14s
```
In listing 4.17, I can see that traffic will be split 50/50 between ``satu`` and ``dua``. What I no longer see is ``@latest`` as one of the targets. By setting the traffic totals explicitly, I told Knative Serving that I know what I’m doing. Under the hood, this shows up as ``latestRevision``: **false**.

What happens if I create another Revision? Something you might not have expected: the Revision exists but can’t receive traffic. The following listing shows how it will look in ``kn``.

Listing 4.18 No love for Tiga
```bash 
$ kn service update satu-dua-example --env TARGET=Tiga
Updating Service 'satu-dua-example' in namespace 'default':

  0.030s The Configuration is still working to reflect the latest desired specification.
  4.316s Ready to serve.

Service 'satu-dua-example' updated to latest revision 'satu-dua-example-00003' is available at URL:
http://satu-dua-example.default.192.168.59.201.sslip.io

 
$ kn service describe satu-dua-example
Name:       satu-dua-example
Namespace:  default
Age:        25m
URL:        http://satu-dua-example.default.192.168.59.201.sslip.io       

Revisions:
     +  satu-dua-example-00003 (current @latest) [3] (22s)              ❶
        Image:     gcr.io/knative-samples/helloworld-go (pinned to 5ea96b)
        Replicas:  1/1
   50%  satu-dua-example-00002 #dua [2] (25m)
        Image:     gcr.io/knative-samples/helloworld-go (pinned to 5ea96b)
        Replicas:  0/0
   50%  satu-dua-example-00001 #satu [1] (25m)
        Image:     gcr.io/knative-samples/helloworld-go (pinned to 5ea96b)
        Replicas:  0/0

Conditions:
  OK TYPE                   AGE REASON
  ++ Ready                  17s
  ++ ConfigurationsReady    17s
  ++ RoutesReady            14m
```
❶ Instead of seeing 0%, I see a + symbol.

The arrow points to the new thing in listing 4.18. Right now, this Revision isn’t excluded because of how routing arithmetic works when given zeroes—it’s excluded from the routing arithmetic altogether. You can figure this out from the next listing, because if you look at the Route instead of the Service, the third Revision isn’t there at all.

Listing 4.19 No Tiga
```bash
$ kn route describe satu-dua-example
Name:       satu-dua-example
Namespace:  default
Age:        27m
URL:        http://satu-dua-example.default.192.168.59.201.sslip.io
Service:    satu-dua-example

Traffic Targets:
   50%  satu-dua-example-00001 #satu
        URL:  http://satu-satu-dua-example.default.192.168.59.201.sslip.io
   50%  satu-dua-example-00002 #dua
        URL:  http://dua-satu-dua-example.default.192.168.59.201.sslip.io

Conditions:
  OK TYPE                      AGE REASON
  ++ Ready                     16m
  ++ AllTrafficAssigned        27m
  ++ CertificateProvisioned    27m TLSNotEnabled
  ++ IngressReady              16m
```
Maybe you’re still confused. I think a diagram is in order (figure 4.1).

At face value, this whole dance may seem a bit silly. Why create a Revision if you’re not going to feed it any traffic? Shouldn’t the latest and greatest always be in the spotlight?

Figure 4.1 The relationship of Services, Routes, Configurations, Revisions, and Tags

Often, yes. In development environments, definitely. That’s why the default Knative Serving behavior sets latestRevision: true and then updates a floating @latest tag automatically.

But when you manually assign traffic percentages, this automatic behavior is disabled and you are given full control. This is a reasonable thing to do because, otherwise, you’ll be constantly stuck in weird slapfights with Serving’s controllers. Setting traffic manually is a useful escape hatch.

Mind you, escaping is sometimes a mistake. Happily, you can undo it pretty easily because ``@latest`` is always available as a tag. Take a peek at the following listing.

Listing 4.20 Switching the autopilot back on
```bash
$ kn service update satu-dua-example \
  --traffic satu=33 \
  --traffic dua=33 \
  --traffic @latest=34

Updating Service 'satu-dua-example' in namespace 'default':

  0.049s The Route is still working to reflect the latest desired specification.
  0.117s Ingress has not yet been reconciled.
  0.205s Waiting for load balancer to be ready
  0.390s Ready to serve.

Service 'satu-dua-example' with latest revision 'satu-dua-example-00003' (unchanged) is available at URL:
http://satu-dua-example.default.192.168.59.201.sslip.io

kn service describe satu-dua-example
Name:       satu-dua-example
Namespace:  default
Age:        30m
URL:        http://satu-dua-example.default.192.168.59.201.sslip.io

Revisions:
   34%  @latest (satu-dua-example-00003) [3] (4m)
        Image:     gcr.io/knative-samples/helloworld-go (pinned to 5ea96b)
        Replicas:  0/0
   33%  satu-dua-example-00002 #dua [2] (29m)
        Image:     gcr.io/knative-samples/helloworld-go (pinned to 5ea96b)
        Replicas:  0/0
   33%  satu-dua-example-00001 #satu [1] (30m)
        Image:     gcr.io/knative-samples/helloworld-go (pinned to 5ea96b)
        Replicas:  0/0

Conditions:
  OK TYPE                   AGE REASON
  ++ Ready                  23s
  ++ Config


$ kn route describe satu-dua-example
Name:       satu-dua-example
Namespace:  default
Age:        31m
URL:        http://satu-dua-example.default.192.168.59.201.sslip.io
Service:    satu-dua-example

Traffic Targets:
   33%  satu-dua-example-00001 #satu
        URL:  http://satu-satu-dua-example.default.192.168.59.201.sslip.io
   33%  satu-dua-example-00002 #dua
        URL:  http://dua-satu-dua-example.default.192.168.59.201.sslip.io
   34%  @latest (satu-dua-example-00003)

Conditions:
  OK TYPE                      AGE REASON
  ++ Ready                      1m
  ++ AllTrafficAssigned        30m
  ++ CertificateProvisioned    30m TLSNotEnabled
  ++ IngressReady               1m
```
In listing 4.20, I can now see that my third Revision is visible in both the Service and the Route. And, in figure 4.2, I can see what it looks like.

Figure 4.2 After **@latest** is set as a target

But let’s keep rolling. I’ve re-enabled ``@latest`` and, under the hood, the ``latestRevision: true`` setting has been placed on ``satu-dua-example-00003``. If I add a fourth Revision, what will happen to the third Revision? Will it still get traffic? Will the others shuffle down, or something? Saunter to the next listing for an answer.

Listing 4.21 Adding a fourth Revision and looking at the Service afterward
```bash
$ kn service update satu-dua-example --env TARGET=Empat

Updating Service 'satu-dua-example' in namespace 'default':

  0.044s The Configuration is still working to reflect the latest desired specification.
  3.578s Traffic is not yet migrated to the latest revision.
  3.634s Ingress has not yet been reconciled.
  3.740s Waiting for load balancer to be ready
  3.939s Ready to serve.

Service 'satu-dua-example' updated to latest revision 'satu-dua-example-00004' is available at URL:
http://satu-dua-example.default.192.168.59.201.sslip.io

$ kn service describe satu-dua-example
Name:       satu-dua-example
Namespace:  default
Age:        34m
URL:        http://satu-dua-example.default.192.168.59.201.sslip.io

Revisions:
   34%  @latest (satu-dua-example-00004) [4] (59s)
        Image:     gcr.io/knative-samples/helloworld-go (pinned to 5ea96b)
        Replicas:  1/1
   33%  satu-dua-example-00002 #dua [2] (33m)
        Image:     gcr.io/knative-samples/helloworld-go (pinned to 5ea96b)
        Replicas:  0/0
   33%  satu-dua-example-00001 #satu [1] (34m)
        Image:     gcr.io/knative-samples/helloworld-go (pinned to 5ea96b)
        Replicas:  0/0

Conditions:
  OK TYPE                   AGE REASON
  ++ Ready                  55s
  ++ ConfigurationsReady    55s
  ++ RoutesReady            55s

$ kn route describe satu-dua-example
Name:       satu-dua-example
Namespace:  default
Age:        35m
URL:        http://satu-dua-example.default.192.168.59.201.sslip.io
Service:    satu-dua-example

Traffic Targets:
   33%  satu-dua-example-00001 #satu
        URL:  http://satu-satu-dua-example.default.192.168.59.201.sslip.io
   33%  satu-dua-example-00002 #dua
        URL:  http://dua-satu-dua-example.default.192.168.59.201.sslip.io
   34%  @latest (satu-dua-example-00004)

Conditions:
  OK TYPE                      AGE REASON
  ++ Ready                      1m
  ++ AllTrafficAssigned        34m
  ++ CertificateProvisioned    34m TLSNotEnabled
  ++ IngressReady               1m

```
Something unfortunate has happened in listing 4.21, which is that my third Revision has vanished entirely. The fourth Revision, ``satu-dua-example-00004``, has taken over as ``@latest``. But neither ``route describe`` nor ``service describe`` shows any other signs of its predecessor.

The good news is that the Revision has not vanished forever. I can see this quickly enough with ``kn revision list``, as the next listing reveals.

Listing 4.22 Peekaboo
```bash
$ kn revision list
NAME                        SERVICE            TRAFFIC   TAGS   GENERATION   AGE     CONDITIONS   READY   REASON 
satu-dua-example-00004      satu-dua-example   34%              4            4m20s   3 OK / 4     True
satu-dua-example-00003      satu-dua-example                    3            12m     3 OK / 4     True
satu-dua-example-00002      satu-dua-example   33%       dua    2            37m     3 OK / 4     True
satu-dua-example-00001      satu-dua-example   33%       satu   1            37m     3 OK / 4     True
```
Listing 4.22 shows the whole gang, complete with traffic percentages and tags. Figure 4.3 shows the whole gang in diagrammatic form.

Did I lie earlier when I said you could re-engage autopilot using @latest? The answer is, as usual, “sort of.” You could re-engage the way that ``@latest`` acts as a floating target based on the creation of Revisions, but this doesn’t unpin anything else that you’ve manually configured. Only the fraction that was assigned to ``@latest`` will float. Everything else is fixed in place until you change it.

And if you stop to think about it, this means that the fully automatic setting is actually a special case of the partly automatic setting. If 100% of traffic flows to ``@latest``, which is the default rule, then everything looks fully automated. For development, that’s an excellent experience, but in production, you may want to exert a more precise control.

The trade-off is that the illusion of magic and automation is shattered once we begin to pin things down. And because we’ve shattered the illusion, let’s just keep going and grind it into dust by moving tags across Revisions.

My first instinct is to just use ``--tag`` again, but with a different target. This turns out not to work, which the following listing illustrates.

Listing 4.23 Tags can’t be overwritten in-place
```bahs
$ kn service update satu-dua-example --tag satu-dua-example-00004
 
refusing to overwrite existing tag in service,  add flag '--untag satu' in command to untag it
```

But luckily, I get a hint from kn about what to do. I need to ``--untag`` the target to free up the tag itself. I can see how that goes in the next listing.`

```bash
$ kn service update satu-dua-example --untag satu
Updating Service 'satu-dua-example' in namespace 'default':

  0.034s The Route is still working to reflect the latest desired specification.
  0.084s Ingress has not yet been reconciled.
  0.180s Waiting for load balancer to be ready
  0.411s Ready to serve.

Service 'satu-dua-example' with latest revision 'satu-dua-example-00004' (unchanged) is available at URL:
http://satu-dua-example.default.192.168.59.201.sslip.io
```
And now that I’ve untagged it, what happens to ``satu’s`` 33% share of traffic? The following listing shows us.

```bash
$ kn route describe satu-dua-example
Name:       satu-dua-example
Namespace:  default
Age:        44m
URL:        http://satu-dua-example.default.192.168.59.201.sslip.io
Service:    satu-dua-example

Traffic Targets:
   33%  satu-dua-example-00001
   33%  satu-dua-example-00002 #dua
        URL:  http://dua-satu-dua-example.default.192.168.59.201.sslip.io
   34%  @latest (satu-dua-example-00004) #satu-dua-example-00004
        URL:  http://satu-dua-example-00004-satu-dua-example.default.192.168.59.201.sslip.io

Conditions:
  OK TYPE                      AGE REASON
  ++ Ready                      1m
  ++ AllTrafficAssigned        44m
  ++ CertificateProvisioned    44m TLSNotEnabled
  ++ IngressReady               1m

```
Knative Serving opts for safety. This means that as it removes the satu tag as the Traffic Target, it substitutes the Revision that was pointed at by the tag. Meaning that the 33% previously assigned to ``satu`` is now assigned to ``satu-dua-example-00001`` instead (figure 4.4)

For users coming through the front door, via the main URL, there will not be a perceptible change. The traffic is still being split three ways among the same three Revisions.

For users who were directly hitting the ``<tag>-<servicename>`` URLs, there is a perceptible change. That URL stops working and begins to return 404s.


But now, at least, the tag is free to be reassigned. I perform that reassignment in listing 4.26. 

Listing 4.26 Assigning satu to a different Revision
```bahs
$ kn service update satu-dua-example --tag satu-dua-example-00004=satu
#  ... updates the Route
```

But when I inspect the Route, I am again caught out by an unexpected behavior. The next listing sheds some light.

Listing 4.27 Hmmm
```bash
$ kn route describe satu-dua-example
Name:       satu-dua-example
Namespace:  default
Age:        48m
URL:        http://satu-dua-example.default.192.168.59.201.sslip.io
Service:    satu-dua-example

Traffic Targets:
   33%  satu-dua-example-00001
   33%  satu-dua-example-00002 #dua
        URL:  http://dua-satu-dua-example.default.192.168.59.201.sslip.io
   34%  @latest (satu-dua-example-00004) #satu-dua-example-00004
        URL:  http://satu-dua-example-00004-satu-dua-example.default.192.168.59.201.sslip.io
    0%  satu-dua-example-00004 #satu
        URL:  http://satu-satu-dua-example.default.192.168.59.201.sslip.io

Conditions:
  OK TYPE                      AGE REASON
  ++ Ready                      1m
  ++ AllTrafficAssigned        48m
  ++ CertificateProvisioned    48m TLSNotEnabled
  ++ IngressReady               1m

```
What I expected to see in listing 4.27 was that the 33% of traffic currently going to the untagged Revision  ``satu-dua-example-00001`` would snap over to the newly tagged ``satu-dua-example-00004`` once it took over the ``satu`` tag. But this didn’t happen.

On reflection, it should be clear why. When I untagged the first time, Knative’s knowledge of ``satu`` was destroyed, and it subbed in the Revision to ensure that the Route would continue to function largely as before. When I reintroduce ``satu``, Knative has forgotten its previous existence. It gets the same treatment that any other tag would get: a direct URL is created, the tag is added to the Route, but 0% traffic is assigned. Afterward, it looks like figure 4.5.

Figure 4.5 Adding the #satu tag doesn’t shift traffic allocations.

If you’re not confused, it’s only because you got bored. The purpose of ``--tag`` and ``--traffic`` is to allow you to precisely control how deployment occurs. For right now, if you are just kicking tires, the default ``@latest`` behavior is fine. It will behave like a Blue/Green deployment, traffic won’t get dropped, all will be well. I’ll sketch how to use the more advanced capabilities in chapter 9.

# Summary
* Routes are how you describe to Knative where you want traffic to come from and go to.
* Routes are included as part of Services.
* You can use kn routes subcommands to list and describe Routes.
* Routes can have various conditions; the main ones include AllTrafficAssigned, IngressReady, and CertificateProvisioned.
* The heart of a Route is its list of traffic targets. These are visible in kn as Traffic Targets and visible in YAML under spec.traffic and status.traffic.
* Traffic Targets can have a configurationName, revisionName, or a tag.
* Traffic Targets can be “automated” by using latestRevision: true or by using the special @latest tag.
* Tags are names that you can attach to particular Revisions and then use as names for targeting. You can add and remove tags at will.
* The rules for how tags and @latest behave are not completely obvious. You can skip using tags until you need precise control of your deployment process.
