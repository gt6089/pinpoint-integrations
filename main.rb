require 'sinatra'
require 'faraday'
require 'dotenv/load'
require 'json'
require 'debug'

post '/application-hired' do
  event_data = JSON.parse(request.body.read)["data"]
  application_id = event_data["application"]["id"]

  ProcessApplicationHired.new(application_id).run

  return 200
end

class ProcessApplicationHired
  PINPOINT_API_URL = "developers-test.pinpointhq.com/api/v1"
  HIBOB_API_URL = "api.hibob.com/v1"

  attr_reader :application_id

  def initialize(application_id)
    @application_id = application_id
    @pinpoint_application = nil
  end

  def run
    fetch_pinpoint_application
    create_hibob_employee
    # update_hibob_employee_with_cv
    # update_pinpoint_application
  end

  private

  def pinpoint_api
    Faraday.new(
      url: "https://#{PINPOINT_API_URL}",
      headers: {
        'X-API-KEY': ENV['PINPOINT_API_KEY']
      }
    )
  end

  def fetch_pinpoint_application
    puts "Fetching Pinpoint application #{application_id}"

    response = pinpoint_api.get("applications/#{application_id}") do |req|
      req.params["extra_fields[applications]"] = "attachments"
    end

    data = JSON.parse(response.body)["data"]

    @pinpoint_application = PinpointApplication.new(data)

    true
  end

  def hibob_api
    Faraday.new(
      url: "https://#{HIBOB_API_URL}",
      headers: {
        'Authorization': "Basic #{hibob_token}",
        'Content-Type': 'application/json'
      }
    )
  end

  def hibob_token
    @hibob_token ||= begin
      username = ENV["HIBOB_USER_ID"]
      password = ENV["HIBOB_PASSWORD"]

      Base64.strict_encode64("#{username}:#{password}")
    end
  end

  def create_hibob_employee
    employee_data = {
      firstName: @pinpoint_application.first_name,
      surname: @pinpoint_application.last_name,
      email: 'kdoyle+test@pinpoint.dev',
      work: {
        site: 'New York (Demo)',
        startDate: '2024-08-01',
      }
    }

    response = hibob_api.post('people') do |req|
      req.body = JSON.generate(employee_data)
    end

    binding.break
  end
end

class PinpointApplication
  attr_reader :data

  def initialize(data)
    @data = data
  end

  def first_name
    data["attributes"]["first_name"]
  end

  def last_name
    data["attributes"]["last_name"]
  end

  def email
    data["attributes"]["email"]
  end

  def cv
    get_pdf_cv(data["attachments"])
  end

  private

  def get_pdf_cv(attachment_data)
    attachment_data.filter(attachment => attachment["context"] === "pdf_cv")
  end
end



# fetch Application from Pinpoint
  # interested in:
    # firstName
    # surname
    # email
    # CV
# create Employee record in Hibob
  # New York (Demo) work site
  # Any future date for start
# Update Hibob employee record with CV from application
  # public document
  # pdf_cv context
# Create comment on Pinpoint application
  # "Record has been created with ID: {hibob reference id}"


# HiBob employee record create params
  # firstName
  # surname
  # email
  # work: { site: string, startDate: <date-in-future> }
