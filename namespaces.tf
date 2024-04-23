# Creating K8s Namespaces 
resource "kubernetes_namespace" "vault" {
  metadata {
    annotations = {
      name = "vault"
    }

    labels = {
      team = "vault"
    }

    name = "vault"
  }
}

resource "kubernetes_namespace" "blue" {
  metadata {
    annotations = {
      name = "blue"
    }

    labels = {
      team = "blue"
    }

    name = "blue"
  }
}

# Creating K8s Namespaces 
resource "kubernetes_namespace" "red" {
  metadata {
    annotations = {
      name = "red"
    }

    labels = {
      team = "red"
    }

    name = "red"
  }
}


# Creating two namespaces under the root namespace
resource "vault_namespace" "red" {
  depends_on = [ helm_release.vault ]
  namespace = var.vault_namespace
  path = "red"
  custom_metadata = {
    team  = "red"
  }
}

resource "vault_namespace" "blue" {
  depends_on = [ helm_release.vault ]
  namespace = var.vault_namespace
  path = "blue"
  custom_metadata = {
    team  = "blue"
  }
}

