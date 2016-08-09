class BatchApplication < ActiveRecord::Base
  include Taggable

  FEE = 3000

  belongs_to :batch
  belongs_to :application_stage
  has_many :application_submissions, dependent: :destroy
  has_and_belongs_to_many :batch_applicants
  belongs_to :team_lead, class_name: 'BatchApplicant'
  belongs_to :university
  has_one :payment, dependent: :restrict_with_error
  has_many :archived_payments, class_name: 'Payment', foreign_key: 'original_batch_application_id'

  scope :selected, -> { joins(:application_stage).where(application_stages: { final_stage: true }) }

  # Batch applicants who haven't initiated payment yet.
  scope :submitted_application, -> { joins('LEFT OUTER JOIN payments on batch_applications.id = payments.batch_application_id').where(payments: { id: nil }) }

  # Batch applicants who have initiated payment, but haven't completed it.
  scope :payment_initiated, -> { joins(:payment).merge(Payment.requested) }

  # Batch applicants who have completed payment.
  scope :payment_complete, -> { joins(:payment).merge(Payment.paid) }

  validates :application_stage_id, presence: true
  validates :university_id, presence: true
  validates :college, presence: true

  # If a team lead is present (should be), display his name and batch number as title, otherwise use this entry's ID.
  def display_name
    if team_lead.present?
      if batch.present?
        "#{team_lead&.name} (#{batch.name})"
      else
        "#{team_lead&.name} (Batch Pending)"
      end
    else
      "Batch Application ##{id}"
    end
  end

  # Batch application's score is current stage's submission's score.
  def score
    application_submissions.find_by(application_stage_id: application_stage.id)&.score
  end

  # Promotes this application to the next stage, and returns the latest stage.
  def promote!
    if promotable?
      self.application_stage = application_stage.next
      save!
    end

    application_stage
  end

  # Application is promotable is it's on the same stage as its batch, or if application stage is 1, and batch is in stage 2.
  def promotable?
    application_stage == batch.application_stage || (application_stage.initial_stage? && batch.application_stage.number == 2)
  end

  def cofounders
    batch_applicants.where.not(id: team_lead_id)
  end

  # Fee amount, calculated from unpaid founders
  def fee
    FEE
  end

  # Batch application is paid depending on its payment request status.
  def paid?
    return false if payment.blank?
    payment.paid?
  end

  def invite_applicants!
    # create unique tokens using time and id
    startup_token = Time.now.in_time_zone('Asia/Calcutta').strftime('%a, %e %b %Y, %I:%M:%S %p IST') + " ID#{id}"

    Founder.transaction do
      # Invite team lead.
      Founder.invite! email: team_lead.email, invited_batch: batch, startup_token: startup_token, startup_admin: true

      # Invite cofounders one by one.
      cofounders.each do |cofounder|
        Founder.invite! email: cofounder.email, invited_batch: batch, startup_token: startup_token
      end
    end
  end

  # Called after payment is known to have succeeded. This automatically promotes stage 1 applications to stage 2.
  def perform_post_payment_tasks!
    promote! if application_stage.initial_stage?
  end

  # Destroys all trace of an application so that applicant can start again.
  def restart!
    raise 'Paid payment is present!' if paid?
    raise "Restart blocked because application is in stage #{application_stage.number}" unless application_stage.initial_stage?

    # Destroy payment if it exists.
    if payment.present?
      payment.archive!
      reload
    end

    # Destory self.
    destroy!
  end
end
