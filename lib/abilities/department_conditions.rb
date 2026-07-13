# frozen_string_literal: true

module Abilities
  module DepartmentConditions
    module_function

    def template_collection(user)
      ids = user.department_ids

      return Template.none if ids.blank?

      Abilities::TemplateConditions
        .collection(user)
        .joins(:template_departments)
        .where(template_departments: { department_id: ids })
        .distinct
    end

    def template_entity(template, user:, ability: nil)
      return true if user.department_acl_admin?
      return false unless Abilities::TemplateConditions.entity(template, user:, ability:)

      ids = user.department_ids

      return false if ids.blank?

      template.department_ids.any? { |department_id| ids.include?(department_id) }
    end

    def submission_collection(user)
      ids = user.department_ids

      return Submission.none if ids.blank?

      Submission
        .where(account_id: user.account_id)
        .joins(template: :template_departments)
        .where(template_departments: { department_id: ids })
        .distinct
    end

    def submission_entity(submission, user:)
      return true if user.department_acl_admin?
      return false unless submission.account_id == user.account_id
      return false if submission.template.blank?

      template_entity(submission.template, user:, ability: 'manage')
    end

    def submitter_collection(user)
      ids = user.department_ids

      return Submitter.none if ids.blank?

      Submitter
        .where(account_id: user.account_id)
        .joins(submission: { template: :template_departments })
        .where(template_departments: { department_id: ids })
        .distinct
    end

    def submitter_entity(submitter, user:)
      return true if user.department_acl_admin?
      return false unless submitter.account_id == user.account_id
      return false if submitter.submission.blank?

      submission_entity(submitter.submission, user:)
    end
  end
end