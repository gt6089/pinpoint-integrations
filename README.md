# Kealy Doyle - Pinpoint Integrations Engineer Assignment

## How to run the app

- Install Ruby 3.3.3
- Install the gems `sinatra`, `rackup`, `puma`, `faraday`, `dotenv`, `json` and `debug`
- Create an `.env` in the app root and populate with `PINPOINT_API_KEY`, `HIBOB_USER_ID` and `HIBOB_PASSWORD`
- Run `ruby main.rb` from the app root
- Send a webhook to `http://localhost:4567/pinpoint/application-hired`

## Tech Stack

- [Sinatra](https://sinatrarb.com/)
- Postman

## Task

In Pinpoint we have multiple webhook events and have a new hired event that fires the example payload, when an applicant has been moved to the hired stage of a job:

```jsx
{
  "event": "application_hired",
  "triggeredAt": 1614687278,
  "data": {
    "application": {
      "id": 1
    },
    "job": {
      "id": 1
    }
  }
}
```

We would like you to work with this webhook, as a trigger for a small app or a server-less process that creates a new employee in our test HiBob account ([Hibob](https://www.hibob.com/) is a common HRIS that a lot of clients use, including ourselves).

**You should**:

- Listen for the new hire event
    - Use Pinpoint application with `id=8863807` for testing. You can also use any other application.
- Create the basic Employee record in HiBob with details from the Pinpoint application
    - The employee should be a part of the `New York (Demo)` work site
    - Any date in the future can be used for start date
- Update the employee record with their CV (that was attached during the application) as a public document in HiBob (use one with `pdf_cv`  context)
- Add a comment on the Pinpoint application stating the record has been created quoting the HiBob Reference ID for the employee record i.e. “Record created with ID: xxxxxx”