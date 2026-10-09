# frozen_string_literal: true

class SubmittersAutocompleteController < ApplicationController
  load_and_authorize_resource :submitter, parent: false

  SELECT_COLUMNS = %w[email phone name].freeze
  LIMIT = 100

  def index
    query = params[:q].to_s.strip
    return render json: [] if query.blank?

    field = SELECT_COLUMNS.find { |c| c == params[:field] }

    render json: autocomplete_results(field, query)
  end

  private

  def autocomplete_results(field, query)
    directory = search_directory(field, query)
    history = search_history(field, query)
    merge_results(directory, history)
  end

  def merge_results(directory, history)
    directory_emails = directory.to_set { |r| r['email'].to_s.strip.downcase }

    history_filtered = history.reject do |row|
      directory_emails.include?(row['email'].to_s.strip.downcase)
    end

    (directory + history_filtered).first(LIMIT)
  end

  def search_history(field, query)
    submitters = search_submitters(@submitters, field, query)
    arel_columns = SELECT_COLUMNS.map { |col| Submitter.arel_table[col] }

    values =
      if field
        max_ids = submitters.group(field).limit(LIMIT).select(Submitter.arel_table[:id].maximum)
        submitters.where(id: max_ids).order(id: :desc).pluck(*arel_columns)
      else
        submitters.limit(LIMIT).group(*arel_columns).pluck(*arel_columns)
      end

    results = values.map { |row| SELECT_COLUMNS.zip(row).to_h }
    results.each { |r| r['source'] = 'history' }
    results
  end

  def search_directory(field, query)
    return [] unless can?(:read, RecipientContact)

    contacts = current_account.recipient_contacts.visible_to(current_user)

    term = "#{query.downcase}%"
    contacts = if field
                 contacts.where(RecipientContact.arel_table[field.to_sym].matches(term))
               else
                 contacts.where(
                   RecipientContact.arel_table[:name].matches(term).or(
                     RecipientContact.arel_table[:email].matches(term)
                   ).or(
                     RecipientContact.arel_table[:phone].matches(term)
                   )
                 )
               end

    contacts.limit(LIMIT).map do |contact|
      {
        'email' => contact.email,
        'name' => contact.name,
        'phone' => contact.phone,
        'source' => 'directory',
        'visibility' => contact.shared? ? 'shared' : 'company',
        'company_name' => contact.company&.name
      }
    end
  end

  def search_submitters(submitters, field, query)
    if field
      if Docuseal.fulltext_search?
        Submitters.fulltext_search_field(current_user, submitters, query, field)
      else
        column = Submitter.arel_table[field.to_sym]

        term = "#{query.downcase}%"

        submitters.where(column.matches(term))
      end
    else
      Submitters.search(current_user, submitters, query)
    end
  end
end
