class AnalyticsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [ :track ]
  skip_before_action :track_page_view, only: [ :track ]
  skip_before_action :track_session_progression, only: [ :track ]
  skip_after_action :update_session_metadata, only: [ :track ]

  def track
    event_data = JSON.parse(request.body.read)

    # Validate required fields
    unless event_data["event"] && event_data["session_id"]
      render json: { error: "Missing required fields" }, status: :bad_request
      return
    end

    # Add server-side context
    enriched_data = event_data.merge({
      server_timestamp: Time.current.iso8601,
      ip_address: request.remote_ip,
      referer: request.referer,
      user_id: current_user&.id
    })

    # Send to AppSignal
    Appsignal.increment_counter("checkout_funnel.client_event", 1, {
      event: enriched_data["event"],
      session_id: enriched_data["session_id"],
      user_id: enriched_data["user_id"]
    })

    # Log for debugging
    Rails.logger.info("Client Analytics: #{enriched_data['event']} - #{enriched_data}")

    render json: { status: "success" }
  rescue JSON::ParserError
    render json: { error: "Invalid JSON" }, status: :bad_request
  rescue => e
    Rails.logger.error("Analytics tracking error: #{e.message}")
    render json: { error: "Internal error" }, status: :internal_server_error
  end
end
