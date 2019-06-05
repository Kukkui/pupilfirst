class CommunityPolicy < ApplicationPolicy
  def show?
    return false if scope.blank?

    scope.where(id: record.id).exists?
  end

  class Scope < Scope
    def resolve
      # Pupilfirst doesn't have community.
      return scope.none if current_school.blank?

      # Community is not open for public.
      return scope.none if user.blank?

      # Coach has access to all communities in a school.
      return scope.where(school: current_school) if current_coach.present?

      course_ids = user.founders.where(exited: false).joins(:course).select(:course_id)
      scope.where(school: current_school).joins(:courses).where(courses: { id: course_ids }).distinct
    end
  end
end
