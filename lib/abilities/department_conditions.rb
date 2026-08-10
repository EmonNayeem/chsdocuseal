# frozen_string_literal: true

module Abilities
  module DepartmentConditions
    module_function

    def template_collection(user)
      return Abilities::TemplateConditions.collection(user) if user.platform_admin?

      ids = user.department_ids

      return Template.none if ids.blank?

      Abilities::TemplateConditions
        .collection(user)
        .joins(:template_departments)
        .where(template_departments: { department_id: ids })
        .distinct
    end

    def template_entity(template, user:, ability: nil)
      return false unless Abilities::TemplateConditions.entity(template, user:, ability:)
      return true if user.platform_admin?
      return true if user.department_acl_admin?

      ids = user.department_ids

      return false if ids.blank?

      template.department_ids.any? { |department_id| ids.include?(department_id) }
    end

    def submission_collection(user)
      return Submission.where(account_id: user.account_id) if user.platform_admin?

      ids = user.department_ids

      return Submission.none if ids.blank?

      Submission
        .where(account_id: user.account_id, company_id: user.company_id)
        .joins(template: :template_departments)
        .where(template_departments: { department_id: ids })
        .distinct
    end

    def submission_entity(submission, user:)
      return false unless submission.account_id == user.account_id
      return true if user.platform_admin?
      return false unless submission.company_id == user.company_id

      return true if user.department_acl_admin?
      return false if submission.template.blank?

      template_entity(submission.template, user:, ability: 'manage')
    end

    def submitter_collection(user)
      return Submitter.where(account_id: user.account_id) if user.platform_admin?

      ids = user.department_ids

      return Submitter.none if ids.blank?

      Submitter
        .where(account_id: user.account_id, company_id: user.company_id)
        .joins(submission: { template: :template_departments })
        .where(template_departments: { department_id: ids })
        .distinct
    end

    def submitter_entity(submitter, user:)
      return false unless submitter.account_id == user.account_id
      return true if user.platform_admin?
      return false unless submitter.company_id == user.company_id

      return true if user.department_acl_admin?
      return false if submitter.submission.blank?

      submission_entity(submitter.submission, user:)
    end
  end
end