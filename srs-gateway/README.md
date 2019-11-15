# Dell EMC SRS Gateway Custom Resource Support

This Helm chart deploys an SRS Gateway Custom Resource (CR) for a given
Dell EMC product and an associated credentials secret. These resources will
be used the the Dell EMC Common Kubernetes Support (DECKS) to create all
of the necessary resources for registering with and communicating with an
SRS gateway. See "Description" section for more details.

## Table of Contents

* [Description](#description)
* [Requirements](#requirements)
* [Quick Start](#quick-start)
* [Configuration](#configuration)

## Description

This Helm chart deploys:
- An *SRS Gateway Custom Resource (CR)* for a given Dell EMC product.
  The SRS Gateway CR:
  - Allows the Dell EMC Common Kubernetes Support (DECKS) to register a
    Dell EMC product with a given SRS gateway
  - Triggers creation of a "remote access" pod/service that allows customers
    and customer support a mechanism (via SRS) to SSH into the Kubernetes
    cluster for performing service and maintenance.
  - Provides notifier resources that allow the Kubernetes Application Health
    Monitor (KAHM) to send select Kubernetes events as SRS events/alerts to
    the SRS gateway.
- A *credentials secret* that contains:
  - A login username/password for DECKS to use in registering a product
    with the SRS gateway.
  - User/group/password credentials to configure in the remote access pod.
- Optionally, a *Docker registry credentials secret* containing a user/password
  combination that will be used to download SRS gateway CR secondary resource
  pods, for Docker registries that require authentication.

The product name used for this helm chart must be an official, "on-boarded"
product/model that the SRS gateway recognizes as an official Dell EMC product
(e.g. OBJECTSCALE).

### Creation of SRS Gateway CR Secondary Resources by DECKS

DECKS implements a Kubernetes controller that watches for creation, update,
and deletion of SRS gateway CRs. When an SRS gateway custom resource and an
associated credentials secret are created via this helm chart, DECKS will
do the following:
- Set up a *remote access pod/service* to allow customers/customer support
  to remotely access (via SSH) a Kubernetes cluster for servicing/maintenance.
- *Register the product* with the SRS Gateway
- *Perform a "call home" test* to verify that DECKS can properly make RESTful
  API calls to send events to the SRS gateway.
- *Create an SRS GW config secret* that an KAHM SRS notifier will use to
  access credentials for making RESTful API calls to the SRS gateway.
- Create a *KAHM SRS notifier custom resource, deployment, and service*.
- Create a *SRS Configuration Upload CronJob for periodically scraping
  Helm and Kubernetes config, compiling into a tar/gzip archive file, and
  uploading to the SRS GW*

Here is a summary list of the SRS gateway custom resource secondary resources
that are created by the DECKS SRS gateway CR controller:
- Remote Access deployment
- Remote Access service (configured as type LoadBalancer)
- SRS connection configuration secret (for the SRS notifier to use for API REST calls)
- SRS Notifier deployment
- SRS Notifier service
- SRS Notifier custom resource
- SRS Configuration Upload CronJob

### Name/Prefix Used for SRS GW CR and Its Secondary Resources
This helm chart uses the following order of precedence in selecting a name for
an SRS gateway CR. The selected name is also used as a prefix in naming
secondary resources:
- Use the explicit `customResourceName` setting if configured for this helm chart
- Otherwise, use the `product` setting

### Deploying Multiple SRS Gateways
In some situations, a user may want to run helm install multiple times to
deploy more than one SRS gateway CR. This includes the following scenarios:
- For multiple products: For example, if a Kubernetes cluster deploys both
  Dell EMC Streaming Analytics (DESA) and Dell EMC Object Scale (DEOS)
  procucts, then typically a separate SRS gateway CR will be deployed for
  each product.
- Multiple SRS gateway CRs per product: In some testing situations, it may
  be desirable to spin up a temporary test SRS gateway CR for a given product
  in parallel with an existing instance of SRS gateway CR for that same
  product. This is achievable by setting the `customResourceName` Helm chart
  configuration to a unique name for at least one of the SRS gateway CRs.
  When `customResourceName` is configured, the SRS gateway CR and all of its
  secondary resources will include the `customResourceName` string as a
  prefix in their names. (If `customResourceName` is not set, then the
  SRS GW CR and its secondary resources use the `product` name as a basis
  for resource names.)

### Support for Docker Registry Secrets
In some cases, users may want to use a Docker registry that requires
authentication for pulling images for the SRS gateway CR's secondary
resource pods. This helm chart provides three modes of Docker registry
authentication support:
- No authentication required: If the registry used to pull secondary
  resource pod images does not require authentication, then Helm chart
  default values can be used, and the Helm release will not include
  references to a Docker registry Kubernetes secret.
- Reuse an existing Docker registry Kubernetes secret: If the Kubernetes
  cluster already uses a Docker registry secret (e.g. for ECS FLEX
  installations), then that secret can be reused for pulling SRS gateway CR
  secondary pod images by setting the `dockerSecret` Helm chart configuration.
  Note that if this option is used, the Docker registry secret will NOT be
  automatically deleted if/when the SRS gateway CR is deleted.
- Generate a Docker registry secret: If the user sets the `dockerUser` and
  `dockerPassword` helm chart configurations, then this Helm chart will
  automatically generate a Docker registry secret. The name used for this
  secret will include a prefix as described in the "Name/Prefix Used for
  SRS GW CR and Its Secondary Resources" section above. 
  Note that if this option is used, the Docker registry secret will be
  automatically deleted when the SRS gateway CR is deleted.

## Monitoring SRS Gateway CR Status
As described in the "Creation of SRS Gateway CR Secondary Resources by DECKS"
section above, DECKS will monitor for creation and updates to SRS gateway CRs.
Whenever a creation or update of an SRS gateway CR is detected, DECKS will
reconcile the creation/update with any existing secondary resources, and will
update secondary resources as appropriate.

The status of these operations can be monitored by viewing the SRS gateway
CR via `kubectl get ...`. Here is an example of an SRS gateway CR status
after all secondary resources have been created:
```
$ kubectl get srsgateways.decks.ecs.dellemc.com objectscale -o yaml
apiVersion: decks.ecs.dellemc.com/v1beta1
kind: SRSGateway
metadata:
  creationTimestamp: 2019-06-17T02:07:01Z
  generation: 1
  name: objectscale
  namespace: default
  resourceVersion: "14100160"
  selfLink: /apis/decks.ecs.dellemc.com/v1beta1/namespaces/default/srsgateways/objectscale
  uid: 98397a70-90a4-11e9-865a-005056bbe139
spec:
  configUpload:
    pullPolicy: Always
    registry: emccorp
    repository: config-upload
    restartPolicy: Never
    tag: latest
    uploadPeriodHours: 12
  connectionInfo:
    credsSecret: objectscale-srs-creds-secret
    hostname: 10.11.12.13
    port: 9443
    product: OBJECTSCALE
  dockerSecret: ""
  notifier:
    grpcConnTimeout: 5
    grpcRetries: 3
    pullPolicy: Always
    registry: emccorp
    repository: srs-notifier
    servicePort: 50051
    tag: latest
  remoteAccess:
    pullPolicy: Always
    registry: emccorp
    repository: remote-access
    servicePort: 22
    tag: latest
  testDialHome: false
status:
  configUpload:
    cronJob: streamingdata-config-upload
  connectionState:
    connected: true
    credsSecretChecksum: e5dbe064083f2880d31fd4776661318af64d507e9d4b78692e6127991d8bba4c
    deviceKeyHash: $2a$10$0WfUme1AgDNftazkhT3PluoGwERQJ2fte70.Gq2vcItpPiN6vtDhi
    reconcileError: ""
    reconciling: false
    serialNumber: ELMUSP0619VDBZ
    srsLoginHash: $2a$10$jq03.stCKBDQIDwuYHg9.OxU2KDIe9Fhq04aDHtpSzLU0XQ7V52NO
    testDialHomeResult: PASSED
    testDialHomeTime: Mon, 17 Jun 2019 02:07:36 UTC
  notifier:
    customResource: objectscale-srs
    deployment: objectscale-srs-notifier
    gatewayConfigSecret: objectscale-srs-secret
    service: objectscale-srs-notifier-svc
  remoteAccess:
    deployment: objectscale-remote-access
    extIP: 10.13.14.145
    service: objectscale-remote-service
$
```
The sections that follow describe the status fields in the SRS gateway CR.

### connectionState Status Fields
- connected: Indicates whether service with the SRS gateway is available.
  More specifically, this is marked true after:
  * DECKS is successful in registering the product with the SRS gateway
  * A successful test "call-home" RESTful API call is made
- credsSecretChecksum: A sha256 checksum used to detect changes in the
  SRS login username:password.
- deviceKeyHash: A bcrypt hash of the device key (security token) assigned
  by the SRS gateway for this product.
- reconcileError: The latest error/event/reason that is causing DECKS to
  continue reconciling SRS gateway CR secondary events.
- reconciling: Indicates that the DECKS SRS gateway CR controller is
  continuing to reconcile the desired state of the CR and its secondary
  resources with the actual current stage.
- serialNumber: The serial number assigned by the SRS gateway for this product.
- srsLoginHash: A bcrypt hash of the login username:password used to register
  the product with the SRS gateway.
- testDialHomeResult: Indicates the PASSED/FAILED result of the latest
  test dial home.
- testDialHomeTime: Timestamp for the latest test dial home.

### remoteAccess Status Fields
- deployment: Name of the remote access deployment created for this product.
- extIP: External IP that has been assigned to the remote access pod that
  has been created for this product.
- service: Name of the remote access service that has been created for this
  product.

### notifier Status Fields
- customResource: Name of the SRS notifier custom resource created for this product.
- deployment: Name of the SRS notifier deployment created for this product.
- gatewayConfigSecret: Name of the SRS configuration secret that was created
  for this secret. The connection information and credentials contained in
  this secret are used by the SRS notifier pod to perform RESTful API calls
  to the SRS gateway.
- service: Name of the SRS notifier service that has been created for this
  product.

### configUpload Status Fields
- cronJob: Name of the Kubernetes CronJob that is deployed for this product
  for periodically collecting Helm release and Kubernetes resource
  configuration for the Kubernetes cluster, and uploading this configuration
  to the SRS Gateway in the form of a compressed tar (.tar.gz) file.

## Rerunning the SRS Dial Home Test
To rerun the SRS Dial Home test, which confirms that DECKS can successfully
send "dial home" messages (i.e `connectemc` API requests) to the SRS gateway,
run the following command:
```
kubectl edit srsgateway <srs-gateway-resource-name>
```
and modify the following field:
```
  testDialHome: false
```
to:
```
  testDialHome: true
```
After exiting from your editor, examine the SRS gateway resource to confirm
that the Dial Home test has been rerun (the TestDialHomeTime should have
changed):
```
$ kubectl get srsgateway <srsgateway-resource-name> -o yaml | grep DialHome
    testDialHomeResult: PASSED
    testDialHomeTime: Mon, 17 Jun 2019 04:13:26 UTC
$ 
```

## Requirements

* A [Helm](https://helm.sh) installation with access to install to one or more namespaces.
* A [DECKS](https://github.com/EMCECS/charts/tree/master/decks) installation.

## Quick Start

1. First, [install and setup Helm](https://docs.helm.sh/using_helm/#quickstart).  *_Note:_* you'll likely need to setup role-based access controls for Helm to have rights to install packages, so be sure to read that part.

2. Setup the [EMCECS Helm Repository](https://github.com/EMCECS/charts).

```bash
$ helm repo add ecs https://emcecs.github.io/charts
$ helm repo update
```

3. Install the SRS gateway custom resource and credentials secret.

NOTE: The following options are mandatory:
* product:
Must be an official, "on-boarded" EMC product/model that is recognized by the SRS gateway that you're using.
* gateway.hostname:
Can be either the IP address or an FQDN for accessing the SRS gateway.
* gateway.login:
This should be set to the user:password that was supplied by Dell/EMC for registering a product with an SRS gateway. It is typically of the form `john.doe@example.com:MyPassword`.

If the Docker registry being used for the remote access and notifier images do not require authentication:
```bash
$ helm install --name srs-gateway ecs/srs-gateway --set product=OBJECTSCALE --set gateway.hostname=10.11.12.13 --set gateway.login=john.doe@example.com:MyPassword
```

Alternatively, if you have an existing Docker registry secret:
```bash
$ helm install --name srs-gateway ecs/srs-gateway --set product=OBJECTSCALE --set gateway.hostname=10.11.12.13 --set gateway.login=john.doe@example.com:MyPassword --set dockerSecret=my-existing-registry-secret
...
```

Or if you want this helm chart to generate and use a new Docker registry secret:
```bash
$ helm install --name srs-gateway ecs/srs-gateway --set product=OBJECTSCALE --set gateway.hostname=10.11.12.13 --set gateway.login=john.doe@example.com:MyPassword --set dockerUsername=janedoe --set dockerPassword=MyPassword
...
```

There are [configuration options](#configuration) you can peruse later at your heart's delight.

## Configuration

### product - MANDATORY
Must be an official, "on-boarded" EMC product/model that is recognized by the SRS gateway that you're using.

Example helm install command line setting:
```
--set product=OBJECTSCALE
```

### gateway.hostname - MANDATORY
Can be either the IP address or an FQDN for accessing the SRS gateway.

Example helm install command line setting:
```
--set gateway.hostname=10.11.12.13
```

### gateway.login - MANDATORY
The gateway.login configures the login username/password for DECKS to use for registering with the SRS gateway.

Example helm install command line setting:
```
--set gateway.login=john.doe@example.com:MyPassword
```

### customResourceName
The name to use for the SRS GW custom resource Kubernetes object. If set, this name will be used as a prefix for all secondary resources generated for the SRS GW custom resource. This allows for multiple SRS GW custom resources to use the same product name, while providing distinct names for the SRS GW CRs and their corresponding secondary resources.

This explicit setting for resource name is provided primarily for testing. Production setups should leave this unset.

If "customResourceName" is not set, the lowercase version of the "product" setting will be used for the name of the SRS GW CR as well as a name prefix for all secondary resources.

For example, if customResourceName is set, then the SRS credentials secret will be created with the name:
```
    <customResourceName>-srs-creds-secret
```
Otherwise, the SRS credential secret will be created with the name:
```
    <product>-srs-creds-secret
```

Example helm install command line setting:
```
--set customResourceName=objectscale
```

### Global Docker Registry Settings (registry, tag, pullPolicy)
These global settings can be used to configure the Docker registry, tag, and/or
pullPolicy to use for both the remote access and the notifier pods.

Defaults:
* registry: emccorp
* tag: stable
* pullPolicy: Always

Example helm install command line setting:
```
--set registry=mydockerrepo.example.com
--set tag=latest
--set pullPolicy=IfNotPresent
```

### Docker Registry Authentication Credentials
The dockerSecret, or alternatively, the dockerUsername and
dockerPassword, can be used to configure the authentication credentials
for kubelet to use when downloading docker images for the remote access or
notifier deployments from a public Docker registry.

These settings are only necessary when any of the following settings point
to a Docker registry that requires authentication:
* registry
* remoteAccess.registry
* notifier.registry

The dockerSecret allows a user to re-use an existing Docker
registry secret ("bring-your-own" registry secret). Note that when this
option is used, the existing Docker registry secret will be left intact
if/when the SRS gateway custom resource is deleted.

Example helm install command line setting to re-use a docker registry secret:
```
--set dockerSecret=my-existing-registry-secret
```

Alternatively, if dockerUsername and dockerPassword are set, then a Docker
registry secret will be automatically generated using those credentials. In
this case, the name of the secret that is created will be either:
```
    <customResourceName>-docker-secret
```
if customResourceName is set; otherwise, it will be:
```
    <product>-docker-secret
```
Note that when this option is used to have the helm automatically generate
a docker registry secret, then the generated docker registry secret will
get deleted when the associated SRS gateway custom resource is deleted.

Example helm install command line setting to generate a Docker registry
secret:
```
--set dockerUsername=janedoe --set dockerPassword=MyPassword
```

### gateway.disable
The gateway.disable setting allows a user to temporary disable the communication with SRSGateway. When the SRSGateway is in disabled mode, 
the SRS client will not allow any REST API calls to SRS Gateway except for DELETE (so that the product can be unregistered even in the disabled state).

Defaults:
* gateway.disable: false 

Example helm install command line setting:
```
--set gateway.disable=true
```

### gateway.port
The gateway.port setting configures the port on which the SRS Gateway is listening on.

Defaults:
* gateway.port: 9443

Example helm install command line setting:
```
--set gateway.port=4567
```

### remoteAccess Docker Registry Settings
These settings can be used to customize the Docker registry, repository, tag, and pull policy to use for the remoteAccess pod image.

Defaults:
* remoteAccess.registry=emccorp
* remoteAccess.repository=srs-notifier
* remoteAccess.tag=stable
* remoteAccess.pullPolicy=Always

Example helm install command line setting:
```
--set remoteAccess.registry=harbor.lss.emc.com/ecs
--set remoteAccess.repository=my-special-remote-access
--set remoteAccess.tag=latest
--set remoteAccess.pullPolicy=IfNotPresent
```

### notifier Docker Registry Settings
These settings can be used to customize the Docker registry, repository, tag, and pull policy to use for the notifier pod image.

Defaults:
* notifier.registry=emccorp
* notifier.repository=srs-notifier
* notifier.tag=stable
* notifier.pullPolicy=Always

Example helm install command line setting:
```
--set notifier.registry=harbor.lss.emc.com/ecs
--set notifier.repository=my-special-remote-access
--set notifier.tag=latest
--set notifier.pullPolicy=IfNotPresent
```

### remoteAccess User Login Credentials (user, group, password)
These settings can be used to customize the login access to the remote access pod, including user, group, and password to configure.

Defaults:
* remoteAccess.user: root
* remoteAccess.group: adm
* remoteAccess.password: ChangeMe

Example helm install command line setting:
```
--set remoteAccess.user=admin
--set remoteAccess.group=adm
--set remoteAccess.password=P@ssw0rd
```

### grpcConnTimeout, grpcRetries
These settings can be used to configure the timeout interval and the number of retries for the SRS notifier pod when it tries to send events to the SRS gateway.

Defaults:
* notifier.grpcConnTimeout: 5
* notifier.grpcRetries: 5

Example helm install command line setting:
```
--set notifier.grpcConnTimeout=10
--set notifier.grpcRetries=6
```
