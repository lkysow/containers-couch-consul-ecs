kind   = "service-splitter"
name   = "greeting"
splits = [
  {
    Weight        = 100
    ServiceSubset = "all"
  },
  {
    Weight        = 0
    ServiceSubset = "german"
  }
]
