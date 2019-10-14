# Sonobuoy Helm Chart

This Helm chart deploys [sonobuoy](https://github.com/heptio/sonobuoy), a diagnostic tool that runs kubernetes conformance tests.

## Table of Contents
* [Description](#description)
* [Requirements](#requirements)
* [Quick Start](#quick-start)

## Description

Sonobuoy is an open-source diagnostic tool that makes it easier to understand the state of a Kubernetes cluster by running a set of upstream Kubernetes tests in an accessible and non-destructive manner. Current Kubernetes conformance test suite is [here](https://github.com/cncf/k8s-conformance/blob/master/docs/KubeConformance-1.11.md).

## Requirements

* A [Helm](https://helm.sh) installation with access to install to one or more namespaces.
* Access to an up-and-running Kubernetes cluster.
* Install decks/webdav before installing sonobuoy

## Quick Start

1. First, [install and setup Helm](https://docs.helm.sh/using_helm/#quickstart).  *_Note:_* you'll likely need to setup role-based access controls for Helm to have rights to install packages, so be sure to read that part.

2. Setup the [EMCECS Helm Repository](https://github.com/EMCECS/charts).

```bash
$ helm repo add ecs https://emcecs.github.io/charts
$ helm repo update
```

3. Install sonobuoy. This allows you to create related resources of sonobuoy to run K8S confoemance tests. The tests are run through cronjob. It will generate jobs to run sonobuoy pods to run conformance tests every x hours/days(depend on your need).

```bash
$ helm install --name sonobuoy-test ecs/sonobuoy
NAME:   sonobuoy-test
```

4. You can check the latest test log here. 
```bash
$ kubectl logs sonobuoy -n heptio-sonobuoy > temp.log
$ vim temp.log
...
```
 Also the tests result will be sent by webdav when all tests are finished.
