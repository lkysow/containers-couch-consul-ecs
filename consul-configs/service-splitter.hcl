kind   = "service-splitter"
name   = "greeting"
splits = [
  {
    Weight        = 0
    ServiceSubset = "all"
  },
  {
    Weight        = 100
    ServiceSubset = "german"
  }
]
