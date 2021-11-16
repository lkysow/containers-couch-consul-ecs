kind = "service-resolver"
name = "greeting"
default_subset = "all"
subsets = {
  all = {
    filter = "\"german\" not in ServiceTags"
  }
  german = {
    filter = "\"german\" in ServiceTags"
  }
}
