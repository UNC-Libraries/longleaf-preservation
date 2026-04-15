module Longleaf
  # System configuration field names
  class SystemConfigFields
    MD_INDEX = 'index'
    MD_INDEX_ADAPTER = 'adapter'
    MD_INDEX_CONNECTION = 'connection'
    MD_INDEX_PAGE_SIZE = 'page_size'
    # Amount of time to wait before retrying a failed service. Follows the same
    # time modifier syntax as service frequency/delay (e.g. "1 day", "4 hours").
    # Defaults to "1 day" if not specified.
    FAILURE_RETRY_DELAY = 'failure_retry_delay'
    DEFAULT_FAILURE_RETRY_DELAY = '1 day'
  end
end
