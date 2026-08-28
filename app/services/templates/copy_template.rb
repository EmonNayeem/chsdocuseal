# frozen_string_literal: true

module Templates
  class CopyTemplate
    class Error < StandardError; end
    class UnauthorizedError < Error; end
    class InvalidTargetError < Error; end

    def self.call(template:, target_company:, current_user:, target_department_ids: [], target_folder_id: nil,
                  name: nil)
      new(
        template:,
        target_company:,
        current_user:,
        target_department_ids:,
        target_folder_id:,
        name:
      ).call
    end

    def initialize(template:, target_company:, current_user:, target_department_ids: [], target_folder_id: nil,
                   name: nil)
      @template = template
      @target_company = target_company
      @current_user = current_user
      @target_department_ids = Array.wrap(target_department_ids).compact
      @target_folder_id = target_folder_id
      @name = name
    end

    def call
      authorize_copy!
      validate_targets!

      copied_template = Templates::Clone.call(@template, author: @current_user, name: @name)

      copied_template.template_accesses.clear

      copied_template.company = @target_company
      copied_template.account = @target_company.account

      if @target_folder_id.present?
        copied_template.folder_id = @target_folder_id
      else
        copied_template.folder = @target_company.account.default_template_folder
      end

      raise Error, copied_template.errors.full_messages.join(', ') unless copied_template.save

      copied_template.department_ids = @target_department_ids if @target_department_ids.any?

      Templates::CloneAttachments.call(template: copied_template, original_template: @template)

      SearchEntries.enqueue_reindex(copied_template) if defined?(SearchEntries)
      WebhookUrls.enqueue_events(copied_template, 'template.created') if defined?(WebhookUrls)

      copied_template
    end

    private

    def authorize_copy!
      raise UnauthorizedError, 'You are not allowed to copy this template.' unless can_copy?
    end

    def can_copy?
      return true if @current_user.platform_admin?

      if @current_user.department_acl_admin?
        return @current_user.company_id == @target_company.id && @template.company_id == @current_user.company_id
      end

      false
    end

    def validate_targets!
      raise InvalidTargetError, 'Target company is required.' if @target_company.blank?

      if @target_department_ids.any?
        valid_ids = Department.where(id: @target_department_ids, company_id: @target_company.id).pluck(:id)
        if valid_ids.size != @target_department_ids.size
          raise InvalidTargetError, 'Selected departments must belong to the target company.'
        end
      end

      return if @target_folder_id.blank?

      folder = TemplateFolder.find_by(id: @target_folder_id)
      return unless folder.nil? || folder.company_id != @target_company.id

      raise InvalidTargetError, 'Selected folder must belong to the target company.'
    end
  end
end
