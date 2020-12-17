
#####################
# BUILD ARGS
#########

FROM alpine

WORKDIR /root

#####################
# TERRAFORM
#########

ARG TERRAFORM_VERSION=0.14.2
ARG TERRAFORM_SHA256SUM=6f380c0c7a846f9e0aedb98a2073d2cbd7d1e2dc0e070273f9325f1b69e668b2

# Because the builder downloads the latest akamai provider,
# subsequent terraform init calls will download to this directory
# if required, and create a hard link otherwise.
ARG TF_PLUGIN_CACHE_DIR="/var/terraform/plugins"
ENV TF_PLUGIN_CACHE_DIR="${TF_PLUGIN_CACHE_DIR}"

# ca-certificates: Required by `terraform init` when downloading provider plugins.
# curl: depends on ca-certificates, but specifying ca-certificates explicitly
# upx: compress executables
RUN apk add --no-cache ca-certificates curl \
  && curl https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip > terraform_${TERRAFORM_VERSION}_linux_amd64.zip \
  && echo "${TERRAFORM_SHA256SUM} *terraform_${TERRAFORM_VERSION}_linux_amd64.zip" > terraform_${TERRAFORM_VERSION}_SHA256SUMS \
  && sha256sum -c terraform_${TERRAFORM_VERSION}_SHA256SUMS \
  && unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip -d /usr/local/bin \
  && rm -f terraform_${TERRAFORM_VERSION}_linux_amd64.zip terraform_${TERRAFORM_VERSION}_SHA256SUMS

# initialize providers
COPY files/init.tf init.tf
RUN mkdir -p ${TF_PLUGIN_CACHE_DIR} \
  && terraform init -input=false -backend=false -get-plugins=true -verify-plugins=true \
  && rm init.tf

#####################
# JSONNET
#########

ENV GOROOT /usr/lib/go
ENV GOPATH /go
ENV PATH /go/bin:$PATH

RUN apk add --no-cache bash gcc musl-dev openssl go git libstdc++ \
  && git clone --depth 1 https://github.com/google/go-jsonnet.git \
  && cd go-jsonnet \
  && go build -o /bin/jsonnet -ldflags="-s -w" ./cmd/jsonnet \
  && go build -o /bin/jsonnetfmt -ldflags="-s -w" ./cmd/jsonnetfmt \
  && chmod +x /bin/jsonnet*

#####################
# AKAMAI CLI
#########

ARG AKAMAI_CLI_HOME=/cli
ENV AKAMAI_CLI_HOME=${AKAMAI_CLI_HOME}
ENV AKAMAI_CLI_CACHE_PATH=${AKAMAI_CLI_HOME}/.akamai-cli/cache

COPY files/akamai-cli-config /cli/.akamai-cli/config

RUN go get -d github.com/akamai/cli \
  && cd $GOPATH/src/github.com/akamai/cli \
  && go mod init \
  && go mod tidy \
  # -ldflags="-s -w" strips debug information from the executable 
  && go build -o /bin/akamai -ldflags="-s -w" \
  && chmod +x /bin/akamai

#####################
# AKAMAI CLI MODULES
#########

# cli-property-manager
RUN apk add --no-cache npm nodejs \
  && akamai install property-manager

# cli-terraform
RUN apk add --no-cache npm nodejs \
  && akamai install terraform

# cli-jsonnet (for some reason, does not find pip3)
RUN apk add --no-cache python3 py3-pip gcc python3-dev py3-setuptools libffi-dev musl-dev openssl-dev \
  && cd /cli/.akamai-cli/src \
  && git clone --depth 1 https://github.com/akamai-contrib/cli-jsonnet.git \
  && pip3 install -r cli-jsonnet/requirements.txt

#####################
# HTTPIE & HTTPIE EDGEGRID
#########

RUN pip3 install httpie httpie-edgegrid

#####################
# BOSSMAN
#########

RUN pip3 install bossman

#####################
# SUGAR
#########

# This is the interactive shell container, so people will be more
# familiar with bash than ash
RUN apk add --no-cache bash jq git vim tree bind-tools libstdc++ \
  && sed -i s_/bin/ash_/bin/bash_g /etc/passwd

COPY files/motd /etc/motd
COPY files/profile /etc/profile

# This pattern allows us to execute a command
# `docker run ... akamai property ...`
# ... or simply run bash
# `docker run ...`
ENTRYPOINT ["/bin/bash", "-lc", "${0} ${1+\"$@\"}"]
