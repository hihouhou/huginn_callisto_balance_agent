module Agents
  class CallistoBalanceAgent < Agent
    include FormConfigurable

    can_dry_run!
    no_bulk_receive!
    default_schedule "never"

    description do
      <<-MD
      The Callisto balance agent fetches callisto's balance from callisto explorer

      `debug` is used to verbose mode.

      `decimal` for token decimal.

      `expected_receive_period_in_days` is used to determine if the Agent is working. Set it to the maximum number of days
      that you anticipate passing without this Agent receiving an incoming Event.
      MD
    end

    event_description <<-MD
      Events look like this:

          {
            "message": "OK",
            "result": "8000000203531297540461059",
            "status": "1",
            "address": "0xXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
            "crypto": "CLO",
            "value": 8000000.2035312975404
          }
    MD

    def default_options
      {
        'debug' => 'false',
        'wallet_address' => '',
        'decimal' => '18',
        'expected_receive_period_in_days' => '2',
        'changes_only' => 'true'
      }
    end

    form_configurable :debug, type: :boolean
    form_configurable :expected_receive_period_in_days, type: :string
    form_configurable :wallet_address, type: :string
    form_configurable :decimal, type: :string
    form_configurable :changes_only, type: :boolean

    def validate_options
      unless options['wallet_address'].present?
        errors.add(:base, "wallet_address is a required field")
      end

      unless options['decimal'].present?
        errors.add(:base, "decimal is a required field")
      end

      if options.has_key?('debug') && boolify(options['debug']).nil?
        errors.add(:base, "if provided, debug must be true or false")
      end

      if options.has_key?('changes_only') && boolify(options['changes_only']).nil?
        errors.add(:base, "if provided, changes_only must be true or false")
      end

      unless options['expected_receive_period_in_days'].present? && options['expected_receive_period_in_days'].to_i > 0
        errors.add(:base, "Please provide 'expected_receive_period_in_days' to indicate how many days can pass before this Agent is considered to be not working")
      end
    end

    def working?
      event_created_within?(options['expected_receive_period_in_days']) && !recent_error_logs?
    end

    def check
      handle interpolated[:wallet_address]
    end

    private

    def handle(wallet)

      uri = URI.parse("https://explorer.callisto.network/api?module=account&action=balance&address=#{wallet}")
      request = Net::HTTP::Get.new(uri)
      request["Accept"] = "application/json"

      req_options = {
        use_ssl: uri.scheme == "https",
      }

      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end

      log "fetch event request status : #{response.code}"

      payload = JSON.parse(response.body)
      parsed = JSON.parse(response.body)

      if interpolated['debug'] == 'true'
        log payload
      end
      power = 10 ** interpolated['decimal'].to_i
      value = payload['result'].to_f / power.to_i
      parsed.merge!({ "address" => wallet, "crypto" => "CLO", "value" => value })

      if interpolated['changes_only'] == 'true'
        if payload.to_s != memory['last_status']
          memory['last_status'] = payload.to_s
          create_event payload: parsed
        end
      else
        create_event payload: parsed
        if payload.to_s != memory['last_status']
          memory['last_status'] = payload.to_s
        end
      end
    end
  end
end
