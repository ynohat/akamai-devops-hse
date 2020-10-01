# Akamai for HSE

This is a specialized docker image for Akamai devops focused on:

* terraform
* config as code using jsonnet templates

See the Dockerfile for installed components.

## Usage

This is an example, do customize to your needs.

```bash
docker run -it --rm -v ~/.edgerc:/root/.edgerc -v $PWD/work ynohat/akamai-devops-hse
```
