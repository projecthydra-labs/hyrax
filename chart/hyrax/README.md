Hyrax Helm
==========

This [Helm][helm] chart provides configurable deployments for Hyrax applications
to [Kubernetes][k8s] clusters. It seeks to be a complete but flexible
production-ready setup for Hyrax applications. By default it deploys:

  - A Hyrax-based Rails application
  - Fedora Commons v4.7
  - Postgresql
  - Solr (in a cloud configuration, including Apache Zookeeper)
  - Redis

## A base Hyrax deployment

Because Hyrax is a [Rails Engine][engine]---not a stand-alone application---
deploying it requires us to have a specific application. This chart assumes that
the user has a container image based on `samveralabs/hyrax` (see:
[CONTAINERS.md][containers]) that includes their application. Point the chart at
your image by setting the `image.repository` and `image.tag` values.

By default, the chart deploys [images][dassie-images] for Hyrax's development
application, [`dassie`][dassie].

For application configuration, we take our queues from [12-factor][twelve]
methodology. Applications using environment variables to manage their
configuration can be easily reconfigured across different releases using this
chart; e.g. the same chart can be used to deploy sandbox, staging, and
production environments.

The chart populates the following environment variables:

| Variable          | Description                    | Condition              |
|-------------------|--------------------------------|------------------------|
| DB_PASSWORD       | Postgresql password            | n/a                    |
| DB_PORT           | Postgresql service port        | n/a                    |
| DB_HOST           | Postgresql hostname            | n/a                    |
| DB_USERNAME       | Postgresql username            | n/a                    |
| MEMCACHED_HOST    | Memcached host                 | `memcached.enabled`    |
| RACK_ENV          | app environment ('production') | n/a                    |
| RAILS_ENV         | app environment ('production') | n/a                    |
| REDIS_HOST        | Redis service host             | `redis.enabled`        |
| FCREPO_BASE_PATH  | Fedora Commons root path       | n/a                    |
| FCREPO_HOST       | Fedora Commons host            | n/a                    |
| FCREPO_PORT       | Fedora Commons port            | n/a                    |
| FCREPO_REST_PATH  | Fedora Commons REST endpoint   | n/a                    |
| SKIP_HYRAX_ENGINE_SEED   | Flag to load Hyrax engine seed file | n/a                    |
| SOLR_ADMIN_USER   | Solr user for basic auth       | n/a                    |
| SOLR_ADMIN_PASSWORD | Solr password for basic auth | n/a                    |
| SOLR_COLLECTION_NAME | The name of the solr collection to use | n/a         |
| SOLR_CONFIGSET_NAME | The name of the solr configset to use for config management tasks | n/a |
| SOLR_HOST         | Solr service host              | n/a                    |
| SOLR_PORT         | Solr service port              | n/a                    |
| SOLR_URL          | Solr service full URL          | n/a                    |

## With an external SolrCloud

By default, this chart deploys and manages an internal SolrCloud deployment,
complete with its own ZooKeeper service.

To use an existing or externally managed SolrCloud, use the chart values:

  - `solr.enabled`: false
  - `externalSolrHost`: "mySolr.hostname.example.com"
  - `externalSolrUser`: "admin"
  - `externalSolrPassword`: "the_admin_password"
  - `externalSolrCollection`: "a_collection_name"

The chart will attempt to upload a ConfigSet for Hyrax matching the deployment's
"fullname" and assign it to the collection. This is achieved through the Solr
Collections API, and authentication _must_ be enabled in the external Solr for
this to work.

If you want to manage your ConfigSet manually, disable this behavior with
`--set loadSolrConfigSet=false`.

## With an external Fedora Commons Repository

By default, this chart deploys a local Fedora Repository, backed by the
application's Postgresql system.

To use an existing or external `fcrepo` instance, use the chart values:

  - `fcrepo.enabled`: false
  - `externalFcrepoHost`: "myfedora.hostname.example.com"

## For DevOps:

For those interested in trying out or contributing to this Chart, it's helpful
to setup a simple cluster locally. Various projects exist to make this easy; we
recommend [`k3d`][k3d] or [minikube][minikube].

For example, with `k3d`:

```sh
k3d cluster create dev-cluster --api-port 6550 -p 80:80@loadbalancer --agents 3
```

[containers]: ../../CONTAINERS.md#hyrax-image
[dassie]: ../../.dassie/README.md
[dassie-image]: https://hub.docker.com/r/samveralabs/dassie
[engine]: https://guides.rubyonrails.org/engines.html
[helm]: https://helm.sh
[k3d]: https://k3d.io
[k8s]: https://kubernetes.io
[minikube]: https://minikube.sigs.k8s.io/docs/
