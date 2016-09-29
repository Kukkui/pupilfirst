class AdmissionStatsNotificationJob < ActiveJob::Base
  queue_as :default
  attr_reader :batch, :stats

  def perform
    # @batch = Batch.open_for_applications.order(:start_date).first
    @batch = Batch.last
    return unless batch.present?
    @stats = AdmissionStatsService.load_stats(batch)

    slack_webhook_url = Rails.application.secrets.slack_general_webhook_url
    json_payload = { 'text': admission_stats_summary }.to_json
    RestClient.post(slack_webhook_url, json_payload)
  end

  private

  def admission_stats_summary
    <<~MESSAGE
      > Here are the *Admission Stats for Batch #{batch.batch_number}* today:
      _Payments Completed:_ #{stats[:paid_applications]} (+#{stats[:paid_applications_today]})
      _Payments Intiated:_ #{stats[:payment_initiated]} (+#{stats[:payment_initiated_today]})
      _Applications Started:_ #{stats[:submitted_applications]} (+#{stats[:submitted_applications_today]})
      _Paid Applications From:_ #{state_wise_paid_count}
      _Unique Visits Today:_ #{stats[:total_visits_today]}
    MESSAGE
  end

  def state_wise_paid_count
    message = State.focused_for_admissions.each_with_object('') do |state, string|
      count = stats[:state_wise_stats][state.name.to_sym][:paid_applications]
      string << "#{state.name}(#{count}) " if count.positive?
    end

    others_count = stats[:state_wise_stats][:Others][:paid_applications]
    message << "Others(#{others_count})" if others_count.positive?

    message
  end
end
