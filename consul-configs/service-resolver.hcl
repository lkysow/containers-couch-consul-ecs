kind = "service-resolver"
name = "greeting"
default_subset = "blue"
subsets = {
  blue = {
    filter = "Service.Meta.group == blue"
  }
  green = {
    filter = "Service.Meta.group == green"
  }
}
