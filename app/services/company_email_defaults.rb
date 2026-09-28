# frozen_string_literal: true

class CompanyEmailDefaults
  COMPANY_BRAND_NAMES = {
    'CHS' => 'Churchfield Home Services',
    'MD' => 'Materials Direct',
    'SL' => 'Smart Lotto',
    'ESS' => 'Efficient Software Solutions'
  }.freeze

  class << self
    def invitation_subject(company)
      code = extract_code(company)
      brand_name = COMPANY_BRAND_NAMES[code] || COMPANY_BRAND_NAMES['CHS']
      "#{brand_name} document request"
    end

    def invitation_body(company)
      code = extract_code(company)
      brand_name = COMPANY_BRAND_NAMES[code] || COMPANY_BRAND_NAMES['CHS']
      <<~BODY
        Hello,

        #{brand_name} has sent you a document to review and complete.

        Please click the button below to open the secure document.

        Thank you,
        #{brand_name}
      BODY
    end

    def completed_subject(company)
      code = extract_code(company)
      brand_name = COMPANY_BRAND_NAMES[code] || COMPANY_BRAND_NAMES['CHS']
      "#{brand_name} document completed"
    end

    def completed_body(company)
      code = extract_code(company)
      brand_name = COMPANY_BRAND_NAMES[code] || COMPANY_BRAND_NAMES['CHS']
      <<~BODY
        Hello,

        The document has been completed.

        You can review the completed document using the link below:

        {submission.link}

        Thank you,
        #{brand_name}
      BODY
    end

    def documents_copy_subject(company)
      code = extract_code(company)
      brand_name = COMPANY_BRAND_NAMES[code] || COMPANY_BRAND_NAMES['CHS']
      "Your #{brand_name} document copy"
    end

    def documents_copy_body(company)
      code = extract_code(company)
      brand_name = COMPANY_BRAND_NAMES[code] || COMPANY_BRAND_NAMES['CHS']
      <<~BODY
        Hello,

        Your completed document copy is ready.

        Please use the link below to review or download your copy:

        {documents.link}

        Thank you,
        #{brand_name}
      BODY
    end

    def company_for_submitter(submitter)
      company = submitter.submission&.template&.company.presence ||
                submitter.submission&.company.presence ||
                submitter.company.presence

      company || Company.find_by(code: 'CHS')
    end

    private

    def extract_code(company)
      code = company.respond_to?(:code) ? company.code : company
      code.to_s.upcase
    end
  end
end
