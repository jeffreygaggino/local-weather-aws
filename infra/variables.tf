variable "region" {
  type    = string
  default = "ap-southeast-2"
}

variable "image_tag" {
  description = "Image tag in ECR to run; the Makefile passes the git SHA."
  type        = string
}

variable "location" {
  type = object({
    slug      = string
    latitude  = number
    longitude = number
  })
  default = {
    slug      = "mudgeeraba"
    latitude  = -28.08
    longitude = 153.37
  }
}

variable "alert_email" {
  description = "Where alarm emails go. Set it in terraform.tfvars (gitignored)."
  type        = string
}
