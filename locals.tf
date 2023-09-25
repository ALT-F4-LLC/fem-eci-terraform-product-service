locals {
  services = {
    for service in data.tfe_outputs.tfe.nonsensitive_values.services : service.name => {
      parameters = try(service.parameters, [])
    }
  }
}
