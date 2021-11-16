kind   = "service-splitter"
name   = "greeting"
splits = [
  {
    Weight        = 0
    ServiceSubset = "blue"
  },
  {
    Weight        = 100
    ServiceSubset = "green"
  }
]
