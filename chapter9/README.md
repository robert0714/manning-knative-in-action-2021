# Knative Example Concourse Pipeline

This repo contains an example of using [Concourse](https://concourse-ci.org/) and [`ytt`](https://get-ytt.io/) to roll out a Knative Service, triggered by a new image.

The example was developed for Chapter 9 of [Knative in Action](https://www.manning.com/books/knative-in-action).

I don't support this repo at all. Feel free to study it, but I'm unlikely to answer questions or respond to PRs quickly.

## Setting the pipeline

```bash
fly --target name_of_your_concourse_target \
	set-pipeline \
	--pipeline knative-example-dev \
	--config concourse/pipeline.yml \
	--var cluster_api=$(kubectl config view --minify -o jsonpath='{.clusters[].cluster.server}') \
	--var cluster_ca=$(kubectl config view --flatten --minify -o jsonpath='{.clusters[].cluster.certificate-authority-data}') \
	--var cluster_token=$(kubectl config view --minify -o jsonpath='{.users[].user.auth-provider.config.access-token}') \
	--var git_repository_uri='git@ ... URI for your git repo' \
	--var git_private_key=$(cat /path/to/your/private/key) \
	--var git_name='The name you use for git commits' \
	--var git_email='The email address you use for git commits'
```

## Not suitable for production use

Like the header says, and the book says, this is a simple example, not a robust solution.

In particular, this example repo has _both_ the pipeline configuration _and_ the history of rendered templates. In a real setup, the rendered templates would be written to and read from a dedicated 'robots' or 'history' repository.
