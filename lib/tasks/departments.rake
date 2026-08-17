# frozen_string_literal: true

namespace :departments do
  desc 'List templates without departments'
  task list_unassigned_templates: :environment do
    templates = Template.where.missing(:template_departments).order(:id)

    if templates.blank?
      puts 'No unassigned templates found.'
      next
    end

    templates.each do |template|
      puts [
        "##{template.id}",
        template.name,
        "author=#{template.author&.email || 'unknown'}",
        "account_id=#{template.account_id}"
      ].join(' | ')
    end
  end

  desc 'Assign a department to templates by ID. ' \
       'Usage: DEPARTMENT=ICT TEMPLATE_IDS=1,2,3 APPLY=false bin/rails departments:assign_templates'
  task assign_templates: :environment do
    department_name = ENV.fetch('DEPARTMENT', '').strip
    template_ids = ENV.fetch('TEMPLATE_IDS', '').split(',').map(&:strip).compact_blank
    apply = ENV.fetch('APPLY', 'false') == 'true'

    if department_name.blank?
      puts 'ERROR: DEPARTMENT is required. Example: DEPARTMENT=ICT'
      exit 1
    end

    if template_ids.blank?
      puts 'ERROR: TEMPLATE_IDS is required. Example: TEMPLATE_IDS=1,2,3'
      exit 1
    end

    departments = Department.where('LOWER(name) = ?', department_name.downcase)

    if departments.blank?
      puts "ERROR: Department not found: #{department_name}"
      puts 'Available departments:'
      Department.order(:name).pluck(:name).each { |name| puts "  - #{name}" }
      exit 1
    end

    if departments.size > 1
      puts "ERROR: More than one department named #{department_name.inspect} exists across accounts."
      puts 'Use this task only after confirming there is one matching department in the target environment.'
      exit 1
    end

    department = departments.first
    templates = Template.where(id: template_ids)

    missing_ids = template_ids.map(&:to_i) - templates.pluck(:id)

    if missing_ids.present?
      puts "WARNING: These template IDs were not found: #{missing_ids.join(', ')}"
      puts
    end

    puts "Department: #{department.name}"
    puts "Mode: #{apply ? 'APPLY' : 'PREVIEW'}"
    puts

    templates.order(:id).each do |template|
      existing_departments = template.departments.order(:name).pluck(:name)

      puts "Template ##{template.id}: #{template.name}"
      puts "  Current departments: #{existing_departments.presence&.join(', ') || '(none)'}"
      puts "  Will add: #{department.name}"

      if apply
        template.departments << department unless template.departments.exists?(department.id)
        puts "  Result departments: #{template.departments.order(:name).pluck(:name).join(', ')}"
      end

      puts
    end

    puts apply ? 'Done.' : 'Preview complete. Re-run with APPLY=true to make changes.'
  end
end
