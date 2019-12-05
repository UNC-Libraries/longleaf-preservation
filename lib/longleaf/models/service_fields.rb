module Longleaf
  # Constants for common configuration fields for preservation service definitions
  class ServiceFields
    WORK_SCRIPT = 'work_script'
    WORK_CLASS = 'work_class'
    FREQUENCY = 'frequency'
    DELAY = 'delay'

    REPLICATE_TO = 'to'
    DIGEST_ALGORITHMS = 'algorithms'

    COLLISION_PROPERTY = "replica_collision_policy"
    DEFAULT_COLLISION_POLICY = "replace"
    VALID_COLLISION_POLICIES = ["replace"]
  end
end
