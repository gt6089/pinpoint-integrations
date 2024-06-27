require 'sinatra'
require 'faraday'
require 'dotenv/load'
require 'json'
require 'debug'

post '/pinpoint/application-hired' do
  event_data = JSON.parse(request.body.read)["data"]
  application_id = event_data["application"]["id"]

  ProcessPinpointApplicationHired.new(application_id).run

  return 200
end

class ProcessPinpointApplicationHired
  PINPOINT_API_URL = "developers-test.pinpointhq.com/api/v1"
  HIBOB_API_URL = "api.hibob.com/v1"

  attr_reader :pinpoint_application_id, :hibob_employee_id, :errors

  def initialize(application_id)
    @pinpoint_application_id = application_id
    @pinpoint_application = nil
    @hibob_employee_id = nil
    @errors = []
  end

  def run
    puts "Processing application hired event for Pinpoint application #{pinpoint_application_id}"

    fetch_pinpoint_application
    create_hibob_employee
    upload_employee_cv
    update_pinpoint_application

    puts "Finished processing application hired event for Pinpoint application #{pinpoint_application_id}"
  rescue => error
    puts "Run failed with errors", @errors
  end

  private

  def pinpoint_api
    Faraday.new(
      url: "https://#{PINPOINT_API_URL}",
      headers: {
        'X-API-KEY': ENV['PINPOINT_API_KEY']
      }
    ) do |conn|
      conn.request :json
      conn.response :raise_error
    end
  end

  def fetch_pinpoint_application
    puts "Fetching Pinpoint application #{pinpoint_application_id}"

    response = pinpoint_api.get("applications/#{pinpoint_application_id}") do |req|
      req.params["extra_fields[applications]"] = "attachments"
    end

    data = JSON.parse(response.body)["data"]

    @pinpoint_application = PinpointApplication.new(data)
  rescue => error
    @errors << { message: "Failed to fetch Pinpoint application", error: error }
    raise
  end

  def hibob_api
    Faraday.new(
      url: "https://#{HIBOB_API_URL}",
      headers: {
        'Authorization': "Basic #{hibob_token}",
        'Content-Type': 'application/json'
      }
    ) do |conn|
      conn.request :json
      conn.response :raise_error
    end
  end

  def hibob_token
    @hibob_token ||= begin
      username = ENV["HIBOB_USER_ID"]
      password = ENV["HIBOB_PASSWORD"]

      Base64.strict_encode64("#{username}:#{password}")
    end
  end

  def create_hibob_employee
    puts "Creating Hibob employee for Pinpoint application #{pinpoint_application_id}"

    request_data = {
      firstName: @pinpoint_application.first_name,
      surname: @pinpoint_application.last_name,
      email: 'kdoyle+test+final@pinpoint.dev',
      work: {
        site: 'New York (Demo)',
        startDate: '2024-08-01',
      }
    }

    response = hibob_api.post('people') do |req|
      req.body = request_data
    end

    response_data = JSON.parse(response.body)

    @hibob_employee_id = response_data["id"]

    puts "Successfully created Hibob employee with id #{@hibob_employee_id}"
  rescue => error
    @errors << { message: "Failed to create Hibob employee", error: error }
    raise
  end

  def upload_employee_cv
    puts "Uploading CV for Hibob employee #{@hibob_employee_id}"

    request_data = {
      documentName: @pinpoint_application.cv_name,
      documentUrl: @pinpoint_application.cv_url
    }

    response = hibob_api.post("docs/people/#{@hibob_employee_id}/shared") do |req|
      req.body = request_data
    end

    puts "Successfully uploaded CV for Hibob employee #{@hibob_employee_id}"
  rescue => error
    @errors << { message: "Failed to upload CV for Hibob employee", error: error }
    raise
  end

  def update_pinpoint_application
    puts "Updating Pinpoint application #{@pinpoint_application.id}"

    request_data = {
      data: {
        type: "comments",
        attributes: {
          body_text: "Record created with ID: #{@hibob_employee_id}"
        },
        relationships: {
          commentable: {
            data: {
              type: "applications",
              id: "#{@pinpoint_application.id}"
            }
          }
        }
      }
    }

    response = pinpoint_api.post("comments") do |req|
      req.body = request_data
    end

    puts "Successfully updated Pinpoint application #{@pinpoint_application.id}"
  rescue => error
    errors << { message: "Failed to update Pinpoint application", error: error }
    raise
  end

  def get_fixture(api, action)
    file_path = File.join(Sinatra::Application.settings.root, "fixtures/#{api}", "#{action}.json")
    json_data = File.read(file_path)
  end
end

class PinpointApplication
  attr_reader :data

  def initialize(data)
    @data = data
  end

  def id
    data["id"]
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

  def cv_name
    cv["filename"]
  end

  def cv_url
    cv["url"]
  end

  def cv
    get_pdf_cv(data["attributes"]["attachments"])
  end

  private

  def get_pdf_cv(attachment_data)
    attachment_data.select {|attachment| attachment["context"] === "pdf_cv" }[0]
  end
end
