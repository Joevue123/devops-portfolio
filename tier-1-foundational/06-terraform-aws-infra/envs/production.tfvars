environment          = "production"
instance_type        = "t3.medium"
asg_min_size         = 2
asg_max_size         = 10
asg_desired_capacity = 2
db_instance_class    = "db.t3.medium"
redis_node_type      = "cache.t3.small"
