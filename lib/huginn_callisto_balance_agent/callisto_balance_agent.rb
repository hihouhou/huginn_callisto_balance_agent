module Agents
  class CallistoBalanceAgent < Agent
    include FormConfigurable

    can_dry_run!
    no_bulk_receive!
    default_schedule "never"

    description do
      <<-MD
      The Callisto balance agent fetches callisto's balance from callisto explorer

      `expected_receive_period_in_days` is used to determine if the Agent is working. Set it to the maximum number of days
      that you anticipate passing without this Agent receiving an incoming Event.
      MD
    end

    event_description <<-MD
      Events look like this:
        {
          "balance": xxxx,
          "balanceUSD": xxxx,
          "address": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
          "crypto": "CLO"
        }
    MD

    def default_options
      {
        'wallet_address' => '',
        'expected_receive_period_in_days' => '2',
        'changes_only' => 'true'
      }
    end

    form_configurable :expected_receive_period_in_days, type: :string
    form_configurable :wallet_address, type: :string
    form_configurable :changes_only, type: :boolean

    def validate_options
      unless options['wallet_address'].present?
        errors.add(:base, "wallet_address is a required field")
      end

      if options.has_key?('changes_only') && boolify(options['changes_only']).nil?
        errors.add(:base, "if provided, changes_only must be true or false")
      end

      unless options['expected_receive_period_in_days'].present? && options['expected_receive_period_in_days'].to_i > 0
        errors.add(:base, "Please provide 'expected_receive_period_in_days' to indicate how many days can pass before this Agent is considered to be not working")
      end
    end

    def working?
      memory['last_status'].to_i > 0

      return false if recent_error_logs?
      
      if interpolated['expected_receive_period_in_days'].present?
        return false unless last_receive_at && last_receive_at > interpolated['expected_receive_period_in_days'].to_i.days.ago
      end

      true
    end

    def check
      handle interpolated[:wallet_address]
    end

    private

    def handle(wallet)

        uri = URI.parse("https://explorer2.callisto.network/web3relay")
        request = Net::HTTP::Post.new(uri)
        request.content_type = "application/json;charset=UTF-8"
        request["Authority"] = "explorer2.callisto.network"
        request["Accept"] = "application/json, text/plain, */*"
        request["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/83.0.4103.97 Safari/537.36"
        request["Origin"] = "https://explorer2.callisto.network"
        request["Sec-Fetch-Site"] = "same-origin"
        request["Sec-Fetch-Mode"] = "cors"
        request["Sec-Fetch-Dest"] = "empty"
        request["Referer"] = "https://explorer2.callisto.network/addr/#{wallet}"
        request["Accept-Language"] = "fr,en-US;q=0.9,en;q=0.8"
        request.body = '{"addr":"' + wallet + '","options":["balance"]}'

        req_options = {
          use_ssl: uri.scheme == "https",
        }

        response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
          http.request(request)
        end

        payload = response.body
        payload = JSON.parse(payload)
        payload.merge!({ :address => wallet, :crypto => "CLO" })

        if interpolated['changes_only'] == 'true'
          if payload.to_s != memory['last_status']
            memory['last_status'] = payload.to_s
            create_event payload: payload
          end
        else
          create_event payload: payload
          if payload.to_s != memory['last_status']
            memory['last_status'] = payload.to_s
          end
        end
    end
  end
end
