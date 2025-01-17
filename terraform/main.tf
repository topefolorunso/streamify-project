terraform {
  required_version = ">=1.0"
  backend "local" {}
  required_providers {
    google = {
      source = "hashicorp/google"
    }
  }
}

provider "google" {
  project = var.project
  region  = var.region
  zone    = var.zone
}


resource "google_compute_firewall" "allow_spark_on_9092" {
  project     = var.project
  name        = "allow-spark-connection"
  network     = var.network
  description = "Opens port 9092 on the Kafka VM for Spark cluster to connect"

  allow {
    protocol = "tcp"
    ports    = ["9092"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["kafka", "spark"]

}

resource "google_compute_instance" "kafka_vm" {
  name                      = "musicaly-kafka-vm"
  machine_type              = "e2-standard-2"
  tags                      = ["kafka", "eventsim"]
  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = var.vm_image
      size  = 30
    }
  }

  network_interface {
    network = var.network
    access_config {
    }
  }
}


resource "google_compute_instance" "airflow_vm" {
  name                      = "musicaly-airflow-vm"
  machine_type              = "e2-standard-2"
  tags                      = ["airflow", "dbt"]
  allow_stopping_for_update = true

  boot_disk {
    initialize_params {
      image = var.vm_image
      size  = 30
    }
  }

  network_interface {
    network = var.network
    access_config {
    }
  }
}

resource "google_storage_bucket" "musicaly_bucket" {
  name          = var.bucket
  location      = var.region
  force_destroy = true

  uniform_bucket_level_access = true

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = 30 # days
    }
  }
}


resource "google_dataproc_cluster" "musicaly_spark_cluster" {
  name   = "musicaly-spark-cluster"
  region = var.region

  cluster_config {

    staging_bucket = var.bucket

    gce_cluster_config {
      network = var.network
      zone    = var.zone

      shielded_instance_config {
        enable_secure_boot = true
      }
    }

    master_config {
      num_instances = 1
      machine_type  = "e2-standard-2"
      disk_config {
        boot_disk_type    = "pd-ssd"
        boot_disk_size_gb = 30
      }
    }

    software_config {
      image_version = "2.0-debian10"
      override_properties = {
        "dataproc:dataproc.allow.zero.workers" = "true"
      }
      optional_components = ["JUPYTER"]
    }

  }

}

resource "google_bigquery_dataset" "staging_dataset" {
  dataset_id                 = var.staging_bigquery_dataset
  project                    = var.project
  location                   = var.region
  delete_contents_on_destroy = true
}

resource "google_bigquery_dataset" "production_dataset" {
  dataset_id                 = var.production_bigquery_dataset
  project                    = var.project
  location                   = var.region
  delete_contents_on_destroy = true
}