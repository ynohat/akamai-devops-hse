terraform {
  required_providers {
    jsonnet = {
      source = "alxrem/jsonnet"
      version = "1.0.1"
    }

    akamai = {
      source = "akamai/akamai"
      version = "0.9.1"
    }
  }
}
