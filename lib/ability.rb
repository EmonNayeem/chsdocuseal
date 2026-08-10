# frozen_string_literal: true

class Ability
  include CanCan::Ability

  def initialize(user)
    if user.platform_admin?
      platform_admin_abilities(user)
    elsif user.department_acl_admin?
      admin_abilities(user)
    elsif user.role == User::VIEWER_ROLE
      viewer_abilities(user)
    else
      editor_abilities(user)
    end
  end

  private

  def platform_admin_abilities(user)
    can %i[read create update], Template, Abilities::TemplateConditions.collection(user) do |template|
      Abilities::TemplateConditions.entity(template, user:, ability: 'manage')
    end

    can :destroy, Template, account_id: user.account_id
    can :manage, TemplateFolder, account_id: user.account_id
    can :manage, TemplateSharing, template: { account_id: user.account_id }
    can :manage, Submission, account_id: user.account_id
    can :manage, Submitter, account_id: user.account_id
    can :manage, User, account_id: user.account_id
    can :manage, EncryptedConfig, account_id: user.account_id
    can :manage, EncryptedUserConfig, user_id: user.id
    can :manage, AccountConfig, account_id: user.account_id
    can :manage, UserConfig, user_id: user.id
    can :manage, Account, id: user.account_id
    can :manage, Company, account_id: user.account_id
    can :manage, AccessToken, user_id: user.id
    can :manage, McpToken, user_id: user.id
    can :manage, WebhookUrl, account_id: user.account_id
    can :manage, Department, account_id: user.account_id
    can :manage, :mcp
  end

  def admin_abilities(user)
    can %i[read create update], Template, Abilities::TemplateConditions.collection(user) do |template|
      Abilities::TemplateConditions.entity(template, user:, ability: 'manage')
    end

    can :destroy, Template, account_id: user.account_id, company_id: user.company_id
    can :manage, TemplateFolder, account_id: user.account_id, company_id: user.company_id
    can :manage, TemplateSharing, template: { account_id: user.account_id, company_id: user.company_id }
    can :manage, Submission, account_id: user.account_id, company_id: user.company_id
    can :manage, Submitter, account_id: user.account_id, company_id: user.company_id
    can :manage, User, account_id: user.account_id, company_id: user.company_id
    can :manage, EncryptedConfig, account_id: user.account_id
    can :manage, EncryptedUserConfig, user_id: user.id
    can :manage, AccountConfig, account_id: user.account_id
    can :manage, UserConfig, user_id: user.id
    can :manage, Account, id: user.account_id
    can :read, Company, id: user.company_id, account_id: user.account_id
    can :manage, AccessToken, user_id: user.id
    can :manage, McpToken, user_id: user.id
    can :manage, WebhookUrl, account_id: user.account_id
    can :manage, Department, account_id: user.account_id, company_id: user.company_id
    can :manage, :mcp
  end

  def editor_abilities(user)
    own_account_and_user_abilities(user)

    can :read, TemplateFolder, account_id: user.account_id, company_id: user.company_id
    can :create, TemplateFolder

    can :create, Template

    can %i[read update destroy], Template, Abilities::DepartmentConditions.template_collection(user) do |template|
      Abilities::DepartmentConditions.template_entity(template, user:, ability: 'manage')
    end

    can :create, Submission

    can %i[read update destroy], Submission, Abilities::DepartmentConditions.submission_collection(user) do |submission|
      Abilities::DepartmentConditions.submission_entity(submission, user:)
    end

    can %i[read update], Submitter, Abilities::DepartmentConditions.submitter_collection(user) do |submitter|
      Abilities::DepartmentConditions.submitter_entity(submitter, user:)
    end
  end

  def viewer_abilities(user)
    own_account_and_user_abilities(user)

    can :read, TemplateFolder, account_id: user.account_id, company_id: user.company_id

    can :read, Template, Abilities::DepartmentConditions.template_collection(user) do |template|
      Abilities::DepartmentConditions.template_entity(template, user:, ability: 'read')
    end

    can :read, Submission, Abilities::DepartmentConditions.submission_collection(user) do |submission|
      Abilities::DepartmentConditions.submission_entity(submission, user:)
    end

    can :read, Submitter, Abilities::DepartmentConditions.submitter_collection(user) do |submitter|
      Abilities::DepartmentConditions.submitter_entity(submitter, user:)
    end
  end

  def own_account_and_user_abilities(user)
    can :read, Account, id: user.account_id
    can :read, Company, id: user.company_id, account_id: user.account_id
    can :manage, User, id: user.id
    can :manage, EncryptedUserConfig, user_id: user.id
    can :manage, UserConfig, user_id: user.id
    can :manage, AccessToken, user_id: user.id
  end
end