require 'rails_helper'
require 'huginn_agent/spec_helper'

describe Agents::CallistoBalanceAgent do
  before(:each) do
    @valid_options = Agents::CallistoBalanceAgent.new.default_options
    @checker = Agents::CallistoBalanceAgent.new(:name => "CallistoBalanceAgent", :options => @valid_options)
    @checker.user = users(:bob)
    @checker.save!
  end

  pending "add specs here"
end
